import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/core/acore/time/week_days.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';

import 'package:whph/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';

class TaskRecurrenceService implements ITaskRecurrenceService {
  @override
  bool isRecurring(Task task) {
    return task.recurrenceType != RecurrenceType.none;
  }

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
      return nextDate.isBefore(task.recurrenceEndDate!);
    }

    // Check if we've reached the maximum count
    if (task.recurrenceCount != null) {
      return task.recurrenceCount! > 0;
    }

    return true;
  }

  @override
  DateTime calculateNextRecurrenceDate(Task task, DateTime currentDate) {
    final List<WeekDays>? recurrenceDays = getRecurrenceDays(task);

    switch (task.recurrenceType) {
      case RecurrenceType.daily:
        return currentDate.add(Duration(days: task.recurrenceInterval ?? 1));

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
    // Get the completed task
    final task = await mediator.send<GetTaskQuery, GetTaskQueryResponse>(
      GetTaskQuery(id: taskId),
    );

    // Only handle completed recurring tasks
    if (!task.isCompleted || task.recurrenceType == RecurrenceType.none) {
      return null;
    }

    // Check if this task can create a next instance
    if (!canCreateNextInstance(task)) {
      return null;
    }

    // Calculate the next recurrence date
    final nextPlannedDate = calculateNextRecurrenceDate(task, task.plannedDate ?? DateTime.now().toUtc());
    final nextDeadlineDate = calculateNextRecurrenceDate(task, task.deadlineDate ?? DateTime.now().toUtc());

    final taskTags = await mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
      GetListTaskTagsQuery(taskId: taskId, pageIndex: 0, pageSize: double.maxFinite.toInt()),
    );

    // Create the new task via the mediator
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
      recurrenceDays: getRecurrenceDays(task),
      recurrenceStartDate: task.recurrenceStartDate,
      recurrenceEndDate: task.recurrenceEndDate,
      recurrenceCount: task.recurrenceCount,
      tagIdsToAdd: taskTags.items.map((tag) => tag.id).toList(),
    );

    final result = await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(saveCommand);

    // Return the ID of the newly created task
    return result.id;
  }
}
