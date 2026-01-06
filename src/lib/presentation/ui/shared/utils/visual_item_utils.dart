import '../models/visual_item.dart';

class VisualItemUtils {
  /// Transforms a grouped map of items into a flattened list of [VisualItem]s.
  ///
  /// [gridColumns]: If > 1, single items within groups will be chunked into [VisualItemRow]s.
  static List<VisualItem<T>> getVisualItems<T>({
    required Map<String, List<T>> groupedItems,
    int gridColumns = 1,
  }) {
    final List<VisualItem<T>> visualItems = [];
    if (groupedItems.isEmpty) return visualItems;

    for (final entry in groupedItems.entries) {
      // Add header if group name is not empty
      if (entry.key.isNotEmpty) {
        visualItems.add(VisualItemHeader<T>(entry.key));
      }

      final items = entry.value;
      if (gridColumns > 1) {
        // Chunk items into rows for grid layout
        for (int i = 0; i < items.length; i += gridColumns) {
          final end = (i + gridColumns < items.length) ? i + gridColumns : items.length;
          visualItems.add(VisualItemRow<T>(items.sublist(i, end)));
        }
      } else {
        // Flat list for column layout
        for (int i = 0; i < items.length; i++) {
          visualItems.add(VisualItemSingle<T>(
            data: items[i],
            indexInGroup: i,
            group: items,
          ));
        }
      }
    }

    return visualItems;
  }
}
