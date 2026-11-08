import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'merge_test_support.dart';

const _now = 1790000000000;
const _hour = 60 * 60 * 1000;
const _title = CellKey('task', 't1', 'title');

InMemoryReplicaStore _replica(String node) => InMemoryReplicaStore(nodeId: node, policy: HlcMergePolicy());

void _pull(ReplicaStore from, ReplicaStore into) {
  for (final batch in from.changesSince(into.vector)) {
    into.applyBatch(batch);
  }
}

void main() {
  test('Scenario 1.3: causal order beats clocks (B is 3 h behind A)', () {
    final a = _replica('device-a');
    final b = _replica('device-b');
    a.writeLocal(_title, 'edit on A', nowMs: _now);
    _pull(a, b);
    // B's wall clock is 3 hours behind; the user edits after receiving A's edit.
    b.writeLocal(_title, 'later edit on B', nowMs: _now - 3 * _hour + 60000);
    _pull(b, a);
    _pull(a, b);
    expect(a.read(_title)!.value, 'later edit on B');
    expect(b.read(_title)!.value, 'later edit on B');
    expect(a.read(_title)!.clock, greaterThan(Hlc.pack(_now, 0)));
  });

  test('Scenario 1.3 (unit): a tick after receive beats the received version whatever the wall clock', () {
    final clockA = HlcClock();
    final clockB = HlcClock();
    final editA = cell('task', 't1', 'title', 'A', hlc: clockA.tick(_now), node: 'device-z');
    clockB.receive(editA.clock);
    final editB = cell('task', 't1', 'title', 'B', hlc: clockB.tick(_now - 3 * _hour), node: 'device-y');
    expect(mergeCell(editA, editB).value, 'B');
    expect(mergeCell(editB, editA).value, 'B');
  });

  test('Scenario 1.5: no stale override (B receives C\'s newer edit before A\'s older one)', () {
    final a = _replica('device-a');
    final b = _replica('device-b');
    final c = _replica('device-c');
    a.writeLocal(_title, 'older from A', nowMs: _now);
    c.writeLocal(_title, 'newer from C', nowMs: _now + 60000);
    _pull(c, b);
    _pull(a, b);
    expect(b.read(_title)!.value, 'newer from C');
    // Full mesh: every device ends with C's edit.
    for (var round = 0; round < 2; round++) {
      for (final from in [a, b, c]) {
        for (final into in [a, b, c]) {
          if (!identical(from, into)) _pull(from, into);
        }
      }
    }
    for (final replica in [a, b, c]) {
      expect(replica.read(_title)!.value, 'newer from C', reason: replica.nodeId);
    }
  });

  test('re-applying the same batch is a no-op (FR-013)', () {
    final a = _replica('device-a');
    final b = _replica('device-b');
    a.writeLocal(_title, 'x', nowMs: _now);
    final batches = a.changesSince(b.vector);
    expect(b.applyBatch(batches.single), isTrue);
    final held = b.read(_title);
    expect(b.applyBatch(batches.single), isFalse);
    expect(identical(b.read(_title), held), isTrue);
  });

  group('FR-002 / FR-006 / FR-007 at cell level', () {
    final t1 = Hlc.pack(_now, 0);
    final t2 = Hlc.pack(_now + 1000, 0);
    final t3 = Hlc.pack(_now + 2000, 0);

    test('edits of different fields are both kept', () {
      final state = stateOf([
        cell('task', 'x', 'title', 'T', hlc: t1, node: 'a'),
        cell('task', 'x', 'body', 'B', hlc: t2, node: 'b'),
      ]);
      expect(state[const CellKey('task', 'x', 'title')]!.value, 'T');
      expect(state[const CellKey('task', 'x', 'body')]!.value, 'B');
    });

    test('a delete later than a concurrent edit wins', () {
      final writes = [
        cell('task', 'x', 'title', 'created', hlc: t1, node: 'a'),
        cell('task', 'x', 'title', 'edit', hlc: t2, node: 'b'),
        cell('task', 'x', '~', 12345, hlc: t3, node: 'a'),
      ];
      expect(existenceIn(stateOf(writes), 'task', 'x'), RowExistence.deleted);
      expect(existenceIn(stateOf(writes.reversed), 'task', 'x'), RowExistence.deleted);
    });

    test('an edit later than a delete revives the row with edited data and other fields per their cells', () {
      final writes = [
        cell('task', 'x', 'title', 'created', hlc: t1, node: 'a'),
        cell('task', 'x', 'body', 'old body', hlc: t1, node: 'a'),
        cell('task', 'x', '~', 12345, hlc: t2, node: 'a'),
        cell('task', 'x', 'title', 'edited offline', hlc: t3, node: 'b'),
      ];
      for (final order in [writes, writes.reversed.toList()]) {
        final state = stateOf(order);
        expect(existenceIn(state, 'task', 'x'), RowExistence.alive);
        expect(state[const CellKey('task', 'x', 'title')]!.value, 'edited offline');
        expect(state[const CellKey('task', 'x', 'body')]!.value, 'old body');
      }
    });

    test('a version older than a known deletion does not restore the row (FR-007)', () {
      final deleted = stateOf([
        cell('task', 'x', 'title', 'v2', hlc: t2, node: 'a'),
        cell('task', 'x', '~', 12345, hlc: t3, node: 'a'),
      ]);
      final afterStale = mergeInto(deleted, [cell('task', 'x', 'title', 'v1', hlc: t1, node: 'b')]);
      expect(afterStale[const CellKey('task', 'x', 'title')]!.value, 'v2');
      expect(existenceIn(afterStale, 'task', 'x'), RowExistence.deleted);
    });

    test('a revival cell (~ = null) makes the row alive; no ~ cell means alive; no cells means absent', () {
      expect(
        existenceIn(
            stateOf([
              cell('task', 'x', '~', 12345, hlc: t1, node: 'a'),
              cell('task', 'x', '~', null, hlc: t2, node: 'b'),
            ]),
            'task',
            'x'),
        RowExistence.alive,
      );
      expect(
          existenceIn(stateOf([cell('task', 'x', 'title', 'T', hlc: t1, node: 'a')]), 'task', 'x'), RowExistence.alive);
      expect(existenceIn({}, 'task', 'x'), RowExistence.absent);
    });

    test('a tombstone and an edit with the same (hlc, node) leave the tombstone in force', () {
      final state = stateOf([
        cell('task', 'x', 'title', 'T', hlc: t1, node: 'a'),
        cell('task', 'x', '~', 1, hlc: t1, node: 'a'),
      ]);
      expect(existenceIn(state, 'task', 'x'), RowExistence.deleted);
    });

    test('tombstone vs edit uses the (hlc, node) order on exact HLC ties', () {
      final smallerNodeEdit = stateOf([
        cell('task', 'x', 'title', 'T', hlc: t2, node: 'a'),
        cell('task', 'x', '~', 1, hlc: t2, node: 'b'),
      ]);
      expect(existenceIn(smallerNodeEdit, 'task', 'x'), RowExistence.alive);
      final smallerNodeDelete = stateOf([
        cell('task', 'x', 'title', 'T', hlc: t2, node: 'b'),
        cell('task', 'x', '~', 1, hlc: t2, node: 'a'),
      ]);
      expect(existenceIn(smallerNodeDelete, 'task', 'x'), RowExistence.deleted);
    });
  });
}
