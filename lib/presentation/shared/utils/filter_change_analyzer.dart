class FilterChangeAnalyzer {
  /// Compares two lists for equality by checking their contents
  static bool areListsEqual<T>(List<T>? list1, List<T>? list2) {
    if (list1 == null && list2 == null) return true;
    if (list1 == null || list2 == null) return false;
    if (list1.length != list2.length) return false;
    return Set<T>.from(list1).containsAll(list2);
  }

  /// Compares two values for equality, handling null cases
  static bool hasValueChanged<T>(T? oldValue, T? newValue) {
    if (oldValue == null && newValue == null) return false;
    if (oldValue == null || newValue == null) return true;
    return oldValue != newValue;
  }

  /// Checks if any value in a map of filters has changed
  static bool hasAnyFilterChanged(Map<String, dynamic> oldFilters, Map<String, dynamic> newFilters) {
    final allKeys = {...oldFilters.keys, ...newFilters.keys};

    for (final key in allKeys) {
      final oldValue = oldFilters[key];
      final newValue = newFilters[key];

      if (oldValue is List && newValue is List) {
        if (!areListsEqual(oldValue, newValue)) return true;
      } else {
        if (hasValueChanged(oldValue, newValue)) return true;
      }
    }

    return false;
  }
}
