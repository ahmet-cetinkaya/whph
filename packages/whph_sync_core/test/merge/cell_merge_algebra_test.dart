import 'dart:math';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'merge_test_support.dart';

const _iterations = 10000;
const _seed = 0x5EED9;

const _pks = ['p1', 'p2', 'p3'];
const _cols = [CellKey.existenceCol, 'title', 'body'];
const _nodes = ['a', 'b', 'c'];
const _values = <Object?>[null, 0, 1, 'x', 'y'];

/// A small key and clock space so ties, duplicates and stale versions are
/// frequent, including degenerate same-`(hlc, node)` collisions.
CellRecord _randomCell(Random rng) {
  final col = _cols[rng.nextInt(_cols.length)];
  final isExistence = col == CellKey.existenceCol;
  final pk = _pks[rng.nextInt(_pks.length)];
  return cell(
    't',
    pk,
    col,
    _values[rng.nextInt(_values.length)],
    hlc: Hlc.pack(1000 + rng.nextInt(4), rng.nextInt(3)),
    node: _nodes[rng.nextInt(_nodes.length)],
    seq: 1 + rng.nextInt(3),
    cause: isExistence && rng.nextBool() ? RowRef('t', _pks[rng.nextInt(_pks.length)]) : null,
  );
}

List<CellRecord> _randomSet(Random rng) => [for (var i = rng.nextInt(12); i > 0; i--) _randomCell(rng)];

CellState _merge(CellState a, CellState b) => mergeInto(a, b.values);

Map<String, RowExistence> _existences(CellState state) => {for (final pk in _pks) pk: existenceIn(state, 't', pk)};

void main() {
  test('merge is commutative, associative and idempotent over $_iterations random cell sets (seed $_seed)', () {
    final rng = Random(_seed);
    for (var i = 0; i < _iterations; i++) {
      final a = stateOf(_randomSet(rng));
      final b = stateOf(_randomSet(rng));
      final c = stateOf(_randomSet(rng));
      final ab = _merge(a, b);
      final reason = 'iteration $i';

      expect(sameState(ab, _merge(b, a)), isTrue, reason: '$reason: commutativity');
      expect(sameState(_merge(ab, c), _merge(a, _merge(b, c))), isTrue, reason: '$reason: associativity');
      expect(sameState(_merge(a, a), a), isTrue, reason: '$reason: idempotence');
      expect(sameState(_merge(ab, b), ab), isTrue, reason: '$reason: re-apply is a no-op');
      expect(_existences(ab), _existences(_merge(b, a)), reason: '$reason: existence is order-independent');
    }
  });

  test('any delivery order of the same writes, with duplicates, converges to the same state and existence', () {
    final rng = Random(_seed + 1);
    for (var i = 0; i < 2000; i++) {
      final writes = _randomSet(rng)..addAll(_randomSet(rng));
      final reference = stateOf(writes);
      final shuffled = [...writes, ...writes.take(rng.nextInt(writes.length + 1))]..shuffle(rng);
      final other = stateOf(shuffled);
      expect(sameState(reference, other), isTrue, reason: 'iteration $i');
      expect(_existences(reference), _existences(other), reason: 'iteration $i');
    }
  });

  test('a stale version never overwrites and re-apply keeps the same instance', () {
    final newer = cell('t', 'p', 'title', 'new', hlc: Hlc.pack(2000, 0), node: 'b');
    final older = cell('t', 'p', 'title', 'old', hlc: Hlc.pack(1000, 0), node: 'a');
    expect(identical(mergeCell(newer, older), newer), isTrue);
    expect(identical(mergeCell(newer, newer), newer), isTrue);
    expect(incomingWins(newer, older), isFalse);
    expect(incomingWins(null, older), isTrue);
    expect(() => mergeCell(newer, cell('t', 'p', 'body', 'x', hlc: 1, node: 'a')), throwsArgumentError);
  });

  test('exact (hlc, node) tie across distinct nodes: the smaller node wins', () {
    final hlc = Hlc.pack(1000, 4);
    final fromA = cell('t', 'p', 'title', 'from a', hlc: hlc, node: 'member-a');
    final fromB = cell('t', 'p', 'title', 'from b', hlc: hlc, node: 'member-b');
    expect(mergeCell(fromA, fromB).value, 'from a');
    expect(mergeCell(fromB, fromA).value, 'from a');
    expect(compareCellVersions(fromA, fromB), greaterThan(0));
  });
}
