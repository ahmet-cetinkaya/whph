import 'package:acore/acore.dart';

/// Normalizes and validates task date-time inputs for all task creation/update flows.
class TaskDateTimeNormalizer {
  TaskDateTimeNormalizer._();

  /// Returns true when the local time component represents an all-day value.
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
  /// For date-only values, this keeps an all-day semantic (start of day).
  static DateTime? normalize(DateTime? value) {
    if (value == null) return null;

    if (isAllDay(value)) {
      final local = DateTimeHelper.toLocalDateTime(value);
      final allDayStart = DateTime(local.year, local.month, local.day);
      return DateTimeHelper.toUtcDateTime(allDayStart);
    }

    return DateTimeHelper.toUtcDateTime(value);
  }

  /// Ensures the date range is valid when both values are provided.
  static void validateDateRange({
    DateTime? plannedDate,
    DateTime? deadlineDate,
  }) {
    if (plannedDate != null && deadlineDate != null && deadlineDate.isBefore(plannedDate)) {
      throw ArgumentError.value(
        deadlineDate,
        'deadlineDate',
        'Deadline date must be at or after planned date.',
      );
    }
  }
}
