import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

void main() {
  const now = 1790000000000; // 2026-09 in ms.
  const twoYearsMs = 2 * 365 * 24 * 60 * 60 * 1000;

  group('Hlc packing', () {
    test('pack/unpack round-trips wall and counter', () {
      final hlc = Hlc.pack(now, 0x1234);
      expect(Hlc.wallOf(hlc), now);
      expect(Hlc.counterOf(hlc), 0x1234);
      expect(hlc, (now << 16) | 0x1234);
      expect(Hlc.pack(Hlc.wallLimitMs - 1, Hlc.counterMask), greaterThan(0));
    });

    test('pack rejects out-of-range parts', () {
      expect(() => Hlc.pack(-1, 0), throwsArgumentError);
      expect(() => Hlc.pack(Hlc.wallLimitMs, 0), throwsArgumentError);
      expect(() => Hlc.pack(now, -1), throwsArgumentError);
      expect(() => Hlc.pack(now, 0x10000), throwsArgumentError);
    });

    test('well-formedness: wall in [0, 2^46)', () {
      expect(Hlc.isWellFormed(0), isTrue);
      expect(Hlc.isWellFormed(Hlc.pack(Hlc.wallLimitMs - 1, Hlc.counterMask)), isTrue);
      expect(Hlc.isWellFormed(Hlc.wallLimitMs << Hlc.counterBits), isFalse);
      expect(Hlc.isWellFormed(-1), isFalse);
      expect(() => Hlc.checkWellFormed(-(now << 16)), throwsA(isA<MalformedHlcException>()));
    });
  });

  group('Hlc.compareVersions', () {
    test('larger hlc wins regardless of node', () {
      expect(Hlc.compareVersions(Hlc.pack(now, 1), 'z', Hlc.pack(now, 0), 'a'), greaterThan(0));
      expect(Hlc.compareVersions(Hlc.pack(now, 0), 'a', Hlc.pack(now + 1, 0), 'z'), lessThan(0));
    });

    test('exact tie: the smaller node wins', () {
      final hlc = Hlc.pack(now, 7);
      expect(Hlc.compareVersions(hlc, 'member-a', hlc, 'member-b'), greaterThan(0));
      expect(Hlc.compareVersions(hlc, 'member-b', hlc, 'member-a'), lessThan(0));
      expect(Hlc.compareVersions(hlc, 'member-a', hlc, 'member-a'), 0);
    });
  });

  group('HlcClock', () {
    test('local tick is strictly increasing even when the wall clock goes back', () {
      final clock = HlcClock();
      final a = clock.tick(now);
      final b = clock.tick(now - 60000);
      final c = clock.tick(now);
      expect(a, Hlc.pack(now, 0));
      expect(b, Hlc.pack(now, 1));
      expect(c, Hlc.pack(now, 2));
      expect(clock.tick(now + 5), Hlc.pack(now + 5, 0));
    });

    test('counter overflow: 65,537 ticks at a frozen wall are strictly increasing and carry into the wall', () {
      final clock = HlcClock();
      var previous = -1;
      final values = <int>[];
      for (var i = 0; i < 65537; i++) {
        final next = clock.tick(now);
        expect(next, greaterThan(previous));
        previous = next;
        values.add(next);
      }
      expect(Hlc.wallOf(values.first), now);
      expect(Hlc.counterOf(values[65535]), 0xFFFF);
      expect(Hlc.wallOf(values[65535]), now);
      expect(Hlc.wallOf(values.last), now + 1);
      expect(Hlc.counterOf(values.last), 0);
    });

    test('remote HLC two years ahead is accepted, advances the clock, and a later local tick exceeds it', () {
      final clock = HlcClock()..tick(now);
      final remote = Hlc.pack(now + twoYearsMs, 3);
      clock.receive(remote);
      expect(clock.current, remote);
      final local = clock.tick(now);
      expect(local, greaterThan(remote));
      expect(Hlc.compareVersions(local, 'z-late-node', remote, 'a-node'), greaterThan(0));
    });

    test('receive keeps the larger value (no regression on an older remote)', () {
      final clock = HlcClock()..tick(now);
      final before = clock.current;
      clock.receive(Hlc.pack(now - 1000, 0));
      expect(clock.current, before);
    });

    test('remote wall >= 2^46 or negative is rejected as malformed and leaves the clock unchanged', () {
      final clock = HlcClock()..tick(now);
      final before = clock.current;
      expect(() => clock.receive(Hlc.wallLimitMs << Hlc.counterBits), throwsA(isA<MalformedHlcException>()));
      expect(() => clock.receive(((Hlc.wallLimitMs + 12345) << Hlc.counterBits) | 9),
          throwsA(isA<MalformedHlcException>()));
      expect(() => clock.receive(-1), throwsA(isA<MalformedHlcException>()));
      expect(() => clock.receive(-(now << 16)), throwsA(isA<MalformedHlcException>()));
      expect(clock.current, before);
      clock.receive(Hlc.pack(Hlc.wallLimitMs - 1, 0));
      expect(Hlc.wallOf(clock.current), Hlc.wallLimitMs - 1);
    });

    test('rejects invalid local input', () {
      expect(() => HlcClock(-1), throwsArgumentError);
      expect(() => HlcClock().tick(-1), throwsArgumentError);
      expect(() => HlcClock().tick(Hlc.wallLimitMs), throwsArgumentError);
      final exhausted = HlcClock(Hlc.pack(Hlc.wallLimitMs - 1, Hlc.counterMask));
      expect(() => exhausted.tick(now), throwsStateError);
    });
  });

  group('HlcMergePolicy', () {
    test('stamps with the HLC, observes remotes and rejects malformed ones', () {
      final policy = HlcMergePolicy();
      expect(policy.stampLocal(now), Hlc.pack(now, 0));
      CellRecord remote(int clock) => CellRecord(
            key: const CellKey('task', 'p', 'title'),
            value: 'x',
            clock: clock,
            node: 'b',
            origin: 'ob',
            originSeq: 1,
          );
      policy.observeRemote(remote(Hlc.pack(now + twoYearsMs, 0)));
      expect(policy.stampLocal(now), Hlc.pack(now + twoYearsMs, 1));
      expect(() => policy.observeRemote(remote(Hlc.wallLimitMs << 16)), throwsA(isA<MalformedHlcException>()));
      expect(policy.clock.current, Hlc.pack(now + twoYearsMs, 1));
    });
  });
}
