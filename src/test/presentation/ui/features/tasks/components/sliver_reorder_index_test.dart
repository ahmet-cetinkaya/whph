import 'package:flutter_test/flutter_test.dart';

/// Mirrors the visual-item model both lists build for their sliver path.
sealed class _Item {
  const _Item();
}

class _Header extends _Item {
  const _Header(this.title);
  final String title;
}

class _Single extends _Item {
  const _Single(this.id, this.groupName);
  final String id;
  final String groupName;
}

/// Verbatim copy of the index math in TaskList._onSliverReorder /
/// HabitsList._onSliverReorder, isolated so the arithmetic can be exercised
/// without building the full widget tree.
///
/// Returns (movedGroupIndex, targetGroupIndex) or null when the drop is
/// rejected.
(int, int)? sliverReorderIndices(
  int oldIndex,
  int newIndex,
  List<_Item> visualItems,
) {
  if (oldIndex < 0 || oldIndex >= visualItems.length) return null;
  if (newIndex < 0 || newIndex > visualItems.length) return null;

  final oldItem = visualItems[oldIndex];
  if (oldItem is! _Single) return null;

  final groupName = oldItem.groupName;
  final groupItems = visualItems.whereType<_Single>().where((i) => i.groupName == groupName).toList();
  if (groupItems.isEmpty) return null;

  final movedGroupIndex = groupItems.indexWhere((i) => i.id == oldItem.id);
  if (movedGroupIndex == -1) return null;

  int targetGroupIndex = 0;
  for (int i = 0; i < newIndex; i++) {
    if (i == oldIndex) continue;
    final item = visualItems[i];
    if (item is _Single && item.groupName == groupName) {
      targetGroupIndex++;
    }
  }

  return (movedGroupIndex, targetGroupIndex);
}

void main() {
  group('sliver reorder index math (ungrouped list, as on the today page)', () {
    // Today page suppresses grouping under custom sort, so the sliver holds a
    // flat run of items with no headers — index i maps to group index i.
    final flat = <_Item>[
      const _Single('a', ''),
      const _Single('b', ''),
      const _Single('c', ''),
      const _Single('d', ''),
    ];

    test('moving an item UP lands where the user dropped it', () {
      // Drag 'd' (index 3) up to slot 1 -> expected order a, d, b, c
      final result = sliverReorderIndices(3, 1, flat);
      expect(result, isNotNull);
      final (moved, target) = result!;
      expect(moved, 3);
      expect(target, 1, reason: 'dropping at slot 1 must target group index 1');
    });

    test('moving an item DOWN lands where the user dropped it', () {
      // Regression: SliverReorderableList reports newIndex in *pre-removal*
      // coordinates. The old code both decremented newIndex for downward
      // moves AND skipped oldIndex while counting, subtracting the moved
      // item twice — so every downward drag landed one slot short of where
      // it was dropped. Dragging 'a' (0) to sit after 'c' (newIndex 3) must
      // target group index 2, not 1.
      final result = sliverReorderIndices(0, 3, flat);
      expect(result, isNotNull);
      final (moved, target) = result!;
      expect(moved, 0);
      expect(
        target,
        2,
        reason: 'after removing the moved item, dropping past c means group index 2',
      );
    });

    test('moving an item down by one slot advances it by exactly one', () {
      // Drag 'a' (0) just past 'b' -> expected order b, a, c, d => target 1
      final result = sliverReorderIndices(0, 2, flat);
      expect(result, isNotNull);
      final (_, target) = result!;
      expect(target, 1);
    });
  });
}
