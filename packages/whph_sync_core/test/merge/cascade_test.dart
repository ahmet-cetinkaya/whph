import 'dart:math';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'merge_test_support.dart';

const _now = 1790000000000;
const _parent = RowRef('task', 'parent');

int _h(int step) => Hlc.pack(_now + step * 1000, 0);

/// Device A deletes the parent at step 3; the cascade tombstones the cause-
/// linked subtask and task tag. Independently (no cause) the user deleted
/// subtask "other" at step 3 on device C.
List<CellRecord> _baseWrites() => [
      cell('task', 'parent', 'title', 'Parent', hlc: _h(1), node: 'a'),
      cell('task', 'child', 'title', 'Child', hlc: _h(1), node: 'a'),
      cell('task', 'child', 'parent_task_id', 'parent', hlc: _h(1), node: 'a'),
      cell('task_tag', 'link', '*', 'parent|tag', hlc: _h(1), node: 'a'),
      cell('task', 'other', 'title', 'Other', hlc: _h(1), node: 'a'),
      cell('task', 'other', 'parent_task_id', 'parent', hlc: _h(1), node: 'a'),
      // Cascade delete on A.
      cell('task', 'parent', '~', 3000, hlc: _h(3), node: 'a'),
      cell('task', 'child', '~', 3000, hlc: _h(3) + 1, node: 'a', cause: _parent),
      cell('task_tag', 'link', '~', 3000, hlc: _h(3) + 2, node: 'a', cause: _parent),
      // Independent delete on C.
      cell('task', 'other', '~', 3000, hlc: _h(3), node: 'c'),
    ];

/// Concurrent parent edit on device B, later than A's delete.
final _parentEdit = cell('task', 'parent', 'title', 'Parent edited on B', hlc: _h(4), node: 'b');

Map<String, RowExistence> _existence(CellState state) => {
      'parent': existenceIn(state, 'task', 'parent'),
      'child': existenceIn(state, 'task', 'child'),
      'link': existenceIn(state, 'task_tag', 'link'),
      'other': existenceIn(state, 'task', 'other'),
    };

void main() {
  test('cascade delete without a later parent edit: parent and cause-linked children deleted', () {
    expect(_existence(stateOf(_baseWrites())), {
      'parent': RowExistence.deleted,
      'child': RowExistence.deleted,
      'link': RowExistence.deleted,
      'other': RowExistence.deleted,
    });
  });

  test(
      'parent tombstone + concurrent later parent edit: parent and cause-linked children alive, '
      'independently deleted child stays deleted', () {
    final state = stateOf([..._baseWrites(), _parentEdit]);
    expect(_existence(state), {
      'parent': RowExistence.alive,
      'child': RowExistence.alive,
      'link': RowExistence.alive,
      'other': RowExistence.deleted,
    });
    // Revived children keep their own cells.
    expect(state[const CellKey('task', 'child', 'title')]!.value, 'Child');
  });

  test('the outcome is a pure function of the cells: any delivery order agrees', () {
    final writes = [..._baseWrites(), _parentEdit];
    final expected = _existence(stateOf(writes));
    final rng = Random(42);
    for (var i = 0; i < 500; i++) {
      final shuffled = [...writes]..shuffle(rng);
      expect(_existence(stateOf(shuffled)), expected, reason: 'order $i');
    }
  });

  test('parent deleted again later: cause-linked children are deleted again', () {
    final state = stateOf([
      ..._baseWrites(),
      _parentEdit,
      cell('task', 'parent', '~', 5000, hlc: _h(5), node: 'b'),
    ]);
    expect(_existence(state), {
      'parent': RowExistence.deleted,
      'child': RowExistence.deleted,
      'link': RowExistence.deleted,
      'other': RowExistence.deleted,
    });
  });

  test('a later child edit beating the child\'s own tombstone keeps the child alive', () {
    final childEdit = cell('task', 'child', 'title', 'Child edited', hlc: _h(6), node: 'c');
    final state = stateOf([
      ..._baseWrites(),
      _parentEdit,
      cell('task', 'parent', '~', 5000, hlc: _h(5), node: 'b'),
      childEdit,
    ]);
    expect(existenceIn(state, 'task', 'parent'), RowExistence.deleted);
    expect(existenceIn(state, 'task', 'child'), RowExistence.alive);
    expect(existenceIn(state, 'task_tag', 'link'), RowExistence.deleted);

    // Also without any parent revival.
    expect(existenceIn(stateOf([..._baseWrites(), childEdit]), 'task', 'child'), RowExistence.alive);
  });

  test('parent revived by a revival cell (~ = null) revives cause-linked children', () {
    final state = stateOf([..._baseWrites(), cell('task', 'parent', '~', null, hlc: _h(4), node: 'b')]);
    expect(existenceIn(state, 'task', 'child'), RowExistence.alive);
    expect(existenceIn(state, 'task', 'other'), RowExistence.deleted);
  });

  test('a child whose cause row is absent or itself cause-deleted stays deleted; nested causes follow the root', () {
    final absentCause = stateOf([
      cell('task', 'orphan', 'title', 'O', hlc: _h(1), node: 'a'),
      cell('task', 'orphan', '~', 1, hlc: _h(2), node: 'a', cause: const RowRef('task', 'missing')),
    ]);
    expect(existenceIn(absentCause, 'task', 'orphan'), RowExistence.deleted);

    // Sub-subtask cascade: the cause stays the root item (D3).
    final nested = [
      ..._baseWrites(),
      cell('task', 'grandchild', 'title', 'G', hlc: _h(1), node: 'a'),
      cell('task', 'grandchild', '~', 3000, hlc: _h(3) + 3, node: 'a', cause: _parent),
    ];
    expect(existenceIn(stateOf(nested), 'task', 'grandchild'), RowExistence.deleted);
    expect(existenceIn(stateOf([...nested, _parentEdit]), 'task', 'grandchild'), RowExistence.alive);
  });

  test('a cause cycle counts as deleted from every entry point', () {
    final state = stateOf([
      cell('t', 'x', 'title', 'X', hlc: _h(1), node: 'a'),
      cell('t', 'y', 'title', 'Y', hlc: _h(1), node: 'a'),
      cell('t', 'x', '~', 1, hlc: _h(2), node: 'a', cause: const RowRef('t', 'y')),
      cell('t', 'y', '~', 1, hlc: _h(2), node: 'b', cause: const RowRef('t', 'x')),
    ]);
    expect(existenceIn(state, 't', 'x'), RowExistence.deleted);
    expect(existenceIn(state, 't', 'y'), RowExistence.deleted);
  });

  test('isOwnTombstoneInForce and maxDataCell ignore the cause', () {
    final row = CellListRow([
      cell('task', 'child', 'title', 'Child', hlc: _h(1), node: 'a'),
      cell('task', 'child', 'body', 'B', hlc: _h(2), node: 'z'),
      cell('task', 'child', '~', 1, hlc: _h(3), node: 'a', cause: _parent),
    ]);
    expect(maxDataCell(row)!.value, 'B');
    expect(isOwnTombstoneInForce(row), isTrue);
    expect(isRowEffectivelyAlive(const RowRef('task', 'child'), (r) => r == _parent ? null : row), isFalse);
  });
}
