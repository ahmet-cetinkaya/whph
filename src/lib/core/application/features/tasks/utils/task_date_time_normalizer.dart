import 'package:acore/acore.dart';

/// Normalizes task date-time inputs for all task creation/update flows.
class TaskDateTimeNormalizer {
  TaskDateTimeNormalizer._();

  /// Detects if a DateTime represents a date-only (all-day) value.
  ///
  /// Returns true if the local time component is exactly 00:00:00.000000.
  /// Note: This means a task explicitly scheduled for midnight will be
  /// treated as an all-day task. This is a known limitation - tasks
  /// requiring exact midnight times should not use this normalization.
  static bool isAllDay(DateTime value) {
    final local = DateTimeHelper.toLocalDateTime(value);
    return local.hour == 0 &&
        local.minute == 0 &&
        local.second == 0 &&
        local.millisecond == 0 &&
        local.microsecond == 0;
  }

  /// Converts date input to UTC while preserving explicit times.
  ///
  /// The input [value] should be in the user's local timezone.
  /// Returns null if [value] is null.
  ///
  /// For date-only values (time component is 00:00:00 in local timezone):
  /// - Interprets the date in the user's local timezone
  /// - Converts to UTC start of that local day
  /// - Example: DateTime(2026, 3, 12) in UTC+3 becomes 2026-03-11 21:00:00 UTC
  ///
  /// For values with explicit times, preserves the time component.
  static DateTime? normalize(DateTime? value) {
    if (value == null) return null;

    if (isAllDay(value)) {
      final local = DateTimeHelper.toLocalDateTime(value);
      final allDayStart = DateTime(local.year, local.month, local.day);
      return DateTimeHelper.toUtcDateTime(allDayStart);
    }

    return DateTimeHelper.toUtcDateTime(value);
  }
}
