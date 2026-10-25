// T23 acceptance 2, 3, 4 and 7: the sync engine of the application layer over
// real Drift devices, key files and sessions. Each failure shows its category
// and leaves the last successful sync time alone (FR-016); a malformed item is
// rejected (FR-015); the same item failing in 3 consecutive sessions raises
// the flag (FR-017); edits made while the peer was away go out in the next
// successful session (FR-008, PB-4).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';
import 'package:whph/infrastructure/shared/utils/owner_only_file_utils.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'drift_session_test_support.dart';
import 'sync_app_test_support.dart';
import 'sync_security_test_support.dart';

const int _flagAfterSessions = 3;
const String _poisonTitle = 'poison';

void main() {
  late Directory scratch;

  setUp(() async => scratch = await Directory.systemTemp.createTemp('sync-engine-'));
  tearDown(() => scratch.delete(recursive: true));

  Future<DriftEngineDevice> openPaired(String name, {DriftEngineDevice? inviter, SessionHooks? hooks}) async {
    final device = await DriftEngineDevice.open(name, scratch, hooks: hooks ?? const SessionHooks());
    addTearDown(device.close);
    if (inviter != null) await pairDevices(inviter.security, device.security);
    return device;
  }

  /// A and B paired, A the local side; [remoteHooks] act on what B sends.
  Future<EngineFixture> pairFixture({SessionHooks? remoteHooks}) async {
    final a = await openPaired('A');
    final b = await openPaired('B', inviter: a, hooks: remoteHooks);
    return EngineFixture.create(a, b);
  }

  group('FR-016: every failure shows its category and keeps the last success', () {
    late EngineFixture fixture;
    late DateTime firstSuccess;

    setUp(() async {
      fixture = await pairFixture();
      final report = await fixture.syncOnce();
      expect(report.result, isA<SessionComplete>(), reason: '${report.result}');
      expect(report.category, isNull);
      firstSuccess = (await fixture.lastSuccess())!;
    });

    test('unreachable peer: not reachable', () async {
      fixture.connector.reachable = false;

      final report = await fixture.syncOnce();

      expect(report.category, SyncResultCategory.notReachable);
      expect(await fixture.lastResult(), SyncResultCategory.notReachable);
      expect(await fixture.lastSuccess(), firstSuccess);
    });

    test('auth refused (the peer removed this device): needs re-pairing', () async {
      await fixture.remote.security.service.removeMember(fixture.local.memberId);

      final report = await fixture.syncOnce();

      expect(report.category, SyncResultCategory.needsRepairing, reason: '${report.result}');
      expect(await fixture.lastSuccess(), firstSuccess);
    });

    test('update_required: needs update', () async {
      final scripted = await EngineFixture.create(
        fixture.local,
        fixture.remote,
        host: ScriptedHost(SessionFailed(SessionStats(), fixture.remote.memberId, SessionFailure.needsUpdate)),
      );

      final report = await scripted.syncOnce();

      expect(report.category, SyncResultCategory.needsUpdate);
      expect(await scripted.lastSuccess(), firstSuccess);
    });

    test('partial session: some items failed, last success unchanged', () async {
      final scripted = await EngineFixture.create(
        fixture.local,
        fixture.remote,
        host: ScriptedHost(SessionPartial(SessionStats(), fixture.remote.memberId, {PartialReason.itemsFailed})),
      );

      final report = await scripted.syncOnce();

      expect(report.category, SyncResultCategory.someItemsFailed);
      expect(await scripted.lastSuccess(), firstSuccess);
    });

    test('a peer that is busy leaves the status as it was', () async {
      fixture.connector.reachable = false;
      await fixture.syncOnce();
      final busy = await EngineFixture.create(
        fixture.local,
        fixture.remote,
        host: ScriptedHost(SessionFailed(SessionStats(), fixture.remote.memberId, SessionFailure.busy)),
      );

      await busy.syncOnce();

      expect(await busy.lastResult(), SyncResultCategory.notReachable);
    });
  });

  test('FR-016: a sent-mark write failure ends storage error; incoming changes still apply', () async {
    final a = await DriftEngineDevice.open('A', scratch);
    addTearDown(a.close);
    final b = await openPaired('B', inviter: a);
    var failWrites = false;
    final failing = await _withSentMarkFailure(a.security, () => failWrites);
    final deviceA = DriftEngineDevice.over(failing);
    final fixture = await EngineFixture.create(deviceA, b);
    expect((await fixture.syncOnce()).result, isA<SessionComplete>());
    final firstSuccess = (await fixture.lastSuccess())!;
    await a.security.database.insertNote('from-a', 'out-1');
    await b.security.database.insertNote('from-b', 'in-1');
    failWrites = true;

    final report = await fixture.syncOnce();

    expect(report.category, SyncResultCategory.storageError, reason: '${report.result}');
    expect(await noteTitles(deviceA), contains('in-1'));
    expect(await noteTitles(b), isNot(contains('out-1')));
    expect(await fixture.lastSuccess(), firstSuccess);

    failWrites = false;
    final retry = await fixture.syncOnce();
    expect(retry.category, isNull);
    expect(await noteTitles(b), contains('out-1'));
  });

  group('FR-015: a peer item that is malformed is rejected', () {
    ChangeBatchMessage tamper(ChangeBatchMessage batch, ChangeEnvelope Function(ChangeEnvelope) alter) =>
        ChangeBatchMessage(
          batchId: batch.batchId,
          ranges: batch.ranges,
          manifests: batch.manifests,
          envelopes: [for (final e in batch.envelopes) e.pk == 'victim' && e.col == 'title' ? alter(e) : e],
        );

    ChangeEnvelope withCiphertext(ChangeEnvelope e, Uint8List ciphertext) => ChangeEnvelope(
          tbl: e.tbl,
          pk: e.pk,
          col: e.col,
          hlc: e.hlc,
          node: e.node,
          origin: e.origin,
          originSeq: e.originSeq,
          cause: e.cause,
          epoch: e.epoch,
          nonce: e.nonce,
          ciphertext: ciphertext,
          keyWrap: e.keyWrap,
          protocolVersion: e.protocolVersion,
        );

    Future<void> expectRejectedAndUnchanged(EngineFixture fixture) async {
      await fixture.remote.security.database.insertNote('victim', 'tampered');
      await fixture.remote.security.database.insertNote('fine', 'kept');

      final report = await fixture.syncOnce();

      expect(report.category, SyncResultCategory.rejectedItems,
          reason: '${report.result} ${fixture.connector.responderOutcomes}');
      final titles = await noteTitles(fixture.local);
      expect(titles, contains('kept'));
      expect(titles, isNot(contains('tampered')), reason: 'the rejected item changed nothing');
      expect(await fixture.lastResult(), SyncResultCategory.rejectedItems);
    }

    test('malformed: an altered ciphertext', () async {
      final fixture = await pairFixture(
        remoteHooks: SessionHooks(
          outgoingBatch: (batch) => tamper(batch, (e) => withCiphertext(e, Uint8List.fromList(e.ciphertext)..[0] ^= 1)),
        ),
      );

      await expectRejectedAndUnchanged(fixture);
    });

    test('oversized: a ciphertext at the size limit that does not open', () async {
      final fixture = await pairFixture(
        remoteHooks: SessionHooks(
          outgoingBatch: (batch) =>
              tamper(batch, (e) => withCiphertext(e, Uint8List(SyncLimits.maxEnvelopeCiphertextBytes))),
        ),
      );

      await expectRejectedAndUnchanged(fixture);
    });
  });

  test('FR-017: the flag rises after exactly 3 consecutive failing sessions for one item', () async {
    final fixture = await pairFixture();
    await fixture.local.security.database.sql('''
CREATE TRIGGER poison_insert BEFORE INSERT ON note_table WHEN NEW.title = '$_poisonTitle'
BEGIN SELECT RAISE(ABORT, 'poison'); END''');
    await fixture.local.security.database.sql('''
CREATE TRIGGER poison_update BEFORE UPDATE ON note_table WHEN NEW.title = '$_poisonTitle'
BEGIN SELECT RAISE(ABORT, 'poison'); END''');
    await fixture.remote.security.database.insertNote('stuck', _poisonTitle);
    final flags = <bool>[];

    for (var session = 1; session <= _flagAfterSessions; session++) {
      final report = await fixture.syncOnce();
      expect(report.category, SyncResultCategory.someItemsFailed, reason: 'session $session: ${report.result}');
      flags.add(report.itemsCannotBeApplied);
    }

    expect(flags, [false, false, true], reason: 'not after 1 or 2 sessions, after the 3rd');
    expect(await noteTitles(fixture.local), isNot(contains(_poisonTitle)));

    await fixture.local.security.database.sql('DROP TRIGGER poison_insert');
    await fixture.local.security.database.sql('DROP TRIGGER poison_update');
    final healed = await fixture.syncOnce();
    expect(healed.itemsCannotBeApplied, isFalse);
    expect(await noteTitles(fixture.local), contains(_poisonTitle));
  });

  test('FR-008, PB-4: edits made while the peer was away go out in the next successful session', () async {
    final fixture = await pairFixture();
    expect((await fixture.syncOnce()).category, isNull);
    fixture.connector.reachable = false;
    await fixture.local.security.database.insertNote('offline-1', 'written offline 1');
    await fixture.local.security.database.setTitle('offline-1', 'edited offline');
    await fixture.local.security.database.insertNote('offline-2', 'written offline 2');

    expect((await fixture.syncOnce()).category, SyncResultCategory.notReachable);
    expect(await noteTitles(fixture.remote), isNot(contains('edited offline')));

    fixture.connector.reachable = true;
    final report = await fixture.syncOnce();

    expect(report.category, isNull, reason: '${report.result}');
    expect(await noteTitles(fixture.remote), containsAll({'edited offline', 'written offline 2'}));
  });
}

/// [device] with a key store whose writes of a raised sent mark fail while
/// [shouldFail] is true; every other write goes through.
Future<SecurityDevice> _withSentMarkFailure(SecurityDevice device, bool Function() shouldFail) async {
  late FileSyncKeyStore keyStore;
  keyStore = FileSyncKeyStore(
    keyDirectory: Directory('${device.root.path}/data'),
    ledgerDirectory: Directory('${device.root.path}/state'),
    writer: OwnerOnlyAtomicWriter(beforeRename: (temporaryPath) async {
      if (shouldFail() && _raisesSentMark(temporaryPath, keyStore)) throw StateError('simulated ledger failure');
    }),
  );
  device.keyStore = keyStore;
  device.service =
      SyncMembershipService(keyStore: keyStore, changeStore: device.database.store, peerStateStore: device.peerStates);
  await device.service.loadKeyFile();
  return device;
}

bool _raisesSentMark(String temporaryPath, FileSyncKeyStore ledger) {
  final document = jsonDecode(File(temporaryPath).readAsStringSync()) as Map<String, dynamic>;
  final origins = document['origins'];
  if (origins is! List || ledger.entries.isEmpty) return false;
  return (origins.last as Map<String, dynamic>)['max_sent_seq'] as int > ledger.entries.last.maxSentSeq;
}
