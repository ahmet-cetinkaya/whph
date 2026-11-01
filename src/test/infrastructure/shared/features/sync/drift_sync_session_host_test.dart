// The responder of a session records the peer's last success, as the engine
// does for the sessions it starts (the desktop showed "Never synced" for a
// phone that had synced).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_status_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/features/sync/services/sync_progress_tracker.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'drift_session_test_support.dart';
import 'sync_security_test_support.dart';

const Duration _sessionDeadline = Duration(seconds: 20);

class _RecordingStatusStore extends Fake implements ISyncPeerStatusStore {
  final successes = <String>[];
  final results = <String, SyncResultCategory?>{};

  @override
  Future<void> recordSuccess(String memberId, DateTime at) async => successes.add(memberId);

  @override
  Future<SyncPeerStatus?> read(String memberId) async =>
      SyncPeerStatus(memberId: memberId, lastResult: results[memberId]);

  @override
  Future<void> setResult(String memberId, SyncResultCategory? category) async => results[memberId] = category;
}

void main() {
  late Directory scratch;
  late _RecordingStatusStore statusStore;
  late DriftEngineDevice initiator;
  late DriftEngineDevice responder;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('sync-host-');
    statusStore = _RecordingStatusStore();
    initiator = await DriftEngineDevice.open('Phone', scratch);
    final responderSecurity = await SecurityDevice.open('Desktop', scratch);
    responder = DriftEngineDevice.over(responderSecurity, statusStore: statusStore);
    addTearDown(initiator.close);
    addTearDown(responder.close);
    await pairDevices(initiator.security, responder.security);
  });
  tearDown(() => scratch.delete(recursive: true));

  test('records the last success of the initiator when the session completes', () async {
    final (initiatorEnd, responderEnd) = InMemoryTransport.pair();

    final results = await Future.wait([
      initiator.initiate(initiatorEnd, responder.memberId),
      responder.respond(responderEnd),
    ]).timeout(_sessionDeadline);

    expect(results.last.isComplete, isTrue, reason: '${results.last}');
    expect(statusStore.successes, [initiator.memberId]);
  });

  test('records nothing when the session does not complete', () async {
    final (initiatorEnd, responderEnd) = InMemoryTransport.pair();
    await initiatorEnd.close();

    final result = await responder.respond(responderEnd).timeout(_sessionDeadline);

    expect(result.isComplete, isFalse);
    expect(statusStore.successes, isEmpty);
  });

  Future<SessionResult> completeSession() async {
    final (initiatorEnd, responderEnd) = InMemoryTransport.pair();
    final results = await Future.wait([
      initiator.initiate(initiatorEnd, responder.memberId),
      responder.respond(responderEnd),
    ]).timeout(_sessionDeadline);
    return results.last;
  }

  test('a completed session clears an earlier not-reachable result of the peer', () async {
    statusStore.results[initiator.memberId] = SyncResultCategory.notReachable;

    await completeSession();

    expect(statusStore.results[initiator.memberId], isNull);
  });

  test('a completed session keeps any other stored result of the peer', () async {
    statusStore.results[initiator.memberId] = SyncResultCategory.needsRepairing;

    await completeSession();

    expect(statusStore.results[initiator.memberId], SyncResultCategory.needsRepairing);
  });

  test('an incoming session is refused as preparing while the upgrade is pending and the job is restarted', () async {
    final upgrade = CountingUpgradeService(phase: SyncUpgradePhase.reauthor);
    final preparing = DriftEngineDevice.over(responder.security, upgradeService: upgrade);
    final (initiatorEnd, responderEnd) = InMemoryTransport.pair();

    final results = await Future.wait([
      initiator.initiate(initiatorEnd, responder.memberId),
      preparing.respond(responderEnd),
    ]).timeout(_sessionDeadline);

    expect((results.first as SessionFailed).category, SessionFailure.peerPreparing);
    expect((results.last as SessionFailed).category, SessionFailure.preparing);
    expect(upgrade.runCount, 1);
  });

  test('an incoming session is served once the upgrade is done', () async {
    final done = DriftEngineDevice.over(responder.security, upgradeService: CountingUpgradeService());
    final (initiatorEnd, responderEnd) = InMemoryTransport.pair();

    final results = await Future.wait([
      initiator.initiate(initiatorEnd, responder.memberId),
      done.respond(responderEnd),
    ]).timeout(_sessionDeadline);

    expect(results.last.isComplete, isTrue, reason: '${results.last}');
  });

  test('the responder reports the progress of the peer that syncs into it and clears it at the end', () async {
    await seedNoteMarkers(initiator.security, 5);
    final tracker = SyncProgressTracker();
    final statuses = <SyncStatus>[];
    tracker.changes.listen(statuses.add);
    final answering = DriftEngineDevice.over(responder.security, progress: tracker);
    final (initiatorEnd, responderEnd) = InMemoryTransport.pair();

    await Future.wait([
      initiator.initiate(initiatorEnd, responder.memberId),
      answering.respond(responderEnd),
    ]).timeout(_sessionDeadline);
    await pumpEventQueue();

    expect(statuses.where((status) => status.progress != null), isNotEmpty);
    expect(
        statuses.where((status) => status.state == SyncState.syncing).every((status) {
          return status.currentDeviceId == initiator.memberId;
        }),
        isTrue);
    expect(tracker.current.state, SyncState.idle);
  });

  test('the responder clears the progress of the peer when the session fails', () async {
    final tracker = SyncProgressTracker();
    final preparing = DriftEngineDevice.over(responder.security,
        upgradeService: CountingUpgradeService(phase: SyncUpgradePhase.reauthor), progress: tracker);
    tracker.begin(initiator.memberId);
    final (initiatorEnd, responderEnd) = InMemoryTransport.pair();

    final results = await Future.wait([
      initiator.initiate(initiatorEnd, responder.memberId),
      preparing.respond(responderEnd),
    ]).timeout(_sessionDeadline);

    expect(results.last, isA<SessionFailed>());
    expect(tracker.current.state, SyncState.idle);
  });
}
