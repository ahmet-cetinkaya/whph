/// T22b: `AsyncSyncSession` over the in-memory async adapter reaches the same
/// end states as `SyncSession` and keeps the U11 sent-mark rule. The whole
/// session suite and the simulator run through it with `SESSION_ENGINE=async`
/// (see `session_engine_switch.dart`).
library;

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

Future<List<SyncDevice>> _pairedDevices(int count, {SyncEngineConfig? config}) async {
  final clock = TestClock();
  final devices = [
    for (var i = 0; i < count; i++) await newDevice('D$i', seed: 700 + i, clock: clock, config: config),
  ];
  await pairAll(devices);
  return devices;
}

void main() {
  test('async and sync engines converge to the same content and vector', () async {
    final config = testConfig(maxBatchChanges: 20);
    final sync = await _pairedDevices(2, config: config);
    final async = await _pairedDevices(2, config: config);
    for (final devices in [sync, async]) {
      for (var i = 0; i < 90; i++) {
        createRow(devices[i % 2], 'r$i', 'title $i');
      }
    }
    final syncResult = await SyncDevice.syncPair(sync[0], sync[1]);
    final asyncResult = await InMemoryAsyncSessionDevice.syncPair(
      InMemoryAsyncSessionDevice(async[0]),
      InMemoryAsyncSessionDevice(async[1]),
    );
    expect(syncResult.bothComplete, isTrue);
    expect(asyncResult.bothComplete, isTrue, reason: '$asyncResult');
    expect(content(async[0].store), content(async[1].store));
    expect(content(async[0].store), content(sync[0].store));
    expect(async[1].store.vector, sync[1].store.vector);
    expect(asyncResult.initiator.stats.envelopesSent, syncResult.initiator.stats.envelopesSent);
    expect(asyncResult.responder.stats.applied, syncResult.responder.stats.applied);
  });

  test('the window bounds the batches in flight', () async {
    final devices = await _pairedDevices(2, config: testConfig(window: 3, maxBatchChanges: 5));
    for (var i = 0; i < 100; i++) {
      createRow(devices[0], 'r$i', 'title $i');
    }
    final pair = await InMemoryAsyncSessionDevice.syncPair(
      InMemoryAsyncSessionDevice(devices[0]),
      InMemoryAsyncSessionDevice(devices[1]),
    );
    expect(pair.bothComplete, isTrue, reason: '$pair');
    expect(pair.initiator.stats.maxInFlight, inInclusiveRange(1, 3));
    expect(content(devices[1].store), content(devices[0].store));
  });

  test('a failing sent-mark write stops sending and ends partial(storageError)', () async {
    final ledger = InMemorySyncLedger();
    final delays = <Duration>[];
    final config = SyncEngineConfig(delay: (d) async => delays.add(d));
    final clock = TestClock();
    final a = await newDevice('A', seed: 31, clock: clock, config: config, ledger: ledger);
    final b = await newDevice('B', seed: 32, clock: clock, config: config);
    await SyncDevice.pair(inviter: a, joiner: b);
    createRow(a, 'fromA', 'x');
    createRow(b, 'fromB', 'y');
    ledger.failAllSentMarkWrites = true;
    final pair = await InMemoryAsyncSessionDevice.syncPair(
      InMemoryAsyncSessionDevice(a),
      InMemoryAsyncSessionDevice(b),
    );
    expect(delays, const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)]);
    expect((pair.initiator as SessionPartial).reasons, {PartialReason.storageError});
    expect(pair.initiator.stats.envelopesSent, 0);
    expect(a.store.isRowAlive('task', 'fromB'), isTrue, reason: 'receiving continued');
  });
}
