import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// Orders by clock, then the smaller node; no clock state.
final class _PlainPolicy implements MergePolicy {
  @override
  int stampLocal(int nowMs) => nowMs;

  @override
  void observeRemote(CellRecord remote) {}

  @override
  int compare(CellRecord a, CellRecord b) => a.clock != b.clock ? a.clock.compareTo(b.clock) : b.node.compareTo(a.node);
}

InMemoryReplicaStore _store(String node) => InMemoryReplicaStore(nodeId: node, policy: _PlainPolicy());

const _x = CellKey('t', '1', 'x');
const _y = CellKey('t', '1', 'y');
const _tomb = CellKey('t', '1', CellKey.existenceCol);

void main() {
  test('local writes get consecutive own seqs and advance the own cursor', () {
    final a = _store('a');
    final first = a.writeLocal(_x, 'v1', nowMs: 10);
    final second = a.writeLocal(_x, 'v2', nowMs: 5);
    expect([first.originSeq, second.originSeq], [1, 2]);
    expect(a.read(_x)!.value, 'v2', reason: 'a local write always replaces');
    expect(a.vector, {'a': 2});
  });

  test('changesSince skips superseded seqs and declares the held bound', () {
    final a = _store('a')
      ..writeLocal(_x, 'v1', nowMs: 1)
      ..writeLocal(_y, 'w', nowMs: 2)
      ..writeLocal(_x, 'v2', nowMs: 3);
    final batches = a.changesSince(const {}, maxCellsPerBatch: 1);
    expect([for (final b in batches) (b.fromSeq, b.toSeq, b.cells.length)], [(0, 2, 1), (2, 3, 1)]);
    expect(a.changesSince({'a': 3}), isEmpty);
  });

  test('applyBatch merges by policy, is idempotent and advances only contiguous cursors', () {
    final a = _store('a')
      ..writeLocal(_x, 'v1', nowMs: 1)
      ..writeLocal(_y, 'w', nowMs: 2);
    final b = _store('b');
    final batches = a.changesSince(const {}, maxCellsPerBatch: 1);
    expect(b.applyBatch(batches[1]), isTrue, reason: 'cell stored though the cursor cannot move');
    expect(b.vector, isEmpty);
    expect(b.applyBatch(batches[0]), isTrue);
    expect(b.vector, {'a': 1});
    expect(b.applyBatch(batches[1]), isTrue);
    expect(b.vector, {'a': 2});
    expect(b.applyBatch(batches[1]), isFalse, reason: 'duplicates are no-ops');

    b.writeLocal(_x, 'newer', nowMs: 50);
    expect(b.applyBatch(batches[0]), isFalse, reason: 'an older version never replaces a newer one');
    expect(b.read(_x)!.value, 'newer');
  });

  test('a tombstone beaten by a later edit of another cell leaves the row alive', () {
    final a = _store('a')
      ..writeLocal(_x, 'v', nowMs: 1)
      ..writeLocal(_tomb, null, nowMs: 1);
    expect(a.isRowAlive('t', '1'), isTrue);
    a.writeLocal(_tomb, 5, nowMs: 5);
    expect(a.isRowAlive('t', '1'), isFalse);
    a.writeLocal(_y, 'late', nowMs: 9);
    expect(a.isRowAlive('t', '1'), isTrue);
    expect(a.rowsOf('t'), ['1']);
  });
}
