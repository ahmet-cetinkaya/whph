import 'dart:async';
import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:meta/meta.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/application/features/tasks/utils/task_recurrence_validator.dart';
import 'package:whph/core/application/features/tasks/utils/date_helper.dart';
import 'package:whph/core/domain/features/tasks/models/recurrence_configuration.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/domain/shared/constants/domain_log_components.dart';

class TaskRecurrenceService implements ITaskRecurrenceService {
  final ILogger _logger;
  final ITaskRepository _taskRepository;

  /// Tracks recurrence parent IDs currently being processed to prevent race conditions.
  /// This serializes creation of next instances for the same recurrence chain.
  ///
  /// Using Map&lt;String, Completer&lt;void&gt;&gt; instead of Set&lt;String&gt; ensures:
  /// 1. Thread-safe lock acquisition (no TOCTOU race condition)
  /// 2. Automatic queue management - callers wait on the completer
  /// 3. Proper cleanup - removing from map also signals any waiters
  final Map<String, Completer<void>> _processingRecurrenceParents = {};

  static const int _lockTimeoutMs = 5000;

  TaskRecurrenceService(this._logger, this._taskRepository);
  @override
  bool isRecurring(Task task) {
    return task.recurrenceConfiguration != null || task.recurrenceType != RecurrenceType.none;
  }

  @override
  bool canCreateNextInstance(Task task) {
    if (!isRecurring(task)) {
      return false;
    }

    // Validate parameters - let ArgumentError propagate for invalid input
    TaskRecurrenceValidator.validateRecurrenceParameters(task);

    // New Configuration Logic
    if (task.recurrenceConfiguration != null) {
      final config = task.recurrenceConfiguration!;

      switch (config.endCondition) {
        case RecurrenceEndCondition.never:
          return true;
        case RecurrenceEndCondition.date:
          if (config.endDate == null) {
            throw StateError(
              'RecurrenceConfiguration has endCondition set to "date" but endDate is null. '
              'This is an invalid configuration state that indicates data corruption or incomplete migration. '
              'Task ID: ${task.id}, RecurrenceConfiguration: $config',
            );
          }
          // If the end date has already passed, we cannot create more instances
          if (config.endDate!.isBefore(DateTime.now().toUtc())) {
            return false;
          }
          final lastDate = task.plannedDate ?? task.deadlineDate ?? DateTime.now().toUtc();
          final nextDate = calculateNextRecurrenceDate(task, lastDate);
          // If next recurrence is on or after end date, stop (inclusive per iCal standard)
          return nextDate.isBefore(config.endDate!);
        case RecurrenceEndCondition.count:
          // Check both task-level count and config-level occurrence count
          // task.recurrenceCount tracks remaining occurrences for current task
          // config.occurrenceCount is the total limit from configuration
          final taskCountLimit = task.recurrenceCount;
          final configCountLimit = config.occurrenceCount;

          // If either limit is set and exhausted, stop creating new instances
          if (taskCountLimit != null) {
            return taskCountLimit > 0;
          }
          if (configCountLimit != null) {
            return configCountLimit > 0;
          }
          // Both limits are null - this is an invalid configuration
          throw StateError(
            'RecurrenceConfiguration has endCondition set to "count" but both task.recurrenceCount and config.occurrenceCount are null. '
            'This is an invalid configuration state that indicates data corruption or incomplete migration. '
            'Task ID: ${task.id}, RecurrenceConfiguration: $config',
          );
      }
    }

    // Legacy Logic support
    if (task.recurrenceEndDate == null && task.recurrenceCount == null) {
      return true;
    }

    if (task.recurrenceEndDate != null) {
      final DateTime lastDate = task.plannedDate ?? task.deadlineDate ?? DateTime.now().toUtc();
      final DateTime nextDate = calculateNextRecurrenceDate(task, lastDate);
      return !nextDate.isAfter(task.recurrenceEndDate!);
    }

    if (task.recurrenceCount != null) {
      return task.recurrenceCount! > 0;
    }

    return true;
  }

  @override
  DateTime calculateNextRecurrenceDate(Task task, DateTime currentDate) {
    // 1. New Configuration Logic
    if (task.recurrenceConfiguration != null) {
      return _calculateFromConfiguration(task.recurrenceConfiguration!, task, currentDate);
    }

    // 2. Legacy Logic
    TaskRecurrenceValidator.validateRecurrenceParameters(task);

    final List<WeekDays>? recurrenceDays = getRecurrenceDays(task);

    switch (task.recurrenceType) {
      case RecurrenceType.daily:
        return currentDate.add(Duration(days: task.recurrenceInterval ?? 1));

      case RecurrenceType.daysOfWeek:
        if (recurrenceDays != null && recurrenceDays.isNotEmpty) {
          final selectedWeekdays = recurrenceDays.map((day) => DateHelper.weekDayToNumber(day)).toList()..sort();

          final referenceDate = task.recurrenceStartDate ?? task.plannedDate ?? task.createdDate;

          return DateHelper.findNextWeekdayOccurrence(
            currentDate,
            selectedWeekdays,
            task.recurrenceInterval,
            referenceDate,
          );
        }
        return currentDate.add(Duration(days: 7 * (task.recurrenceInterval ?? 1)));

      case RecurrenceType.weekly:
        return currentDate.add(Duration(days: 7 * (task.recurrenceInterval ?? 1)));

      case RecurrenceType.monthly:
        return DateHelper.calculateNextMonthDate(currentDate, task.recurrenceInterval ?? 1);

      case RecurrenceType.yearly:
        return DateTime(
          currentDate.year + (task.recurrenceInterval ?? 1),
          currentDate.month,
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );

      case RecurrenceType.hourly:
        return currentDate.add(Duration(hours: task.recurrenceInterval ?? 1));

      case RecurrenceType.minutely:
        return currentDate.add(Duration(minutes: task.recurrenceInterval ?? 1));

      default:
        return currentDate;
    }
  }

  DateTime _calculateFromConfiguration(RecurrenceConfiguration config, Task task, DateTime currentDate) {
    switch (config.frequency) {
      case RecurrenceFrequency.daily:
        return currentDate.add(Duration(days: config.interval));

      case RecurrenceFrequency.weekly:
        // Check if weeklySchedule is provided for per-day times
        if (config.weeklySchedule != null && config.weeklySchedule!.isNotEmpty) {
          final referenceDate = task.recurrenceStartDate ?? task.plannedDate ?? currentDate;
          return DateHelper.findNextWeekdayOccurrenceWithTimes(
            currentDate,
            config.weeklySchedule!,
            config.interval,
            referenceDate,
          );
        }
        // Fall back to existing logic for daysOfWeek
        if (config.daysOfWeek != null && config.daysOfWeek!.isNotEmpty) {
          // Reuse existing logic but with int list
          // Note: DateHelper.findNextWeekdayOccurrence expects List<int>
          // RecurrenceConfiguration.daysOfWeek is List<int> (1-7)

          // We need a reference date. For pure config calculation without task context,
          // we treat currentDate as reference if strict interval needed?
          // Actually `findNextWeekdayOccurrence` needs a reference date to align "Every 2 weeks" logic.
          // Use recurrenceStartDate for interval alignment to prevent drift when interval > 1
          final referenceDate = task.recurrenceStartDate ?? task.plannedDate ?? currentDate;
          return DateHelper.findNextWeekdayOccurrence(
            currentDate,
            config.daysOfWeek!.toList()..sort(),
            config.interval,
            referenceDate, // Align intervals to original recurrence start date
          );
        }
        return currentDate.add(Duration(days: 7 * config.interval));

      case RecurrenceFrequency.monthly:
        // Monthly Logic
        int nextMonth = currentDate.month + config.interval;
        int year = currentDate.year;
        while (nextMonth > 12) {
          nextMonth -= 12;
          year++;
        }

        if (config.monthlyPatternType == MonthlyPatternType.relativeDay) {
          // e.g., "2nd Tuesday" or "Last Friday"
          final weekOfMonth = config.weekOfMonth ?? 1; // 1-5
          final dayOfWeek = config.dayOfWeek ?? 1; // 1-7 Mon-Sun

          final nextDate = DateHelper.getNthWeekdayOfMonth(year, nextMonth, dayOfWeek, weekOfMonth);
          return DateTime(nextDate.year, nextDate.month, nextDate.day, currentDate.hour, currentDate.minute);
        } else {
          // Specific Day (e.g. 15th)
          // If day is "31" or generic "last day"?
          // Support "Last Day" logic if dayOfMonth is -1 or special flag?
          // For now assume dayOfMonth is explicit.
          // If simple dayOfMonth is provided, use fixed default of 1st if not set
          // to avoid unpredictable behavior with currentDate.day
          final desiredDay = config.dayOfMonth ?? 1;

          // Handle months with fewer days
          final lastDayOfNextMonth = DateTime(year, nextMonth + 1, 0).day;

          // If looking for 31st but month has 30, clamp to 30? Or skip?
          // Standard behavior usually clamps.
          final actualDay = desiredDay > lastDayOfNextMonth ? lastDayOfNextMonth : desiredDay;

          return DateTime(year, nextMonth, actualDay, currentDate.hour, currentDate.minute);
        }

      case RecurrenceFrequency.yearly:
        // Yearly recurrence with optional monthOfYear specification
        // If monthOfYear is set, use that month; otherwise use current month
        final targetMonth = config.monthOfYear ?? currentDate.month;
        int targetYear = currentDate.year + config.interval;

        // If we're targeting a specific month and the current month is after that month,
        // we need to advance to the next interval year
        if (config.monthOfYear != null && currentDate.month > config.monthOfYear!) {
          targetYear += config.interval;
        }

        // Handle day validation - if target day doesn't exist in target month (e.g., Feb 31),
        // clamp to last day of month
        final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        final targetDay = currentDate.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : currentDate.day;

        return DateTime(
          targetYear,
          targetMonth,
          targetDay,
          currentDate.hour,
          currentDate.minute,
        );

      case RecurrenceFrequency.hourly:
        return currentDate.add(Duration(hours: config.interval));

      case RecurrenceFrequency.minutely:
        return currentDate.add(Duration(minutes: config.interval));
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
    } on StateError catch (_) {
      // Task state changed (no longer completed) - this is expected in some scenarios
      _logger.warning(
        'TaskRecurrenceService: Task state changed during recurrence processing for $taskId [$TaskErrorIds.recurrenceTaskStateChanged]',
      );
      return null;
    } on TimeoutException catch (e, stackTrace) {
      // Lock timeout - log as warning since this may indicate high load
      _logger.warning(
        'TaskRecurrenceService: Timeout acquiring lock for $taskId [$TaskErrorIds.recurrenceLockTimeout]',
        e,
        stackTrace,
        DomainLogComponents.task,
      );
      return null;
    } catch (e, stackTrace) {
      // Unexpected errors - log with error ID for monitoring
      _logger.error(
        'TaskRecurrenceService: Failed to create recurring task instance for $taskId [$TaskErrorIds.recurrenceCreateInstanceFailed]',
        e,
        stackTrace,
        DomainLogComponents.task,
      );
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

  /// Creates the next recurrence instance for a completed recurring task.
  Future<String> _createNextRecurrenceInstance(Task task, Mediator mediator) async {
    final parentId = task.recurrenceParentId ?? task.id;

    await _acquireRecurrenceLock(parentId);

    try {
      // Re-verify the task is still completed before creating recurrence.
      final currentTaskState = await _getTaskForRecurrence(task.id, mediator);
      if (!currentTaskState.isCompleted) {
        _logger.info('TaskRecurrenceService: Task ${task.id} is no longer completed - ABORTING recurrence creation');
        throw StateError('Task is no longer completed');
      }

      final nextDates = _calculateNextDates(task);
      final taskTags = await _getTaskTags(task.id, mediator);

      // Check if the next recurrence instance already exists to prevent duplicates, excluding the current task
      final existingId = await _findDuplicateRecurrence(parentId, nextDates.plannedDate, excludeTaskId: task.id);
      if (existingId != null) {
        _logger.info('TaskRecurrenceService: Duplicate found for parent $parentId, returning existing ID: $existingId');
        return existingId;
      }

      final nextRecurrenceCount = _calculateNextRecurrenceCount(task);
      final saveCommand =
          _buildSaveTaskCommand(task, nextDates.plannedDate, nextDates.deadlineDate, nextRecurrenceCount, taskTags);

      final result = await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(saveCommand);
      _logger.info('TaskRecurrenceService: Created recurrence ${result.id} for task ${task.id}');

      return result.id;
    } finally {
      final completer = _processingRecurrenceParents.remove(parentId);
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      _logger.debug('TaskRecurrenceService: Released lock for parent $parentId');
    }
  }

  Future<void> _acquireRecurrenceLock(String parentId) async {
    // Serialize operations for the same recurrence parent to prevent race conditions.
    final timeoutDuration = const Duration(milliseconds: _lockTimeoutMs);
    final startTime = DateTime.now();

    bool lockAcquired = false;
    try {
      while (true) {
        final completer = _processingRecurrenceParents[parentId];
        if (completer == null) break; // Lock is available

        final elapsed = DateTime.now().difference(startTime);
        if (elapsed >= timeoutDuration) {
          _logger.error(
            'TaskRecurrenceService: Timeout waiting for parent $parentId lock [$TaskErrorIds.recurrenceLockTimeout]',
          );
          throw Exception('Timeout waiting for parent $parentId lock');
        }

        try {
          await completer.future.timeout(timeoutDuration - elapsed);
        } on TimeoutException {
          // Loop check will handle timeout
        } on StateError catch (e) {
          // Stream was closed while waiting
          _logger.error(
            'TaskRecurrenceService: Lock stream closed unexpectedly [$TaskErrorIds.recurrenceLockStreamClosed]',
            e,
            null,
            DomainLogComponents.task,
          );
          rethrow;
        } catch (e) {
          // Other stream errors
          _logger.error(
            'TaskRecurrenceService: Unexpected error waiting for lock stream [$TaskErrorIds.recurrenceLockStreamError]',
            e,
            null,
            DomainLogComponents.task,
          );
          rethrow;
        }
      }
      // Acquire the lock - this MUST happen after the while loop
      _processingRecurrenceParents[parentId] = Completer<void>();
      lockAcquired = true;
      _logger.debug('TaskRecurrenceService: Acquired lock for parent $parentId');
    } catch (e) {
      // If any error occurs (including timeout), ensure we don't mark lock as acquired
      lockAcquired = false;
      rethrow;
    }

    // Note: The following check is kept for defensive programming.
    // In normal execution flow (lock acquired successfully), this branch is unreachable.
    // However, it serves as a safeguard in case of unexpected state changes.
    // Only proceed if we actually acquired the lock
    // ignore: dead_code - Analyzer identifies this as unreachable in normal flow
    if (!lockAcquired) {
      // This code only executes if lockAcquired is somehow reset to false after line 369
      throw Exception('Failed to acquire lock for parent $parentId');
    }
  }

  /// Checks if a recurrence instance already exists for the given parent and date, excluding the current task
  Future<String?> _findDuplicateRecurrence(String parentId, DateTime scheduledDate, {String? excludeTaskId}) async {
    try {
      // Create a range for the whole day to check for existing tasks safely with integer timestamps
      final startOfDay = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Drift/SQLite stores DateTimes as integer Unix timestamps (seconds or milliseconds depending on config).
      // Comparing DATE(..., 'unixepoch') is fragile if the stored value doesn't match the expectation.
      // It is safer to check if the integer value falls within the timestamps for the start and end of the day.
      var filterSql =
          "recurrence_parent_id = ? AND planned_date >= ? AND planned_date < ? AND deleted_date IS NULL AND completed_at IS NULL";

      // Use milliSecondsSinceEpoch / 1000 if storing as seconds, or just milliSecondsSinceEpoch.
      // Drift default for DateTime is to store as seconds since epoch (unix timestamp).
      final startTimestamp = startOfDay.millisecondsSinceEpoch ~/ 1000;
      final endTimestamp = endOfDay.millisecondsSinceEpoch ~/ 1000;

      final filterArgs = [parentId, startTimestamp, endTimestamp];

      if (excludeTaskId != null) {
        filterSql += " AND id != ?";
        filterArgs.add(excludeTaskId);
      }

      final filter = CustomWhereFilter(filterSql, filterArgs);

      final result = await _taskRepository.getList(
        0,
        1,
        customWhereFilter: filter,
      );

      if (result.items.isNotEmpty) {
        return result.items.first.id;
      }
      return null;
    } catch (e, stackTrace) {
      _logger.error('TaskRecurrenceService: Error checking for duplicate recurrence: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Calculates the next planned and deadline dates for recurrence
  ({DateTime plannedDate, DateTime? deadlineDate}) _calculateNextDates(Task task) {
    try {
      Duration? originalOffset;

      // Determine the offset if both dates exist
      if (task.plannedDate != null && task.deadlineDate != null) {
        originalOffset = task.deadlineDate!.difference(task.plannedDate!);
      }

      // If plannedDate is in the future (after completedAt), keep the original schedule (use plannedDate)
      // Otherwise (completed late), recur from the actual completion time to avoid piling up
      final DateTime recurrenceBaseDate;

      // Check Recurrence From Policy (NEW)
      if (task.recurrenceConfiguration != null) {
        if (task.recurrenceConfiguration!.fromPolicy == RecurrenceFromPolicy.completionDate) {
          // Explicitly recur from completion date
          recurrenceBaseDate = task.completedAt ?? DateTime.now().toUtc();
        } else {
          // Plain old "Planned Date" policy with stricter implementation
          // "Planned Date" policy means "Keep the schedule" - recurrence should be based on
          // the planned date, not completion time, even if completed late.
          // Stricter implementation: prioritize plannedDate, then recurrenceStartDate.
          // Only fall back to deadlineDate/completedAt as absolute last resort.
          recurrenceBaseDate = task.plannedDate ??
              task.recurrenceStartDate ??
              task.deadlineDate ??
              task.completedAt ??
              DateTime.now().toUtc();
        }
      } else {
        // Legacy "Smart" Logic
        if (task.plannedDate != null && task.completedAt != null && task.plannedDate!.isAfter(task.completedAt!)) {
          recurrenceBaseDate = task.plannedDate!;
        } else {
          recurrenceBaseDate = task.completedAt ?? task.plannedDate ?? task.deadlineDate ?? DateTime.now().toUtc();
        }
      }

      // Calculate next recurrence for primary date
      final nextAnchorDate = calculateNextRecurrenceDate(task, recurrenceBaseDate);

      // Reconstruct calculated dates based on what components originally existed
      if (task.plannedDate != null) {
        // Original anchor was plannedDate
        final nextPlannedDate = nextAnchorDate;
        DateTime? nextDeadlineDate;
        if (originalOffset != null) {
          nextDeadlineDate = nextPlannedDate.add(originalOffset);
        }
        return (plannedDate: nextPlannedDate, deadlineDate: nextDeadlineDate);
      } else if (task.deadlineDate != null) {
        // Original anchor was deadlineDate (since plannedDate is null)
        final nextDeadlineDate = nextAnchorDate;
        // As per previous logic, if only deadline exists, set planned to 1 day before
        final nextPlannedDate = nextDeadlineDate.subtract(const Duration(days: 1));
        return (plannedDate: nextPlannedDate, deadlineDate: nextDeadlineDate);
      } else {
        // Fallback if neither existed
        return (plannedDate: nextAnchorDate, deadlineDate: null);
      }
    } on ArgumentError catch (e, stackTrace) {
      _logger.error(
        'TaskRecurrenceService: Invalid date arguments in _calculateNextDates [$TaskErrorIds.recurrenceStateError]',
        e,
        stackTrace,
        DomainLogComponents.task,
      );
      rethrow; // Let the caller handle this
    } catch (e, stackTrace) {
      _logger.error(
        'TaskRecurrenceService: Unexpected error in _calculateNextDates [$TaskErrorIds.recurrenceCreateInstanceFailed]',
        e,
        stackTrace,
        DomainLogComponents.task,
      );
      rethrow;
    }
  }

  /// Test helper method to expose _calculateNextDates for testing
  /// This method should only be used in unit tests
  @visibleForTesting
  ({DateTime plannedDate, DateTime? deadlineDate}) calculateNextDatesForTesting(Task task) {
    return _calculateNextDates(task);
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
    final recurrenceParentIdToUse = task.recurrenceParentId ?? task.id;
    _logger.debug(
        'TaskRecurrenceService: _buildSaveTaskCommand - task.recurrenceParentId=${task.recurrenceParentId}, task.id=${task.id}, using recurrenceParentId=$recurrenceParentIdToUse');

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
      recurrenceParentId: recurrenceParentIdToUse,
      recurrenceConfiguration: task.recurrenceConfiguration,
      tagIdsToAdd: tagIds,
    );
  }

  /// Disposes resources used by this service.
  /// Should be called when the service is no longer needed to prevent memory leaks.
  void dispose() {
    if (_processingRecurrenceParents.isNotEmpty) {
      _logger.warning(
        'TaskRecurrenceService: dispose() called with ${_processingRecurrenceParents.length} pending locks - these will be cleared',
      );
    }
    // Complete all pending completers to signal waiting callers
    for (final completer in _processingRecurrenceParents.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _processingRecurrenceParents.clear();
  }
}
