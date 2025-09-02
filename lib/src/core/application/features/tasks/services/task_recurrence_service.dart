import 'package:whph/src/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/src/core/application/features/tasks/queries/get_task_query.dart';

import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';

class TaskRecurrenceService implements ITaskRecurrenceService {
  final ILogger _logger;

  TaskRecurrenceService(this._logger);
  @override
  bool isRecurring(Task task) {
    return task.recurrenceType != RecurrenceType.none;
  }

  @override
  bool canCreateNextInstance(Task task) {
    _logger.debug('TaskRecurrenceService: Checking if can create next instance for task ${task.id}');
    _logger.debug('TaskRecurrenceService: Task recurrence type: ${task.recurrenceType}');

    if (!isRecurring(task)) {
      _logger.debug('TaskRecurrenceService: Task is not recurring, cannot create next instance');
      return false;
    }

    // If there's no end date or count limit, we can always create new instances
    if (task.recurrenceEndDate == null && task.recurrenceCount == null) {
      _logger.debug('TaskRecurrenceService: No end date or count limit, can create next instance');
      return true;
    }

    // Check if we've reached the end date
    if (task.recurrenceEndDate != null) {
      DateTime lastDate = task.plannedDate ?? task.deadlineDate ?? DateTime.now();
      DateTime nextDate = calculateNextRecurrenceDate(task, lastDate);
      bool canCreate = nextDate.isBefore(task.recurrenceEndDate!);
      _logger.debug(
          'TaskRecurrenceService: End date check - next date: $nextDate, end date: ${task.recurrenceEndDate}, can create: $canCreate');
      return canCreate;
    }

    // Check if we've reached the maximum count
    if (task.recurrenceCount != null) {
      bool canCreate = task.recurrenceCount! > 0;
      _logger.debug(
          'TaskRecurrenceService: Count check - remaining count: ${task.recurrenceCount}, can create: $canCreate');
      return canCreate;
    }

    _logger.debug('TaskRecurrenceService: Default case, can create next instance');
    return true;
  }

  @override
  DateTime calculateNextRecurrenceDate(Task task, DateTime currentDate) {
    _logger.debug('TaskRecurrenceService: Calculating next recurrence date for task ${task.id}');
    _logger.debug('TaskRecurrenceService: Current date: $currentDate');
    _logger.debug('TaskRecurrenceService: Recurrence type: ${task.recurrenceType}');
    _logger.debug('TaskRecurrenceService: Recurrence interval: ${task.recurrenceInterval}');

    final List<WeekDays>? recurrenceDays = getRecurrenceDays(task);
    if (recurrenceDays != null && recurrenceDays.isNotEmpty) {
      _logger.debug('TaskRecurrenceService: Recurrence days: $recurrenceDays');
    }

    DateTime nextDate;
    switch (task.recurrenceType) {
      case RecurrenceType.daily:
        nextDate = currentDate.add(Duration(days: task.recurrenceInterval ?? 1));
        _logger.debug('TaskRecurrenceService: Daily recurrence - next date: $nextDate');
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

  @override
  Future<String?> handleCompletedRecurringTask(String taskId, Mediator mediator) async {
    _logger.debug('TaskRecurrenceService: Starting handleCompletedRecurringTask for task $taskId');

    try {
      // Get the completed task
      _logger.debug('TaskRecurrenceService: Fetching task details for $taskId');
      final task = await mediator.send<GetTaskQuery, GetTaskQueryResponse>(
        GetTaskQuery(id: taskId),
      );

      _logger.debug(
          'TaskRecurrenceService: Retrieved task - ID: ${task.id}, Completed: ${task.isCompleted}, RecurrenceType: ${task.recurrenceType}');
      _logger.debug(
          'TaskRecurrenceService: Task recurrence settings - Interval: ${task.recurrenceInterval}, StartDate: ${task.recurrenceStartDate}, EndDate: ${task.recurrenceEndDate}, Count: ${task.recurrenceCount}');
      _logger.debug('TaskRecurrenceService: Task planned date: ${task.plannedDate}');


      // Only handle completed recurring tasks
      if (!task.isCompleted || task.recurrenceType == RecurrenceType.none) {
        _logger.debug(
            'TaskRecurrenceService: Task is not completed (${task.isCompleted}) or not recurring (${task.recurrenceType}), skipping recurrence creation');
        return null;
      }

      // Check if this task can create a next instance
      if (!canCreateNextInstance(task)) {
        _logger.debug('TaskRecurrenceService: Cannot create next instance based on recurrence rules');
        return null;
      }


      // Calculate the next recurrence date
      _logger.debug('TaskRecurrenceService: Calculating next recurrence date');
      final nextPlannedDate = calculateNextRecurrenceDate(task, task.plannedDate ?? DateTime.now().toUtc());
      _logger.debug('TaskRecurrenceService: Next planned date calculated: $nextPlannedDate');

      // Calculate the next deadline date if the original task has one
      DateTime? nextDeadlineDate;
      if (task.deadlineDate != null) {
        nextDeadlineDate = calculateNextRecurrenceDate(task, task.deadlineDate!);
        _logger.debug('TaskRecurrenceService: Next deadline date calculated: $nextDeadlineDate');
      }


      _logger.debug('TaskRecurrenceService: Fetching task tags');
      final taskTags = await mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
        GetListTaskTagsQuery(taskId: taskId, pageIndex: 0, pageSize: double.maxFinite.toInt()),
      );
      _logger.debug('TaskRecurrenceService: Found ${taskTags.items.length} tags for task');

      // Calculate the next recurrence count if needed
      int? nextRecurrenceCount = task.recurrenceCount;
      if (task.recurrenceCount != null && task.recurrenceCount! > 0) {
        nextRecurrenceCount = task.recurrenceCount! - 1;
        _logger.debug(
            'TaskRecurrenceService: Decremented recurrence count from ${task.recurrenceCount} to $nextRecurrenceCount');
      } else {
        _logger.debug('TaskRecurrenceService: Recurrence count unchanged: $nextRecurrenceCount');
      }

      // Create the new task via the mediator
      _logger.debug('TaskRecurrenceService: Creating SaveTaskCommand for next recurrence instance');

      final recurrenceDaysForNewTask = getRecurrenceDays(task);

      final saveCommand = SaveTaskCommand(
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
        recurrenceDays: recurrenceDaysForNewTask,
        recurrenceStartDate: task.recurrenceStartDate,
        recurrenceEndDate: task.recurrenceEndDate,
        recurrenceCount: nextRecurrenceCount,
        tagIdsToAdd: taskTags.items.map((tag) => tag.id).toList(),
      );

      _logger.debug('TaskRecurrenceService: Saving new recurring task instance');
      _logger.debug(
          'TaskRecurrenceService: New task details - TaskID: ${task.id}, PlannedDate: $nextPlannedDate, DeadlineDate: $nextDeadlineDate, RecurrenceCount: $nextRecurrenceCount');


      final result = await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(saveCommand);

      _logger.debug('TaskRecurrenceService: Successfully created new recurring task instance with ID: ${result.id}');


      // Return the ID of the newly created task
      return result.id;
    } catch (e) {
      // Log error but don't throw to avoid breaking the completion flow
      _logger.error('TaskRecurrenceService: Failed to create recurring task instance for $taskId: $e');
      // Return null to indicate failure - the caller should handle this gracefully
      return null;
    }
  }
}
