/// The in-memory transport's fault model and the Noise channel's chunked
/// framing.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

Uint8List _f(int n) => Uint8List.fromList([n]);

void main() {
  group('InMemoryTransport', () {
    test('delivers in order and closes after draining', () async {
      final (a, b) = InMemoryTransport.pair();
      await a.send(_f(1));
      await a.send(_f(2));
      await a.close();
      expect((await b.receive()).single, 1);
      expect((await b.receive()).single, 2);
      await expectLater(b.receive(), throwsA(isA<TransportClosedException>()));
      await expectLater(a.send(_f(3)), throwsA(isA<TransportClosedException>()));
    });

    test('cutAfter delivers the first k frames, then both ends are closed', () async {
      final trace = TransportTrace();
      final (a, b) = InMemoryTransport.pair(faults: const TransportFaults(cutAfter: 2), trace: trace);
      await a.send(_f(1));
      await b.send(_f(2));
      await expectLater(a.send(_f(3)), throwsA(isA<TransportClosedException>()));
      expect(trace.cut, isTrue);
      expect((await b.receive()).single, 1);
      expect((await a.receive()).single, 2);
      await expectLater(b.receive(), throwsA(isA<TransportClosedException>()));
      await expectLater(b.send(_f(4)), throwsA(isA<TransportClosedException>()));
    });

    test('duplicate and reorder faults', () async {
      final (a, b) = InMemoryTransport.pair(faults: const TransportFaults(duplicate: {0}, reorder: {1}));
      await a.send(_f(1));
      await a.send(_f(2));
      await a.send(_f(3));
      final got = [for (var i = 0; i < 4; i++) (await b.receive()).single];
      expect(got, [1, 1, 3, 2]);
    });

    test('a pending receive completes when a frame arrives', () async {
      final (a, b) = InMemoryTransport.pair();
      final pending = b.receive();
      await a.send(_f(9));
      expect((await pending).single, 9);
    });
  });

  test('frames above the Noise payload limit are chunked (a 1.5 MiB value syncs)', () async {
    final clock = TestClock();
    final a = await newDevice('A', seed: 1, clock: clock);
    final b = await newDevice('B', seed: 2, clock: clock);
    await SyncDevice.pair(inviter: a, joiner: b);
    final big = Uint8List.fromList(List<int>.generate(1536 * 1024, (i) => i * 31 & 0xff));
    a.write(const CellKey('note', 'n1', 'body'), big);
    final trace = TransportTrace();
    final r = await runSessionPair(a, b, trace: trace);
    expect(r.bothComplete, isTrue);
    expect(b.store.read(const CellKey('note', 'n1', 'body'))?.value, big);
    expect(trace.bytesSent, greaterThan(big.length));
    expect(trace.framesSent, greaterThan(big.length ~/ secureChunkBytes));
  });

  test('cells of tables, columns and value types unknown to this build are relayed unchanged (FR-042)', () async {
    final clock = TestClock();
    final a = await newDevice('A', seed: 3, clock: clock);
    final b = await newDevice('B', seed: 4, clock: clock);
    final c = await newDevice('C', seed: 5, clock: clock);
    await pairAll([a, b, c]);
    final unknown = UnknownValue(0x42, [1, 2, 3]);
    a.write(const CellKey('future_table', 'f1', 'future_col'), unknown);
    expect((await runSessionPair(a, b)).bothComplete, isTrue);
    expect((await runSessionPair(b, c)).bothComplete, isTrue);
    final relayed = c.store.read(const CellKey('future_table', 'f1', 'future_col'))!;
    expect(relayed.value, unknown);
    expect(relayed.origin, a.store.localOrigin.hex);
  });
}
