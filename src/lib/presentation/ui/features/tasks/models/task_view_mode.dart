export 'calendar_sub_view.dart' show CalendarSubView;

enum TaskViewMode { list, board, calendar }

extension TaskViewModeParse on TaskViewMode {
  /// Parse a [TaskViewMode] from its [name] (e.g. persisted JSON value).
  /// Falls back to [TaskViewMode.list] for null or unknown values.
  static TaskViewMode fromName(String? name) {
    for (final mode in TaskViewMode.values) {
      if (mode.name == name) return mode;
    }
    return TaskViewMode.list;
  }
}
