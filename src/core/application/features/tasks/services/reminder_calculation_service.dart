import 'package:application/features/tasks/services/abstraction/i_reminder_calculation_service.dart';
import 'package:application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:domain/shared/constants/task_error_ids.dart';
import 'package:domain/shared/constants/domain_log_components.dart';

class ReminderCalculationService extends IReminderCalculationService {
  final ITaskRecurrenceService _recurrenceService;

  ReminderCalculationService(this._recurrenceService);

  @override
  DateTime? calculateReminderDateTime({
    required DateTime? baseDate,
    required ReminderTime reminderTime,
    int? customOffset,
  }) {
    if (baseDate == null || reminderTime == ReminderTime.none) {
      return null;
    }

    if (!validateReminderSettings(reminderTime: reminderTime, customOffset: customOffset)) {
      DomainLogger.warning('ReminderCalculationService: Invalid reminder settings provided');
      return null;
    }

    try {
      switch (reminderTime) {
        case ReminderTime.atTime:
          return baseDate;

        case ReminderTime.fiveMinutesBefore:
          return baseDate.subtract(const Duration(minutes: 5));

        case ReminderTime.fifteenMinutesBefore:
          return baseDate.subtract(const Duration(minutes: 15));

        case ReminderTime.oneHourBefore:
          return baseDate.subtract(const Duration(hours: 1));

        case ReminderTime.oneDayBefore:
          return baseDate.subtract(const Duration(days: 1));

        case ReminderTime.custom:
          if (customOffset != null) {
            return baseDate.subtract(Duration(minutes: customOffset));
          }
          DomainLogger.warning('ReminderCalculationService: Custom reminder time requires offset');
          return null;

        case ReminderTime.none:
          return null;
      }
    } on ArgumentError catch (e) {
      // Invalid argument (e.g., negative duration, overflow)
      DomainLogger.error(
        'ReminderCalculationService: Invalid argument for reminder calculation [$TaskErrorIds.reminderCalculateDateTimeFailed]',
        error: e,
        component: DomainLogComponents.task,
      );
      return null;
    } catch (e, stackTrace) {
      DomainLogger.error(
        'ReminderCalculationService: Error calculating reminder datetime [$TaskErrorIds.reminderCalculateDateTimeFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return null;
    }
  }

  @override
  bool validateReminderSettings({
    required ReminderTime reminderTime,
    int? customOffset,
  }) {
    if (reminderTime == ReminderTime.none) {
      return true; // No reminder is valid
    }

    if (reminderTime == ReminderTime.custom) {
      return ReminderOffsets.isValidCustomOffset(customOffset);
    }

    // For predefined reminder times, no additional validation needed
    return true;
  }

  @override
  DateTime? getNextReminderOccurrence({
    required Task task,
    DateTime? afterDate,
  }) {
    try {
      final searchDate = afterDate ?? DateTime.now();

      // If task is not recurring, check single reminder
      if (!_recurrenceService.isRecurring(task)) {
        return calculateReminderDateTime(
          baseDate: task.plannedDate ?? task.deadlineDate,
          reminderTime: task.plannedDateReminderTime != ReminderTime.none
              ? task.plannedDateReminderTime
              : task.deadlineDateReminderTime,
          customOffset: task.plannedDateReminderTime != ReminderTime.none
              ? task.plannedDateReminderCustomOffset
              : task.deadlineDateReminderCustomOffset,
        );
      }

      // For recurring tasks, calculate next occurrence
      final baseDate = task.plannedDate ?? task.deadlineDate ?? searchDate;

      // Check if we can create the next instance
      if (!_recurrenceService.canCreateNextInstance(task)) {
        // Check the final occurrence
        final reminderDateTime = calculateReminderDateTime(
          baseDate: baseDate,
          reminderTime: task.plannedDateReminderTime != ReminderTime.none
              ? task.plannedDateReminderTime
              : task.deadlineDateReminderTime,
          customOffset: task.plannedDateReminderTime != ReminderTime.none
              ? task.plannedDateReminderCustomOffset
              : task.deadlineDateReminderCustomOffset,
        );
        if (reminderDateTime != null && reminderDateTime.isAfter(searchDate)) {
          return reminderDateTime;
        }
        return null;
      }

      // Calculate next recurrence date
      final nextRecurrenceDate = _recurrenceService.calculateNextRecurrenceDate(task, baseDate);

      // If next date is in the past, check current date
      if (nextRecurrenceDate.isBefore(searchDate) || nextRecurrenceDate.isAtSameMomentAs(searchDate)) {
        // Calculate reminder for a future date
        final futureDate = searchDate.add(const Duration(days: 1));
        return calculateReminderDateTime(
          baseDate: futureDate,
          reminderTime: task.plannedDateReminderTime != ReminderTime.none
              ? task.plannedDateReminderTime
              : task.deadlineDateReminderTime,
          customOffset: task.plannedDateReminderTime != ReminderTime.none
              ? task.plannedDateReminderCustomOffset
              : task.deadlineDateReminderCustomOffset,
        );
      }

      // Calculate reminder for the next recurrence
      return calculateReminderDateTime(
        baseDate: nextRecurrenceDate,
        reminderTime: task.plannedDateReminderTime != ReminderTime.none
            ? task.plannedDateReminderTime
            : task.deadlineDateReminderTime,
        customOffset: task.plannedDateReminderTime != ReminderTime.none
            ? task.plannedDateReminderCustomOffset
            : task.deadlineDateReminderCustomOffset,
      );
    } on StateError catch (e) {
      // Task state error (e.g., invalid recurrence configuration)
      DomainLogger.error(
        'ReminderCalculationService: Task state error in getNextReminderOccurrence [$TaskErrorIds.reminderGetNextOccurrenceFailed]',
        error: e,
        component: DomainLogComponents.task,
      );
      return null;
    } catch (e, stackTrace) {
      DomainLogger.error(
        'ReminderCalculationService: Error getting next reminder occurrence [$TaskErrorIds.reminderGetNextOccurrenceFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return null;
    }
  }

  @override
  bool shouldReminderTrigger({
    required Task task,
    required DateTime currentTime,
  }) {
    try {
      // For non-recurring tasks
      if (task.recurrenceType == RecurrenceType.none) {
        final reminderDateTime = calculateReminderDateTime(
          baseDate: task.plannedDate ?? task.deadlineDate,
          reminderTime: task.plannedDateReminderTime != ReminderTime.none
              ? task.plannedDateReminderTime
              : task.deadlineDateReminderTime,
          customOffset: task.plannedDateReminderTime != ReminderTime.none
              ? task.plannedDateReminderCustomOffset
              : task.deadlineDateReminderCustomOffset,
        );

        if (reminderDateTime == null) return false;

        // Check if current time is within a reasonable window (e.g., within 1 minute)
        final timeDifference = currentTime.difference(reminderDateTime).abs();
        return timeDifference.inMinutes <= 1;
      }

      // For recurring tasks, check if we're due for a reminder
      final nextReminder =
          getNextReminderOccurrence(task: task, afterDate: currentTime.subtract(const Duration(minutes: 1)));

      if (nextReminder == null) return false;

      final timeDifference = nextReminder.difference(currentTime).abs();
      return timeDifference.inMinutes <= 1;
    } on ArgumentError catch (e) {
      // Invalid argument (e.g., null date in difference calculation)
      DomainLogger.error(
        'ReminderCalculationService: Invalid argument in shouldReminderTrigger [$TaskErrorIds.reminderShouldTriggerCheckFailed]',
        error: e,
        component: DomainLogComponents.task,
      );
      return false;
    } catch (e, stackTrace) {
      DomainLogger.error(
        'ReminderCalculationService: Error checking if reminder should trigger [$TaskErrorIds.reminderShouldTriggerCheckFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return false;
    }
  }
}
