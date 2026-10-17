import 'package:test/test.dart';

import 'oracle/oracle_checks.dart';
import 'oracle/oracle_hlc.dart';
import 'oracle/reference_oracle.dart';

void main() {
  group('OracleHlc', () {
    test('local tick is max(prev + 1, now << 16) and carries counter overflow', () {
      final clock = OracleHlc();
      expect(clock.tick(1000), oracleHlcPack(1000, 0));
      expect(clock.tick(1000), oracleHlcPack(1000, 1));
      expect(clock.tick(999), oracleHlcPack(1000, 2), reason: 'a clock moving backwards still advances');
      clock.receive(oracleHlcPack(1000, oracleCounterMask));
      expect(clock.tick(1000), oracleHlcPack(1001, 0));
    });

    test('receive keeps the maximum', () {
      final clock = OracleHlc()..tick(5000);
      clock.receive(oracleHlcPack(4000, 9));
      expect(clock.current, oracleHlcPack(5000, 0));
      clock.receive(oracleHlcPack(9000, 3));
      expect(clock.tick(100), oracleHlcPack(9000, 4));
    });

    test('versions order by hlc, then the smaller node wins exact ties', () {
      expect(oracleCompareVersions(2, 'b', 1, 'a'), isPositive);
      expect(oracleCompareVersions(1, 'a', 1, 'b'), isPositive);
      expect(oracleCompareVersions(1, 'b', 1, 'a'), isNegative);
    });
  });

  group('ReferenceOracle', () {
    const day = 24 * 60 * 60 * 1000;

    test('FR-003: a causally later edit wins despite an earlier wall clock', () {
      final oracle = ReferenceOracle(['a', 'b']);
      final first = oracle.recordWrite(device: 'a', wallMs: 10 * day, table: 't', pk: '1', col: 'x', value: 'A');
      oracle.recordDelivery('b', first.id);
      final later = oracle.recordWrite(device: 'b', wallMs: 9 * day, table: 't', pk: '1', col: 'x', value: 'B');
      expect(oracle.happenedBefore(first, later), isTrue);
      expect(oracle.winner(later.cellKey)!.id, later.id);
    });

    test('FR-004: concurrent edits keep the later recorded time', () {
      final oracle = ReferenceOracle(['a', 'b']);
      oracle.recordWrite(device: 'a', wallMs: 2000, table: 't', pk: '1', col: 'x', value: 'A');
      final b = oracle.recordWrite(device: 'b', wallMs: 1000, table: 't', pk: '1', col: 'x', value: 'B');
      expect(oracle.winner(b.cellKey)!.value, 'A');
    });

    test('FR-006: a later edit revives a deleted row, an earlier one does not', () {
      final oracle = ReferenceOracle(['a', 'b']);
      final create = oracle.recordWrite(device: 'a', wallMs: 1000, table: 't', pk: '1', col: 'x', value: 'v');
      oracle.recordWrite(device: 'a', wallMs: 1000, table: 't', pk: '1', col: '~', value: null);
      oracle.recordDelivery('b', create.id);
      oracle.recordWrite(device: 'a', wallMs: 3000, table: 't', pk: '1', col: '~', value: 3000);
      expect(oracle.expectedAlive(create.rowKey), isFalse);
      oracle.recordWrite(device: 'b', wallMs: 2000, table: 't', pk: '1', col: 'x', value: 'early');
      expect(oracle.expectedAlive(create.rowKey), isFalse);
      oracle.recordWrite(device: 'b', wallMs: 4000, table: 't', pk: '1', col: 'x', value: 'late');
      expect(oracle.expectedAlive(create.rowKey), isTrue);
    });

    test('D12: bucket totals sum winners and non-owner writes are flagged', () {
      final oracle = ReferenceOracle(['a', 'b']);
      const info = OracleBucketInfo(ownerDevice: 'a', group: 'g');
      oracle.recordWrite(device: 'a', wallMs: 1, table: 'bucket', pk: 'g@a', col: '*', value: 5, bucket: info);
      oracle.recordWrite(device: 'a', wallMs: 1, table: 'bucket', pk: 'g@a', col: '~', value: null, bucket: info);
      const infoB = OracleBucketInfo(ownerDevice: 'b', group: 'g');
      oracle.recordWrite(device: 'b', wallMs: 1, table: 'bucket', pk: 'g@b', col: '*', value: -2, bucket: infoB);
      expect(oracle.expectedBucketTotals(), {'g': 3});
      expect(oracle.recordingViolations, isEmpty);
      oracle.recordWrite(device: 'b', wallMs: 2, table: 'bucket', pk: 'g@a', col: '*', value: 1, bucket: info);
      expect(oracle.recordingViolations.single.kind, OracleViolationKind.bucketOwnership);
    });
  });

  group('ReferenceOracle with engine stamps', () {
    int hlc(int wall, [int counter = 0]) => oracleHlcPack(wall, counter);

    OracleWrite put(ReferenceOracle o, String device, int wall, int stamp, String node, String col, Object? value,
            {String pk = '1', String? cause}) =>
        o.recordWrite(
            device: device,
            wallMs: wall,
            table: 't',
            pk: pk,
            col: col,
            value: value,
            hlc: stamp,
            node: node,
            cause: cause);

    test('the engine stamp is the recorded edit time; ties go to the smaller node', () {
      final oracle = ReferenceOracle(['a', 'b']);
      final a = put(oracle, 'a', 1000, hlc(1000), 'na', 'x', 'A');
      final b = put(oracle, 'b', 1000, hlc(1000), 'nb', 'x', 'B');
      expect(oracle.compare(a, b), isPositive, reason: 'exact tie: the smaller node wins');
      expect(oracle.writeIdOfVersion('t', '1', 'x', 'nb', hlc(1000)), b.id);
      expect(oracle.recordingViolations, isEmpty);
    });

    test('causality: a causally later write with a smaller stamp is reported, not thrown', () {
      final oracle = ReferenceOracle(['a', 'b']);
      final first = put(oracle, 'a', 5000, hlc(5000), 'na', 'x', 'A');
      oracle.observeStored('b', first.id);
      final later = put(oracle, 'b', 4000, hlc(4000), 'nb', 'x', 'B');
      expect(oracle.recordingViolations.single.kind, OracleViolationKind.causality);
      expect(oracle.compare(later, first), isPositive, reason: 'the oracle keeps the causal order');
    });

    test('hlcTick: a stamp below the wall clock is reported', () {
      final oracle = ReferenceOracle(['a']);
      put(oracle, 'a', 5000, hlc(4999, 7), 'na', 'x', 'A');
      expect(oracle.recordingViolations.single.kind, OracleViolationKind.hlcTick);
    });

    test('ambiguousVersion: two writes with the same (table, pk, col, node, hlc)', () {
      final oracle = ReferenceOracle(['a', 'b']);
      put(oracle, 'a', 1000, hlc(1000), 'n', 'x', 'A');
      put(oracle, 'b', 1000, hlc(1000), 'n', 'x', 'B');
      expect(oracle.recordingViolations.single.kind, OracleViolationKind.ambiguousVersion);
    });

    test('incarnations: a restored device knows only what its snapshot knew', () {
      final oracle = ReferenceOracle(['a', 'b']);
      final w1 = put(oracle, 'a', 1000, hlc(1000), 'na', 'x', 'v1');
      oracle.observeStored('b', w1.id);
      final saved = oracle.knowledgeOf('b');
      final w2 = put(oracle, 'a', 2000, hlc(2000), 'na', 'x', 'v2');
      oracle.observeStored('b', w2.id);
      oracle.startIncarnation('b', saved);
      // b's new incarnation knew w1 but not w2: its write follows w1 only.
      final w3 = put(oracle, 'b', 1500, hlc(1500), 'nb', 'x', 'v3');
      expect(oracle.happenedBefore(w1, w3), isTrue);
      expect(oracle.happenedBefore(w2, w3), isFalse);
      expect(oracle.compare(w2, w3), isPositive, reason: 'concurrent: the later stamp wins');
      expect(w3.actor, isNot(oracle.write(w1.id).actor));
      expect(w3.seqOnActor, 1, reason: 'a new incarnation never reuses sequence numbers');
      expect(oracle.incarnations, 3);
      expect(oracle.recordingViolations, isEmpty);
    });

    test('cascade existence: a child tombstone is in force only while its cause is deleted', () {
      final oracle = ReferenceOracle(['a']);
      final winners = <String, OracleWrite>{};
      void w(int t, String pk, String col, Object? value, {String? cause}) {
        final x = put(oracle, 'a', t, hlc(t), 'na', col, value, pk: pk, cause: cause);
        winners[x.cellKey] = x;
      }

      w(1, 'p', 'title', 'P');
      w(2, 'c', 'title', 'C');
      w(3, 'p', '~', 3);
      w(4, 'c', '~', 4, cause: 't|p');
      bool alive(String pk) => oracle.effectiveAlive('t|$pk', (k) => winners[k]);
      expect(alive('p'), isFalse);
      expect(alive('c'), isFalse);
      w(5, 'p', 'title', 'P revived by a later edit');
      expect(alive('p'), isTrue);
      expect(alive('c'), isTrue, reason: 'the cause is alive, so the cascaded tombstone is not in force');
      w(6, 'q', '~', 6, cause: 't|r');
      w(7, 'r', '~', 7, cause: 't|q');
      expect(alive('q'), isFalse, reason: 'a cause cycle counts as deleted');
      w(8, 'orphan', '~', 8, cause: 't|absent');
      expect(alive('orphan'), isFalse, reason: 'an absent cause counts as deleted');
    });

    ObservedReplica replica(String name, ReferenceOracle oracle, List<OracleWrite> held) => ObservedReplica(
          device: name,
          cells: {
            for (final w in held)
              w.cellKey: ObservedCell(value: w.value, writeId: w.id, author: w.device, cause: w.cause)
          },
          rowsAlive: {
            for (final w in held)
              w.rowKey: oracle.effectiveAlive(w.rowKey, (k) => held.where((x) => x.cellKey == k).firstOrNull)
          },
        );

    test('required vs allowed: a lost unrequired version is an allowed discard, a beaten required one is not', () {
      final oracle = ReferenceOracle(['a', 'b']);
      final kept = put(oracle, 'a', 1000, hlc(1000), 'na', 'x', 'kept');
      final lost = put(oracle, 'b', 3000, hlc(3000), 'nb', 'x', 'lost by restore');
      final ok = checkEngineFinalState(oracle, [
        replica('a', oracle, [kept]),
        replica('b', oracle, [kept])
      ], required: {
        kept.id
      }, optional: {});
      expect(ok.violations, isEmpty);
      expect(ok.discards['lostFinal'], 1, reason: '$lost would have won but was not required');

      final bad = checkEngineFinalState(oracle, [
        replica('a', oracle, [kept]),
        replica('b', oracle, [kept])
      ], required: {
        kept.id,
        lost.id
      }, optional: {});
      expect(bad.violations.map((v) => v.kind), everyElement(OracleViolationKind.lostEdit));
      expect(bad.violations, hasLength(2));
    });

    test('an optional (revoked) version may win; an alive version replacing a required tombstone is a resurrection',
        () {
      final oracle = ReferenceOracle(['a', 'o']);
      final alive = put(oracle, 'a', 1000, hlc(1000), 'na', '~', null);
      final revoked = put(oracle, 'o', 2000, hlc(2000), 'no', 'x', 'revoked author');
      final tomb = put(oracle, 'a', 3000, hlc(3000), 'na', '~', 3000);
      final held = [alive, revoked];
      final result = checkEngineFinalState(oracle, [replica('a', oracle, held)],
          required: {alive.id, tomb.id}, optional: {revoked.id});
      expect(result.violations.map((v) => v.kind), [OracleViolationKind.resurrection]);

      final unknown = checkEngineFinalState(oracle, [
        replica('a', oracle, [tomb, revoked])
      ], required: {
        tomb.id
      }, optional: {});
      expect(unknown.violations.map((v) => v.kind), [OracleViolationKind.unknownVersion]);
    });

    test('existence mismatch against the engine is reported', () {
      final oracle = ReferenceOracle(['a']);
      final p = put(oracle, 'a', 1, hlc(1), 'na', '~', 1, pk: 'p');
      final c = put(oracle, 'a', 2, hlc(2), 'na', '~', 2, pk: 'c', cause: 't|p');
      final observed = ObservedReplica(
        device: 'a',
        cells: {
          for (final w in [p, c]) w.cellKey: ObservedCell(value: w.value, writeId: w.id, author: 'a', cause: w.cause)
        },
        rowsAlive: {'t|p': false, 't|c': true},
      );
      final result = checkEngineFinalState(oracle, [observed], required: {p.id, c.id}, optional: {});
      expect(result.violations.map((v) => '${v.kind.name}@${v.subject}'), ['resurrection@t|c']);
    });
  });
}
