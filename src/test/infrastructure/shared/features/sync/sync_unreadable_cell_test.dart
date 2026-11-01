// A store that lists a cell but cannot re-read it by key (the unknown-cell
// fallback reverted, Efe's #324 mutation) must make the session fail, not
// spin: the scan loop used to retry the same seq forever on microtasks, so
// no timer, not even test timeouts, could fire.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_change_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'drift_session_test_support.dart';
import 'sync_security_test_support.dart';

const Duration _sessionDeadline = Duration(seconds: 20);

/// Lists every cell like the real store but never finds one by key.
class _UnreadableCellStore extends DriftAsyncSyncStore {
  _UnreadableCellStore(super.changeStore);

  @override
  Future<StoredCell?> storedCell(CellKey key) async {
    // Yields so a session that keeps retrying lets the test timeout fire.
    await Future<void>.delayed(Duration.zero);
    return null;
  }
}

void main() {
  late Directory scratch;

  setUp(() async => scratch = await Directory.systemTemp.createTemp('sync-unreadable-'));
  tearDown(() => scratch.delete(recursive: true));

  test('a cell that cannot be re-read by key fails the session instead of spinning', () async {
    final sender = await DriftEngineDevice.open('A', scratch);
    final receiver = await DriftEngineDevice.open('B', scratch);
    addTearDown(sender.close);
    addTearDown(receiver.close);
    await pairDevices(sender.security, receiver.security);
    final unreadable =
        DriftEngineDevice.over(sender.security, store: _UnreadableCellStore(sender.security.database.store));
    await sender.security.database.insertNote('n1', 'held by A');
    final (senderEnd, receiverEnd) = InMemoryTransport.pair();

    final results = await Future.wait([
      unreadable.initiate(senderEnd, receiver.memberId),
      receiver.respond(receiverEnd),
    ]).timeout(_sessionDeadline);

    expect(results.first.isComplete, isFalse, reason: '${results.first}');
  });
}
