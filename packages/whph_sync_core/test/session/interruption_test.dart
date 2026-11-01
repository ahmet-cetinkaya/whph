/// T12 acc 3 (Scenarios 1.8, 1.9) and acc 10 (U9/PA-2 pipelining).
library;

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

/// Two paired devices; A holds [rows] rows with two cells each.
Future<(SyncDevice, SyncDevice)> _setup({
  int rows = 600,
  int window = 4,
  int maxBatchChanges = 50,
}) async {
  final clock = TestClock();
  final config = testConfig(window: window, maxBatchChanges: maxBatchChanges);
  final a = await newDevice('A', seed: 11, clock: clock, config: config);
  final b = await newDevice('B', seed: 12, clock: clock, config: config);
  await SyncDevice.pair(inviter: a, joiner: b);
  for (var i = 0; i < rows; i++) {
    createRow(a, 'r$i', 'title $i');
    clock.advance(1);
  }
  createRow(b, 'b0', 'from B');
  return (a, b);
}

/// Every version of [origin] held by [store] was committed exactly once.
void _expectCommittedOnce(SyncStore receiver, SyncStore author) {
  final own = author.localOrigin.hex;
  var checked = 0;
  for (final c in author.cells) {
    if (c.origin != own) continue;
    expect(receiver.commitLog['$own#${c.originSeq}'], 1, reason: 'version $own#${c.originSeq}');
    checked++;
  }
  expect(checked, greaterThan(0));
  expect(receiver.commitLog.values.where((n) => n != 1), isEmpty, reason: 'a version was committed twice');
}

void main() {
  group('Scenario 1.8 (acc 3): interrupted then resumed session', () {
    for (final cut in [9, 14, 23, 31]) {
      test('cut after $cut frames: every change applied exactly once, none skipped', () async {
        final (a, b) = await _setup();
        final trace = TransportTrace();
        final first = await runSessionPair(a, b, faults: TransportFaults(cutAfter: cut), trace: trace);
        expect(trace.cut, isTrue);
        expect((first.initiator as SessionFailed).category, SessionFailure.notReachable);
        expect((first.responder as SessionFailed).category, SessionFailure.notReachable);
        final partialCursor = b.store.cursorOf(a.store.localOrigin.hex);
        expect(partialCursor, lessThan(a.store.highestOwnSeq), reason: 'the cut interrupted the stream');

        final second = await runSessionPair(a, b);
        expect(second.bothComplete, isTrue, reason: '$second');
        expect(content(b.store), content(a.store));
        expect(b.store.cursorOf(a.store.localOrigin.hex), a.store.highestOwnSeq);
        _expectCommittedOnce(b.store, a.store);
        // The resumed stream starts at the committed cursor: nothing below it
        // is sent again.
        final resent = second.initiator.stats.sentVersions
            .where((v) => v.startsWith(a.store.localOrigin.hex))
            .map((v) => int.parse(v.split('#').last))
            .where((seq) => seq <= partialCursor);
        expect(resent, isEmpty);
      });
    }
  });

  group('Scenario 1.9 (acc 3): a failing item', () {
    test('→ partial, others kept, cursor at the declared bound; applied next session via refetch', () async {
      final (a, b) = await _setup(rows: 120);
      bool fault(Change c) => c.pk == 'r7' && c.col == 'title';
      b.store.applyFault = fault;
      final first = await runSessionPair(a, b);
      expect(first.initiator, isComplete, reason: 'A applied everything of B');
      final bSide = first.responder;
      expect(bSide, isA<SessionPartial>());
      expect((bSide as SessionPartial).reasons, {PartialReason.itemsFailed});
      expect(bSide.stats.failed, 1);
      expect(b.store.read(const CellKey('task', 'r7', 'title')), isNull, reason: 'the failed item rolled back alone');
      expect(b.store.read(const CellKey('task', 'r8', 'title'))?.value, 'title 8', reason: 'others kept');
      expect(b.store.cursorOf(a.store.localOrigin.hex), a.store.highestOwnSeq, reason: 'cursor not held back');
      final held = b.store.heldEnvelopes.single;
      expect(held.reason, HeldReason.applyFailed);
      expect(held.failCount, 1);

      b.store.applyFault = null;
      final second = await runSessionPair(a, b);
      expect(second.bothComplete, isTrue, reason: '$second');
      expect(second.initiator.stats.refetchSent, 1, reason: 'B refetched the failed key and A answered');
      expect(b.store.read(const CellKey('task', 'r7', 'title'))?.value, 'title 7');
      expect(b.store.heldEnvelopes, isEmpty);
      expect(content(b.store), content(a.store));
      expect(b.peerState(a.memberId).itemsCannotBeApplied, isFalse);
    });

    test('FR-017: the same item failing in 3 consecutive sessions flags the peer', () async {
      final (a, b) = await _setup(rows: 10);
      b.store.applyFault = (c) => c.pk == 'r3';
      for (var i = 1; i <= 3; i++) {
        final r = await runSessionPair(a, b);
        expect(r.responder, isA<SessionPartial>(), reason: 'session $i');
        expect(b.peerState(a.memberId).itemsCannotBeApplied, i >= 3, reason: 'after session $i');
      }
      b.store.applyFault = null;
      final ok = await runSessionPair(a, b);
      expect(ok.bothComplete, isTrue);
      expect(b.peerState(a.memberId).itemsCannotBeApplied, isFalse);
      expect(content(b.store), content(a.store));
    });
  });

  group('Pipelining (acc 10, U9/PA-2)', () {
    test('window > 1 keeps several unacknowledged batches in flight; end state equals window 1', () async {
      final (a4, b4) = await _setup(window: 4);
      final r4 = await runSessionPair(a4, b4);
      expect(r4.bothComplete, isTrue);
      expect(r4.initiator.stats.batchesSent, greaterThan(8));
      expect(r4.initiator.stats.maxUnackedAtAck, greaterThan(1),
          reason: 'when the receiver acked a batch, later batches were already in flight');

      final (a1, b1) = await _setup(window: 1);
      final r1 = await runSessionPair(a1, b1);
      expect(r1.bothComplete, isTrue);
      expect(r1.initiator.stats.maxUnackedAtAck, 1);
      expect(r1.initiator.stats.maxInFlight, 1);

      expect(content(b4.store), content(b1.store));
      expect(content(a4.store), content(a1.store));
      expect(b4.store.vector.values.toList(), b1.store.vector.values.toList());
    });

    test('a cut in the middle of a window resumes without skipping or double-applying', () async {
      for (final cut in [12, 17, 26]) {
        final (a, b) = await _setup(window: 6);
        final first = await runSessionPair(a, b, faults: TransportFaults(cutAfter: cut));
        expect(first.initiator, isA<SessionFailed>());
        // The async engine awaits its store, so an ack can beat the next batch:
        // the window is not necessarily open at the cut (the window bound itself
        // is asserted in the test above).
        if (!useAsyncEngine) {
          expect(first.initiator.stats.maxInFlight, greaterThan(1), reason: 'cut $cut hit an open window');
        }
        final second = await runSessionPair(a, b);
        expect(second.bothComplete, isTrue, reason: 'cut $cut: $second');
        expect(content(b.store), content(a.store), reason: 'cut $cut');
        _expectCommittedOnce(b.store, a.store);
      }
    });

    test('both directions stream concurrently', () async {
      final (a, b) = await _setup(rows: 300, window: 3);
      for (var i = 0; i < 300; i++) {
        createRow(b, 'x$i', 'b title $i');
      }
      final r = await runSessionPair(a, b);
      expect(r.bothComplete, isTrue);
      expect(r.initiator.stats.batchesSent, greaterThan(3));
      expect(r.responder.stats.batchesSent, greaterThan(3));
      expect(content(a.store), content(b.store));
    });
  });
}
