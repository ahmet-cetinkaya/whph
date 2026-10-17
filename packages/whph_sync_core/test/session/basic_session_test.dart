import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

void main() {
  test('two paired devices converge in one session both ways', () async {
    final clock = TestClock();
    final a = await newDevice('A', seed: 1, clock: clock);
    final b = await newDevice('B', seed: 2, clock: clock);
    await SyncDevice.pair(inviter: a, joiner: b);
    createRow(a, 't1', 'from A');
    clock.advance(10);
    createRow(b, 't2', 'from B');
    final r = await SyncDevice.syncPair(a, b);
    expect(r.initiator, isComplete, reason: '$r');
    expect(r.responder, isComplete, reason: '$r');
    expect(content(a.store), content(b.store));
    expect(aliveRows(b.store, 'task'), {'t1', 't2'});
    expect(b.store.cursorOf(a.store.localOrigin.hex), a.store.highestOwnSeq);
    expect(a.store.cursorOf(b.store.localOrigin.hex), b.store.highestOwnSeq);

    // A second session sends nothing new.
    final again = await SyncDevice.syncPair(b, a);
    expect(again.bothComplete, isTrue, reason: '$again');
    expect(again.initiator.stats.envelopesSent, 0);
    expect(again.responder.stats.envelopesSent, 0);
  });

  test('an unpaired device does not sync', () async {
    final a = await newDevice('A', seed: 1);
    final b = await newDevice('B', seed: 2);
    final r = await SyncDevice.syncPair(a, b);
    expect((r.initiator as SessionFailed).category, SessionFailure.notPaired);
  });
}
