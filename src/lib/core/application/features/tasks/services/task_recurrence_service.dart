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

class TaskRecurrenceService implements ITaskRecurrenceService {
  final ILogger _logger;
  final ITaskRepository _taskRepository;

  /// Tracks recurrence parent IDs currently being processed to prevent race conditions.
  /// This serializes creation of next instances for the same recurrence chain.
  final Set<String> _processingRecurrenceParents = {};
  final _lockReleaseController = StreamController<String>.broadcast();

  static const int _lockTimeoutMs = 5000;

  TaskRecurrenceService(this._logger, this._taskRepository);
  @override
  bool isRecurring(Task task) {
    return task.recurrenceType != RecurrenceType.none;
  }

  @override
  bool canCreateNextInstance(Task task) {
    if (!isRecurring(task)) {
      return false;
    }

    TaskRecurrenceValidator.validateRecurrenceParameters(task);

    if (task.recurrenceEndDate == null && task.recurrenceCount == null) {
      return true;
    }

    if (task.recurrenceEndDate != null) {
      final DateTime lastDate = task.plannedDate ?? task.deadlineDate ?? DateTime.now();
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

      // Check if the next recurrence instance already exists to prevent duplicates
      final existingId = await _findDuplicateRecurrence(parentId, nextDates.plannedDate);
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
      _processingRecurrenceParents.remove(parentId);
      _lockReleaseController.add(parentId);
      _logger.debug('TaskRecurrenceService: Released lock for parent $parentId');
    }
  }

  Future<void> _acquireRecurrenceLock(String parentId) async {
    // Serialize operations for the same recurrence parent to prevent race conditions.
    final timeoutDuration = const Duration(milliseconds: _lockTimeoutMs);
    final startTime = DateTime.now();

    while (_processingRecurrenceParents.contains(parentId)) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= timeoutDuration) {
        _logger.warning('TaskRecurrenceService: Timeout waiting for parent $parentId lock');
        throw Exception('Timeout waiting for parent $parentId lock');
      }

      try {
        await _lockReleaseController.stream.firstWhere((id) => id == parentId).timeout(timeoutDuration - elapsed);
      } on TimeoutException {
        // Loop check will handle timeout
      } catch (e) {
        _logger.warning('TaskRecurrenceService: Error waiting for lock stream: $e');
        // Ignore other errors and retry check
      }
    }
    _processingRecurrenceParents.add(parentId);
    _logger.debug('TaskRecurrenceService: Acquired lock for parent $parentId');
  }

  /// Checks if a recurrence instance already exists for the given parent and date
  Future<String?> _findDuplicateRecurrence(String parentId, DateTime scheduledDate) async {
    try {
      // Create a range for the whole day to check for existing tasks safely with integer timestamps
      final startOfDay = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Drift/SQLite stores DateTimes as integer Unix timestamps (seconds or milliseconds depending on config).
      // Comparing DATE(..., 'unixepoch') is fragile if the stored value doesn't match the expectation.
      // It is safer to check if the integer value falls within the timestamps for the start and end of the day.
      final filterSql = "recurrence_parent_id = ? AND planned_date >= ? AND planned_date < ? AND deleted_date IS NULL";

      // Use milliSecondsSinceEpoch / 1000 if storing as seconds, or just milliSecondsSinceEpoch.
      // Drift default for DateTime is to store as seconds since epoch (unix timestamp).
      final startTimestamp = startOfDay.millisecondsSinceEpoch ~/ 1000;
      final endTimestamp = endOfDay.millisecondsSinceEpoch ~/ 1000;

      final filterArgs = [parentId, startTimestamp, endTimestamp];

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
    DateTime? primaryDate, secondaryDate;
    Duration? originalOffset;

    // Determine which date exists and calculate offset
    if (task.plannedDate != null && task.deadlineDate != null) {
      originalOffset = task.deadlineDate!.difference(task.plannedDate!);
      primaryDate = task.plannedDate;
    } else if (task.plannedDate != null) {
      primaryDate = task.plannedDate;
    } else if (task.deadlineDate != null) {
      primaryDate = task.deadlineDate;
    } else {
      primaryDate = DateTime.now().toUtc();
    }

    // Calculate next recurrence for primary date
    final nextPrimaryDate = calculateNextRecurrenceDate(task, primaryDate!);

    // Apply same offset to secondary date
    if (originalOffset != null) {
      secondaryDate = nextPrimaryDate.add(originalOffset);
    }

    // Return in correct order
    if (task.plannedDate != null) {
      return (plannedDate: nextPrimaryDate, deadlineDate: secondaryDate);
    } else if (task.deadlineDate != null) {
      // primaryDate was deadlineDate, so nextPrimaryDate is the next deadline.
      // Set plannedDate to a reasonable time before the deadline (e.g., 1 day before)
      final plannedDate = nextPrimaryDate.subtract(const Duration(days: 1));
      return (plannedDate: plannedDate, deadlineDate: nextPrimaryDate);
    } else {
      // Both were null, primaryDate was now(), so nextPrimaryDate is the next planned date.
      return (plannedDate: nextPrimaryDate, deadlineDate: null);
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
      tagIdsToAdd: tagIds,
    );
  }
}
