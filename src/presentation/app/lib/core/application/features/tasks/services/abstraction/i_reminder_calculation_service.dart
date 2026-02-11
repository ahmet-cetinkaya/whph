import 'package:whph/core/domain/features/tasks/task.dart';

abstract class IReminderCalculationService {
  /// Calculates the actual reminder DateTime based on the task date and reminder settings
  DateTime? calculateReminderDateTime({
    required DateTime? baseDate,
    required ReminderTime reminderTime,
    int? customOffset,
  });

  /// Validates if the reminder settings are valid
  bool validateReminderSettings({
    required ReminderTime reminderTime,
    int? customOffset,
  });

  /// Gets the next occurrence of a reminder for a recurring task
  DateTime? getNextReminderOccurrence({
    required Task task,
    DateTime? afterDate,
  });

  /// Checks if a reminder should trigger at the current time
  bool shouldReminderTrigger({
    required Task task,
    required DateTime currentTime,
  });
}
