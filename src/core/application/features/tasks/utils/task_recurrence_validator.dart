import 'package:domain/features/tasks/task.dart';

class TaskRecurrenceValidator {
  static void validateRecurrenceInterval(int? interval) {
    if (interval != null && interval <= 0) {
      throw ArgumentError.value(interval, 'interval', 'Recurrence interval must be greater than 0');
    }
  }

  static void validateRecurrenceStartDate(DateTime? startDate) {
    if (startDate != null && startDate.isAfter(DateTime.now().add(const Duration(days: 365)))) {
      throw ArgumentError.value(
          startDate, 'startDate', 'Recurrence start date cannot be more than 1 year in the future');
    }
  }

  static void validateDaysOfWeekRecurrence(Task task) {
    // No validation for backward compatibility - service handles fallback
  }

  static void validateRecurrenceParameters(Task task) {
    validateRecurrenceInterval(task.recurrenceInterval);
    validateRecurrenceStartDate(task.recurrenceStartDate);
    validateDaysOfWeekRecurrence(task);
  }
}
