/// D7 sent-seq mark: persisted before a batch above it; a failing write stops
/// sending (after the 1 s / 2 s / 4 s retries), keeps receiving and ends the
/// session partial with the category storage error.
library;

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

void main() {
  test('the mark is persisted before own seqs are sent, at most once per batch', () async {
    final clock = TestClock();
    final config = testConfig(maxBatchChanges: 25);
    final ledger = InMemorySyncLedger();
    final a = await newDevice('A', seed: 1, clock: clock, config: config, ledger: ledger);
    final b = await newDevice('B', seed: 2, clock: clock, config: config);
    await SyncDevice.pair(inviter: a, joiner: b);
    for (var i = 0; i < 100; i++) {
      createRow(a, 'r$i', 't$i');
    }
    final writesBefore = ledger.sentMarkWrites;
    final r = await SyncDevice.syncPair(a, b);
    expect(r.bothComplete, isTrue);
    expect(a.ledger.entryOf(a.store.localOrigin)!.maxSentSeq, a.store.highestOwnSeq);
    expect(ledger.sentMarkWrites - writesBefore, lessThanOrEqualTo(r.initiator.stats.batchesSent));
  });

  test('a failing mark write stops sending, keeps receiving, ends partial(storageError); the next session retries',
      () async {
    final clock = TestClock();
    final delays = <Duration>[];
    final config = SyncEngineConfig(delay: (d) async => delays.add(d));
    final ledger = InMemorySyncLedger();
    final a = await newDevice('A', seed: 3, clock: clock, config: config, ledger: ledger);
    final b = await newDevice('B', seed: 4, clock: clock, config: config);
    await SyncDevice.pair(inviter: a, joiner: b);
    createRow(a, 'fromA', 'x');
    createRow(b, 'fromB', 'y');
    ledger.failAllSentMarkWrites = true;
    final r = await SyncDevice.syncPair(a, b);
    expect(delays, const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)]);
    final aSide = r.initiator as SessionPartial;
    expect(aSide.reasons, {PartialReason.storageError});
    expect(aSide.stats.envelopesSent, 0, reason: 'the batch above the mark was not sent');
    expect(r.responder, isComplete);
    expect(a.store.isRowAlive('task', 'fromB'), isTrue, reason: 'receiving continued');
    expect(b.store.rowsOf('task'), ['fromB']);

    ledger.failAllSentMarkWrites = false;
    final again = await SyncDevice.syncPair(a, b);
    expect(again.bothComplete, isTrue);
    expect(content(a.store), content(b.store));
  });
}
