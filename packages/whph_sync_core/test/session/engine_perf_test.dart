/// T12 part A performance sanity (real crypto, in-memory transport).
///
/// * Per-change engine cost (sender + receiver incl. crypto) of one session
///   carrying 10,000 changes.
/// * A representative 5-device workload driven by a small throwaway driver
///   (not the simulator): random creates, edits, deletes and cascades, random
///   pairwise sessions with cuts and replayed frames, then a final round
///   until quiet; all devices must converge. The default run uses 2,000 ops;
///   `ENGINE_PERF=1` runs the full 10,000 ops and prints the projection of
///   the part-B soak (1,000 runs × 5 devices × 10,000 ops).
library;

import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

final bool _full = Platform.environment['ENGINE_PERF'] == '1';

void main() {
  test('per-change engine cost of a 10,000-change session', () async {
    final clock = TestClock();
    final a = await newDevice('A', seed: 1, clock: clock);
    final b = await newDevice('B', seed: 2, clock: clock);
    await SyncDevice.pair(inviter: a, joiner: b);
    // Warm-up session (JIT, handshake code paths).
    createRow(a, 'warm', 'x');
    await SyncDevice.syncPair(a, b);
    for (var i = 0; i < 10000; i++) {
      a.write(CellKey('task', 'r${i ~/ 2}', i.isEven ? 'title' : 'note'), 'value $i: some typical title text');
    }
    final sw = Stopwatch()..start();
    final r = await SyncDevice.syncPair(a, b);
    final ms = sw.elapsedMicroseconds / 1000;
    expect(r.bothComplete, isTrue);
    expect(r.responder.stats.applied, 10000);
    sw.reset();
    await SyncDevice.syncPair(a, b);
    final emptyMs = sw.elapsedMicroseconds / 1000;
    // ignore: avoid_print
    print('ENGINE-PERF 10,000 changes one session: ${ms.toStringAsFixed(0)} ms total, '
        '${(ms * 1000 / 10000).toStringAsFixed(1)} µs/change (sender+receiver incl. signing, sealing, '
        'opening, hash checks); empty session (Noise XX + exchange): ${emptyMs.toStringAsFixed(1)} ms');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('5-device random workload converges (${_full ? 10000 : 2000} ops)', () async {
    final result = await _workload(seed: 4242, ops: _full ? 10000 : 2000);
    // ignore: avoid_print
    print('ENGINE-PERF workload: $result');
    if (_full) {
      final perRunS = result.elapsedMs / 1000;
      // ignore: avoid_print
      print('ENGINE-PERF soak projection (1,000 runs × 5 devices × 10,000 ops): '
          '${(perRunS * 1000 / 3600).toStringAsFixed(1)} h single process; '
          '${(perRunS * 1000 / 3600 / 16).toStringAsFixed(2)} h on 16 shards');
    }
  }, timeout: Timeout.none);
}

final class _WorkloadResult {
  _WorkloadResult(
      this.ops, this.sessions, this.elapsedMs, this.sessionMs, this.envelopes, this.failedSessions, this.finalRounds);

  final int ops;
  final int sessions;
  final int elapsedMs;
  final int sessionMs;
  final int envelopes;
  final int failedSessions;
  final int finalRounds;

  @override
  String toString() => 'ops=$ops sessions=$sessions failed(injected)=$failedSessions envelopes=$envelopes '
      'finalRounds=$finalRounds total=${elapsedMs}ms sessions=${sessionMs}ms '
      '(${(sessionMs / max(sessions, 1)).toStringAsFixed(2)} ms/session)';
}

Future<_WorkloadResult> _workload({required int seed, required int ops}) async {
  final rng = Random(seed);
  final clocks = [for (var i = 0; i < 5; i++) TestClock(baseWall + rng.nextInt(2 * day) - day)];
  final devices = [
    for (var i = 0; i < 5; i++) await newDevice('D$i', seed: seed * 10 + i, clock: clocks[i]),
  ];
  await pairAll(devices);
  final sw = Stopwatch()..start();
  final sessionSw = Stopwatch();
  var sessions = 0;
  var failed = 0;
  var envelopes = 0;
  var nextRow = 0;
  final rows = <String>[];
  for (var op = 0; op < ops; op++) {
    for (final c in clocks) {
      c.advance(1 + rng.nextInt(50));
    }
    final d = devices[rng.nextInt(5)];
    final roll = rng.nextDouble();
    if (roll < 0.25 || rows.isEmpty) {
      final pk = 'r${nextRow++}';
      rows.add(pk);
      createRow(d, pk, 'title $op');
    } else if (roll < 0.8) {
      final pk = rows[rng.nextInt(rows.length)];
      d.write(CellKey('task', pk, rng.nextBool() ? 'title' : 'note'), 'edit $op');
    } else if (roll < 0.9) {
      d.delete(row(rows[rng.nextInt(rows.length)]));
    } else if (roll < 0.95) {
      final parent = rows[rng.nextInt(rows.length)];
      d.cascadeDelete(row(parent), [for (var k = 0; k < 2; k++) row(rows[rng.nextInt(rows.length)])]);
    } else {
      final pk = rows[rng.nextInt(rows.length)];
      d.write(CellKey('task', pk, CellKey.existenceCol), null);
    }
    if (rng.nextDouble() < 0.25) {
      final i = rng.nextInt(5);
      var j = rng.nextInt(4);
      if (j >= i) j++;
      final faultRoll = rng.nextDouble();
      final faults = faultRoll < 0.1
          ? TransportFaults(cutAfter: 3 + rng.nextInt(20))
          : faultRoll < 0.15
              ? TransportFaults(duplicate: {3 + rng.nextInt(10)})
              : TransportFaults.none;
      sessionSw.start();
      final p = await SyncDevice.syncPair(devices[i], devices[j], faults: faults);
      sessionSw.stop();
      sessions++;
      if (!p.bothComplete) failed++;
      envelopes += p.initiator.stats.envelopesSent + p.responder.stats.envelopesSent;
    }
  }
  sessionSw.start();
  final rounds = await syncUntilQuiet(devices, maxRounds: 6);
  sessionSw.stop();
  sw.stop();
  final prints = {for (final d in devices) fingerprint(d.store)};
  expect(prints, hasLength(1), reason: 'all devices converge');
  expect(rounds, lessThanOrEqualTo(6));
  return _WorkloadResult(
      ops, sessions, sw.elapsedMilliseconds, sessionSw.elapsedMilliseconds, envelopes, failed, rounds);
}
