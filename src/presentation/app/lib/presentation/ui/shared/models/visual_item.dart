/// A sealed class representing visual items in a sliver-based list or grid.
/// [T] is the type of the underlying data item (e.g., HabitListItem, TaskListItem).
sealed class VisualItem<T> {
  const VisualItem();
}

/// A header visual item.
class VisualItemHeader<T> extends VisualItem<T> {
  final String title;

  const VisualItemHeader(this.title);
}

/// A single data item visual item.
class VisualItemSingle<T> extends VisualItem<T> {
  final T data;
  final int indexInGroup;
  final List<T> group;

  const VisualItemSingle({
    required this.data,
    required this.indexInGroup,
    required this.group,
  });
}

/// A row of data items, used for grid layouts.
class VisualItemRow<T> extends VisualItem<T> {
  final List<T> items;

  const VisualItemRow(this.items);
}
