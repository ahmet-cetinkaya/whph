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
          if (config.endDate!.isBefore(DateTime.now().toUtc())) {
            return false;
          }
          final lastDate = task.plannedDate ?? task.deadlineDate ?? DateTime.now().toUtc();
          final nextDate = calculateNextRecurrenceDate(task, lastDate);
          // Inclusive per iCal standard: stop if next recurrence is on or after end date
          return nextDate.isBefore(config.endDate!);
        case RecurrenceEndCondition.count:
          final taskCountLimit = task.recurrenceCount;
          final configCountLimit = config.occurrenceCount;

          if (taskCountLimit != null) {
            return taskCountLimit > 0;
          }
          if (configCountLimit != null) {
            return configCountLimit > 0;
          }
          throw StateError(
            'RecurrenceConfiguration has endCondition set to "count" but both task.recurrenceCount and config.occurrenceCount are null. '
            'This is an invalid configuration state that indicates data corruption or incomplete migration. '
            'Task ID: ${task.id}, RecurrenceConfiguration: $config',
          );
      }
    }

    // Legacy support
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
    if (task.recurrenceConfiguration != null) {
      return _calculateFromConfiguration(task.recurrenceConfiguration!, task, currentDate);
    }

    // Legacy logic
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
        if (config.weeklySchedule != null && config.weeklySchedule!.isNotEmpty) {
          final referenceDate = task.recurrenceStartDate ?? task.plannedDate ?? currentDate;
          final includeToday = config.fromPolicy == RecurrenceFromPolicy.completionDate;
          return DateHelper.findNextWeekdayOccurrenceWithTimes(
            currentDate,
            config.weeklySchedule!,
            config.interval,
            referenceDate,
            includeToday: includeToday,
          );
        }
        if (config.daysOfWeek != null && config.daysOfWeek!.isNotEmpty) {
          // DateHelper.findNextWeekdayOccurrence expects List<int>,
          // use recurrenceStartDate for interval alignment to prevent drift
          final referenceDate = task.recurrenceStartDate ?? task.plannedDate ?? currentDate;
          return DateHelper.findNextWeekdayOccurrence(
            currentDate,
            config.daysOfWeek!.toList()..sort(),
            config.interval,
            referenceDate,
          );
        }
        return currentDate.add(Duration(days: 7 * config.interval));

      case RecurrenceFrequency.monthly:
        int nextMonth = currentDate.month + config.interval;
        int year = currentDate.year;
        while (nextMonth > 12) {
          nextMonth -= 12;
          year++;
        }

        if (config.monthlyPatternType == MonthlyPatternType.relativeDay) {
          final weekOfMonth = config.weekOfMonth ?? 1;
          final dayOfWeek = config.dayOfWeek ?? 1;

          final nextDate = DateHelper.getNthWeekdayOfMonth(year, nextMonth, dayOfWeek, weekOfMonth);
          return DateTime(nextDate.year, nextDate.month, nextDate.day, currentDate.hour, currentDate.minute);
        } else {
          final desiredDay = config.dayOfMonth ?? 1;

          // Clamp to last day if target month has fewer days
          final lastDayOfNextMonth = DateTime(year, nextMonth + 1, 0).day;
          final actualDay = desiredDay > lastDayOfNextMonth ? lastDayOfNextMonth : desiredDay;

          return DateTime(year, nextMonth, actualDay, currentDate.hour, currentDate.minute);
        }

      case RecurrenceFrequency.yearly:
        final targetMonth = config.monthOfYear ?? currentDate.month;
        int targetYear = currentDate.year + config.interval;

        // Advance to next interval if target month has already passed
        if (config.monthOfYear != null && currentDate.month > config.monthOfYear!) {
          targetYear += config.interval;
        }

        // Clamp day if it doesn't exist in target month (e.g., Feb 31)
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

  @override
  Future<String?> handleCompletedRecurringTask(String taskId, Mediator mediator) async {
    try {
      final task = await _getTaskForRecurrence(taskId, mediator);
      if (!_canProcessRecurrence(task)) {
        return null;
      }

      final parentId = task.recurrenceParentId ?? task.id;
      await _acquireRecurrenceLock(parentId);

      try {
        // Re-verify the task is still completed before creating recurrence.
        // This is crucial now that we've moved the lock acquisition earlier.
        final currentTaskState = await _getTaskForRecurrence(taskId, mediator);
        if (!currentTaskState.isCompleted) {
          _logger.info('TaskRecurrenceService: Task $taskId is no longer completed - ABORTING recurrence creation');
          return null;
        }

        return await _createNextRecurrenceInstanceInternal(currentTaskState, mediator);
      } finally {
        final completer = _processingRecurrenceParents.remove(parentId);
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
        _logger.debug('TaskRecurrenceService: Released lock for parent $parentId');
      }
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

  Future<Task> _getTaskForRecurrence(String taskId, Mediator mediator) async {
    return await mediator.send<GetTaskQuery, GetTaskQueryResponse>(
      GetTaskQuery(id: taskId),
    );
  }

  bool _canProcessRecurrence(Task task) {
    if (!task.isCompleted || task.recurrenceType == RecurrenceType.none) {
      return false;
    }

    return canCreateNextInstance(task);
  }

  /// Assumed to be running under a lock for the parentId.
  Future<String> _createNextRecurrenceInstanceInternal(Task task, Mediator mediator) async {
    final parentId = task.recurrenceParentId ?? task.id;

    try {
      // Re-verify the task is still completed before creating recurrence.
      final currentTaskState = await _getTaskForRecurrence(task.id, mediator);
      if (!currentTaskState.isCompleted) {
        _logger.info('TaskRecurrenceService: Task ${task.id} is no longer completed - ABORTING recurrence creation');
        throw StateError('Task is no longer completed');
      }

      final nextDates = _calculateNextDates(task);

      // Prevent data corruption from invalid recurrence calculations
      final plannedDate = nextDates.plannedDate;
      final deadlineDate = nextDates.deadlineDate;
      if (deadlineDate != null && deadlineDate.isBefore(plannedDate)) {
        _logger.error(
          'TaskRecurrenceService: Calculated invalid date range for task ${task.id} - '
          'planned: $plannedDate, deadline: $deadlineDate',
        );
        throw StateError(
          'Calculated invalid date range for task ${task.id}: '
          'deadline ($deadlineDate) is before planned ($plannedDate)',
        );
      }

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
    } catch (e) {
      rethrow;
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

    // ignore: dead_code
    if (!lockAcquired) {
      throw Exception('Failed to acquire lock for parent $parentId');
    }
  }

  Future<String?> _findDuplicateRecurrence(String parentId, DateTime scheduledDate, {String? excludeTaskId}) async {
    try {
      // Check for any uncompleted instance for the same parent to prevent
      // duplicates from slightly different date calculations
      var filterSql = "recurrence_parent_id = ? AND deleted_date IS NULL AND completed_at IS NULL";
      final filterArgs = [parentId];

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

      if (task.recurrenceConfiguration != null) {
        if (task.recurrenceConfiguration!.fromPolicy == RecurrenceFromPolicy.completionDate) {
          recurrenceBaseDate = task.completedAt ?? DateTime.now().toUtc();
        } else {
          // Keep the schedule - base recurrence on planned date not completion time
          recurrenceBaseDate = task.plannedDate ??
              task.recurrenceStartDate ??
              task.deadlineDate ??
              task.completedAt ??
              DateTime.now().toUtc();
        }
      } else {
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

  Future<List<String>> _getTaskTags(String taskId, Mediator mediator) async {
    final taskTags = await mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
      GetListTaskTagsQuery(taskId: taskId, pageIndex: 0, pageSize: double.maxFinite.toInt()),
    );
    return taskTags.items.map((tag) => tag.tagId).toList();
  }

  int? _calculateNextRecurrenceCount(Task task) {
    if (task.recurrenceCount == null || task.recurrenceCount! <= 0) {
      return task.recurrenceCount;
    }

    return task.recurrenceCount! - 1;
  }

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

  void dispose() {
    if (_processingRecurrenceParents.isNotEmpty) {
      _logger.warning(
        'TaskRecurrenceService: dispose() called with ${_processingRecurrenceParents.length} pending locks - these will be cleared',
      );
    }
    for (final completer in _processingRecurrenceParents.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _processingRecurrenceParents.clear();
  }
}
