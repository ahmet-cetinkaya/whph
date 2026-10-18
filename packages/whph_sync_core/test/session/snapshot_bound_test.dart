/// T12 acc 4 (seq gaps), acc 5 (snapshot bound, FR-014), acc 6 (Busy).
library;

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

Future<(SyncDevice, SyncDevice, TestClock)> _pair({SyncEngineConfig? config, int seedA = 21, int seedB = 22}) async {
  final clock = TestClock();
  final a = await newDevice('A', seed: seedA, clock: clock, config: config);
  final b = await newDevice('B', seed: seedB, clock: clock, config: config);
  await SyncDevice.pair(inviter: a, joiner: b);
  return (a, b, clock);
}

void main() {
  test('acc 4: after 1,000 overwrites of one cell on A, B\'s cursor for A is A\'s latest seq after one session',
      () async {
    final (a, b, clock) = await _pair();
    createRow(a, 'n1', 'v0');
    for (var i = 1; i <= 1000; i++) {
      clock.advance(1);
      a.write(const CellKey('task', 'n1', 'title'), 'v$i');
    }
    final r = await SyncDevice.syncPair(a, b);
    expect(r.bothComplete, isTrue);
    expect(b.store.cursorOf(a.store.localOrigin.hex), a.store.highestOwnSeq);
    expect(b.store.read(const CellKey('task', 'n1', 'title'))?.value, 'v1000');
    expect(r.initiator.stats.sentVersions.length, lessThan(10), reason: 'superseded seqs are gaps, not sent');
  });

  group('acc 5: a session started while writes continue (FR-014)', () {
    test('ends after the snapshot and sends no change twice', () async {
      final (a, b, clock) = await _pair(config: testConfig(maxBatchChanges: 20, window: 2));
      for (var i = 0; i < 200; i++) {
        createRow(a, 'r$i', 't$i');
      }
      final snapshotSeq = a.store.highestOwnSeq;
      var concurrent = 0;
      // Seqs of the overwrites of rows that were planned but not yet sent: the
      // only versions allowed above the snapshot (as relayed winners).
      final overwriteSeqs = <int>{};
      final narrowRanges = <(int, int)>{};
      final r = await SyncDevice.syncPair(
        a,
        b,
        hooksA: SessionHooks(outgoingBatch: (batch) {
          for (final entry in batch.ranges.entries) {
            if (entry.key.hex != a.store.localOrigin.hex) continue;
            for (final range in entry.value) {
              narrowRanges.add((range.from, range.to));
            }
          }
          return batch;
        }, afterBatchSent: (_) {
          // The user keeps editing on A while the session streams: new rows
          // and overwrites of rows planned but not yet sent.
          clock.advance(1);
          createRow(a, 'late$concurrent', 'late');
          a.write(CellKey('task', 'r${199 - concurrent}', 'title'), 'edited during session');
          overwriteSeqs.add(a.store.highestOwnSeq);
          concurrent++;
        }),
      );
      expect(r.bothComplete, isTrue, reason: '$r');
      expect(concurrent, greaterThan(5));
      final own = a.store.localOrigin.hex;
      final sent = r.initiator.stats.sentVersions;
      expect(sent.toSet().length, sent.length, reason: 'no change sent twice in one session');
      final ownSeqs = [
        for (final v in sent)
          if (v.startsWith(own)) int.parse(v.split('#').last),
      ];
      // A write made during the session may overwrite a planned row: its
      // superseded seq is then omitted, so the new version travels as a
      // relayed winner (F5, FR-014). These are the only seqs above the snapshot.
      final aboveSnapshot = {
        for (final s in ownSeqs)
          if (s > snapshotSeq) s
      };
      expect(overwriteSeqs.containsAll(aboveSnapshot), isTrue,
          reason: 'only overwrites of planned rows may travel above the snapshot: $aboveSnapshot vs $overwriteSeqs');
      for (final seq in aboveSnapshot) {
        expect(narrowRanges, contains((seq - 1, seq)), reason: 'relayed winner $seq goes under (Q-1, Q]');
      }
      expect(b.store.cursorOf(own), snapshotSeq, reason: 'the session ended at the snapshot');

      // The next session delivers what was written during the first one.
      final next = await SyncDevice.syncPair(a, b);
      expect(next.bothComplete, isTrue);
      final nextSent = next.initiator.stats.sentVersions.toSet();
      final alreadySent = {for (final s in sent) s};
      final relayedVersions = {for (final s in aboveSnapshot) '$own#$s'};
      // A relayed winner is not part of the snapshot, so the next session may
      // carry it again; nothing else may repeat.
      expect(nextSent.intersection(alreadySent).difference(relayedVersions), isEmpty);
      expect(content(b.store), content(a.store));
    });
  });

  group('acc 6: simultaneous start', () {
    test('exactly one session proceeds; the end state equals a single session', () async {
      final (a, b, clock) = await _pair();
      final (a2, b2, clock2) = await _pair();
      for (final (x, y, c) in [(a, b, clock), (a2, b2, clock2)]) {
        for (var i = 0; i < 50; i++) {
          createRow(x, 'a$i', 'from A $i');
          createRow(y, 'b$i', 'from B $i');
          c.advance(1);
        }
      }
      final both = await Future.wait([SyncDevice.syncPair(a, b), SyncDevice.syncPair(b, a)]);
      final proceeded = [
        for (final p in both)
          if (p.bothComplete) p,
      ];
      expect(proceeded, hasLength(1), reason: '$both');
      final other = both.firstWhere((p) => !p.bothComplete);
      expect((other.initiator as SessionFailed).category, SessionFailure.busy);
      expect(other.initiator.stats.envelopesSent + other.responder.stats.envelopesSent, 0);
      final smaller = a.memberId.compareTo(b.memberId) < 0 ? a : b;
      expect(identical(both.indexOf(proceeded.single) == 0 ? a : b, smaller), isTrue,
          reason: 'the session started by the smaller member id continues');

      final single = await SyncDevice.syncPair(a2, b2);
      expect(single.bothComplete, isTrue);
      expect(content(a.store), content(a2.store));
      expect(content(b.store), content(b2.store));
      expect(a.activeSessions, isEmpty);
      expect(b.activeSessions, isEmpty);
    });
  });
}
