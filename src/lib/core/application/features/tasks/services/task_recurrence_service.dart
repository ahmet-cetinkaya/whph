import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';

import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';

class TaskRecurrenceService implements ITaskRecurrenceService {
  final ILogger _logger;

  TaskRecurrenceService(this._logger);
  @override
  bool isRecurring(Task task) {
    return task.recurrenceType != RecurrenceType.none;
  }

  /// Determines if a recurring task can create a next instance based on its recurrence rules
  @override
  bool canCreateNextInstance(Task task) {
    if (!isRecurring(task)) {
      return false;
    }

    // If there's no end date or count limit, we can always create new instances
    if (task.recurrenceEndDate == null && task.recurrenceCount == null) {
      return true;
    }

    // Check if we've reached the end date
    if (task.recurrenceEndDate != null) {
      DateTime lastDate = task.plannedDate ?? task.deadlineDate ?? DateTime.now();
      DateTime nextDate = calculateNextRecurrenceDate(task, lastDate);
      return !nextDate.isAfter(task.recurrenceEndDate!);
    }

    // Check if we've reached the maximum count
    if (task.recurrenceCount != null) {
      return task.recurrenceCount! > 0;
    }

    return true;
  }

  /// Calculates the next recurrence date based on the task's recurrence settings
  @override
  DateTime calculateNextRecurrenceDate(Task task, DateTime currentDate) {
    final List<WeekDays>? recurrenceDays = getRecurrenceDays(task);

    DateTime nextDate;
    switch (task.recurrenceType) {
      case RecurrenceType.daily:
        nextDate = currentDate.add(Duration(days: task.recurrenceInterval ?? 1));
        return nextDate;

      case RecurrenceType.weekly:
        if (recurrenceDays != null && recurrenceDays.isNotEmpty) {
          // Find the next day that matches one of the recurrence days
          final int currentWeekday = currentDate.weekday; // 1 = Monday, 7 = Sunday

          // Convert our enum to weekday numbers
          final List<int> weekdays = recurrenceDays.map((day) {
            // Adjust for Dart's DateTime weekday (1-7, Monday-Sunday)
            switch (day) {
              case WeekDays.monday:
                return 1;
              case WeekDays.tuesday:
                return 2;
              case WeekDays.wednesday:
                return 3;
              case WeekDays.thursday:
                return 4;
              case WeekDays.friday:
                return 5;
              case WeekDays.saturday:
                return 6;
              case WeekDays.sunday:
                return 7;
            }
          }).toList();

          // Sort weekdays
          weekdays.sort();

          // Find the next weekday from the current one
          int? nextWeekday;
          for (final weekday in weekdays) {
            if (weekday > currentWeekday) {
              nextWeekday = weekday;
              break;
            }
          }

          // If no next weekday found in the current week, take the first one in the next week
          nextWeekday ??= weekdays.first;

          // Calculate days to add
          int daysToAdd = nextWeekday - currentWeekday;
          if (daysToAdd <= 0) {
            daysToAdd += 7; // Move to next week
          }

          // Add interval weeks if specified (skipping the first occurrence)
          if (task.recurrenceInterval != null && task.recurrenceInterval! > 1) {
            daysToAdd += (task.recurrenceInterval! - 1) * 7;
          }

          return currentDate.add(Duration(days: daysToAdd));
        } else {
          // Simple weekly recurrence without specific days
          return currentDate.add(Duration(days: 7 * (task.recurrenceInterval ?? 1)));
        }

      case RecurrenceType.monthly:
        // Calculate the next month, preserving the day of month if possible
        int year = currentDate.year;
        int month = currentDate.month + (task.recurrenceInterval ?? 1);

        // Adjust for year overflow
        while (month > 12) {
          month -= 12;
          year++;
        }

        // Create a new date with the calculated year and month
        final DateTime nextDate = DateTime(
          year,
          month,
          1, // Start with first day of month
          currentDate.hour,
          currentDate.minute,
        );

        // Try to use the same day of month, but cap to last day of the month
        final int desiredDay = currentDate.day;
        final int lastDayOfMonth = DateTime(nextDate.year, nextDate.month + 1, 0).day;
        final int actualDay = desiredDay > lastDayOfMonth ? lastDayOfMonth : desiredDay;

        return DateTime(
          nextDate.year,
          nextDate.month,
          actualDay,
          nextDate.hour,
          nextDate.minute,
        );

      case RecurrenceType.yearly:
        return DateTime(
          currentDate.year + (task.recurrenceInterval ?? 1),
          currentDate.month,
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );

      default:
        return currentDate;
    }
  }

  @override
  List<WeekDays>? getRecurrenceDays(Task task) {
    if (task.recurrenceDaysString == null || task.recurrenceDaysString!.isEmpty) {
      return null;
    }
    return task.recurrenceDaysString!
        .split(',')
        .map((day) => WeekDays.values
            .firstWhere((e) => e.toString().split('.').last == day.trim(), orElse: () => WeekDays.monday))
        .toList();
  }

  /// Handles the creation of the next recurring task instance when a task is completed
  @override
  Future<String?> handleCompletedRecurringTask(String taskId, Mediator mediator) async {
    try {
      final task = await _getTaskForRecurrence(taskId, mediator);
      if (!_canProcessRecurrence(task)) {
        return null;
      }

      return await _createNextRecurrenceInstance(task, mediator);
    } catch (e) {
      _logger.error('Failed to create recurring task instance for $taskId: $e');
      return null;
    }
  }

  /// Retrieves and validates a task for recurrence processing
  Future<Task> _getTaskForRecurrence(String taskId, Mediator mediator) async {
    return await mediator.send<GetTaskQuery, GetTaskQueryResponse>(
      GetTaskQuery(id: taskId),
    );
  }

  /// Validates if a task can be processed for recurrence
  bool _canProcessRecurrence(Task task) {
    if (!task.isCompleted || task.recurrenceType == RecurrenceType.none) {
      return false;
    }

    return canCreateNextInstance(task);
  }

  /// Creates the next recurrence instance of a task
  Future<String> _createNextRecurrenceInstance(Task task, Mediator mediator) async {
    final nextDates = _calculateNextDates(task);
    final taskTags = await _getTaskTags(task.id, mediator);
    final nextRecurrenceCount = _calculateNextRecurrenceCount(task);

    final saveCommand =
        _buildSaveTaskCommand(task, nextDates.plannedDate, nextDates.deadlineDate, nextRecurrenceCount, taskTags);

    final result = await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(saveCommand);
    _logger.info('Created next recurrence instance ${result.id} for task ${task.id}');

    return result.id;
  }

  /// Calculates the next planned and deadline dates for recurrence
  ({DateTime plannedDate, DateTime? deadlineDate}) _calculateNextDates(Task task) {
    final nextPlannedDate = calculateNextRecurrenceDate(task, task.plannedDate ?? DateTime.now().toUtc());
    final nextDeadlineDate = task.deadlineDate != null ? calculateNextRecurrenceDate(task, task.deadlineDate!) : null;

    return (plannedDate: nextPlannedDate, deadlineDate: nextDeadlineDate);
  }

  /// Retrieves tags associated with a task
  Future<List<String>> _getTaskTags(String taskId, Mediator mediator) async {
    final taskTags = await mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
      GetListTaskTagsQuery(taskId: taskId, pageIndex: 0, pageSize: double.maxFinite.toInt()),
    );
    return taskTags.items.map((tag) => tag.tagId).toList();
  }

  /// Calculates the next recurrence count, decrementing if needed
  int? _calculateNextRecurrenceCount(Task task) {
    if (task.recurrenceCount == null || task.recurrenceCount! <= 0) {
      return task.recurrenceCount;
    }

    return task.recurrenceCount! - 1;
  }

  /// Builds a SaveTaskCommand for creating the next recurrence instance
  SaveTaskCommand _buildSaveTaskCommand(
    Task task,
    DateTime nextPlannedDate,
    DateTime? nextDeadlineDate,
    int? nextRecurrenceCount,
    List<String> tagIds,
  ) {
    return SaveTaskCommand(
      title: task.title,
      description: task.description,
      priority: task.priority,
      plannedDate: nextPlannedDate,
      deadlineDate: nextDeadlineDate,
      estimatedTime: task.estimatedTime,
      parentTaskId: task.parentTaskId,
      plannedDateReminderTime: task.plannedDateReminderTime,
      deadlineDateReminderTime: task.deadlineDateReminderTime,
      recurrenceType: task.recurrenceType,
      recurrenceInterval: task.recurrenceInterval,
      recurrenceDays: getRecurrenceDays(task),
      recurrenceStartDate: task.recurrenceStartDate,
      recurrenceEndDate: task.recurrenceEndDate,
      recurrenceCount: nextRecurrenceCount,
      tagIdsToAdd: tagIds,
    );
  }
}
