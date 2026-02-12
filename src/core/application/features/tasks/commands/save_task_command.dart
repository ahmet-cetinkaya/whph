import 'package:mediatr/mediatr.dart';
import 'package:application/features/tasks/constants/task_translation_keys.dart';
import 'package:application/shared/utils/key_helper.dart';
import 'package:domain/features/tasks/models/recurrence_configuration.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:application/features/tasks/services/task_time_record_service.dart';
import 'package:application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:acore/acore.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/tasks/task_tag.dart';
import 'package:domain/features/tasks/task_constants.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:domain/shared/constants/task_error_ids.dart';
import 'package:domain/shared/constants/domain_log_components.dart';

class SaveTaskCommand implements IRequest<SaveTaskCommandResponse> {
  final String? id;
  final String title;
  final String? description;
  final EisenhowerPriority? priority;
  final DateTime? plannedDate;
  final DateTime? deadlineDate;
  final int? estimatedTime;
  final DateTime? completedAt;
  final List<String>? tagIdsToAdd;
  final String? parentTaskId;
  final double? order;
  final ReminderTime? plannedDateReminderTime;
  final int? plannedDateReminderCustomOffset;
  final ReminderTime? deadlineDateReminderTime;
  final int? deadlineDateReminderCustomOffset;
  final RecurrenceType? recurrenceType;
  final int? recurrenceInterval;
  final List<WeekDays>? recurrenceDays;
  final DateTime? recurrenceStartDate;
  final DateTime? recurrenceEndDate;
  final int? recurrenceCount;
  final String? recurrenceParentId;
  final RecurrenceConfiguration? recurrenceConfiguration;

  SaveTaskCommand({
    this.id,
    required this.title,
    this.description,
    this.priority,
    DateTime? plannedDate,
    DateTime? deadlineDate,
    this.estimatedTime,
    DateTime? completedAt,
    this.tagIdsToAdd,
    this.parentTaskId,
    this.order,
    this.plannedDateReminderTime,
    this.plannedDateReminderCustomOffset,
    this.deadlineDateReminderTime,
    this.deadlineDateReminderCustomOffset,
    this.recurrenceType,
    this.recurrenceInterval,
    this.recurrenceDays,
    DateTime? recurrenceStartDate,
    DateTime? recurrenceEndDate,
    this.recurrenceCount,
    this.recurrenceParentId,
    this.recurrenceConfiguration,
  })  : plannedDate = plannedDate != null ? DateTimeHelper.toUtcDateTime(plannedDate) : null,
        deadlineDate = deadlineDate != null ? DateTimeHelper.toUtcDateTime(deadlineDate) : null,
        completedAt = completedAt != null ? DateTimeHelper.toUtcDateTime(completedAt) : null,
        recurrenceStartDate = recurrenceStartDate != null ? DateTimeHelper.toUtcDateTime(recurrenceStartDate) : null,
        recurrenceEndDate = recurrenceEndDate != null ? DateTimeHelper.toUtcDateTime(recurrenceEndDate) : null;
}

class SaveTaskCommandResponse {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;

  SaveTaskCommandResponse({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
  });
}

class SaveTaskCommandHandler implements IRequestHandler<SaveTaskCommand, SaveTaskCommandResponse> {
  final ITaskRepository _taskRepository;
  final ITaskTagRepository _taskTagRepository;
  final ITaskTimeRecordRepository _taskTimeRecordRepository;
  final ISettingRepository _settingRepository;

  SaveTaskCommandHandler({
    required ITaskRepository taskService,
    required ITaskTagRepository taskTagRepository,
    required ITaskTimeRecordRepository taskTimeRecordRepository,
    required ISettingRepository settingRepository,
  })  : _taskRepository = taskService,
        _taskTagRepository = taskTagRepository,
        _taskTimeRecordRepository = taskTimeRecordRepository,
        _settingRepository = settingRepository;

  /// Gets the default estimated time from user settings
  /// Returns null if user has disabled default estimated time
  Future<int?> _getDefaultEstimatedTime() async {
    try {
      final setting = await _settingRepository.getByKey(SettingKeys.taskDefaultEstimatedTime);
      if (setting == null) {
        // Setting not found, use current default behavior (15 minutes)
        return TaskConstants.defaultEstimatedTime;
      }

      final value = setting.getValue<int?>();
      // Return null if user set to 0 (disabled), otherwise return the value
      return value == 0 ? null : value;
    } on FormatException catch (e, stackTrace) {
      // Handle parsing errors specifically
      DomainLogger.error(
        'SaveTaskCommand: Failed to parse default estimated time setting [$TaskErrorIds.saveCommandDefaultEstimatedTimeFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return TaskConstants.defaultEstimatedTime;
    } catch (e, stackTrace) {
      // Handle any other unexpected errors (database errors, etc.)
      DomainLogger.error(
        'SaveTaskCommand: Unexpected error getting default estimated time [$TaskErrorIds.saveCommandDefaultEstimatedTimeFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return TaskConstants.defaultEstimatedTime;
    }
  }

  Future<(ReminderTime, int?)> _getDefaultPlannedDateReminder() async {
    String? value; // Declare outside try block for error logging
    try {
      final setting = await _settingRepository.getByKey(SettingKeys.taskDefaultPlannedDateReminder);
      if (setting == null) return (TaskConstants.defaultReminderTime, null);

      value = setting.getValue<String>();
      if (value.isEmpty) {
        DomainLogger.warning(
          'SaveTaskCommand: Empty reminder time value, using default [$TaskErrorIds.saveCommandDefaultPlannedDateReminderFailed]',
        );
        return (TaskConstants.defaultReminderTime, null);
      }

      final reminderTime = ReminderTimeExtension.fromString(value);

      // Fetch custom offset if type is custom
      if (reminderTime == ReminderTime.custom) {
        final offset = await _getDefaultPlannedDateReminderCustomOffset();
        if (offset == null) {
          DomainLogger.warning(
            'SaveTaskCommand: Default planned date reminder is custom without offset, treating as none. Check setting: ${SettingKeys.taskDefaultPlannedDateReminderCustomOffset}',
          );
          return (ReminderTime.none, null);
        }
        return (reminderTime, offset);
      }

      return (reminderTime, null);
    } on ArgumentError catch (e, stackTrace) {
      // Handle invalid enum values specifically
      DomainLogger.error(
        'SaveTaskCommand: Invalid reminder time value: "$value" [$TaskErrorIds.saveCommandDefaultPlannedDateReminderFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return (TaskConstants.defaultReminderTime, null);
    } on FormatException catch (e, stackTrace) {
      // Handle parsing errors for reminder time string
      DomainLogger.error(
        'SaveTaskCommand: Failed to parse default planned date reminder setting [$TaskErrorIds.saveCommandDefaultPlannedDateReminderFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return (TaskConstants.defaultReminderTime, null);
    } catch (e, stackTrace) {
      DomainLogger.error(
        'SaveTaskCommand: Error getting default planned date reminder [$TaskErrorIds.saveCommandDefaultPlannedDateReminderFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return (TaskConstants.defaultReminderTime, null);
    }
  }

  /// Gets the default planned date reminder custom offset
  Future<int?> _getDefaultPlannedDateReminderCustomOffset() async {
    try {
      final setting = await _settingRepository.getByKey(SettingKeys.taskDefaultPlannedDateReminderCustomOffset);
      if (setting == null) return null;

      final value = setting.getValue<int?>();
      if (!ReminderOffsets.isValidCustomOffset(value)) {
        return null;
      }
      return value;
    } on FormatException catch (e, stackTrace) {
      // Handle parsing errors specifically
      DomainLogger.error(
        'SaveTaskCommand: Failed to parse default reminder custom offset setting [$TaskErrorIds.saveCommandDefaultReminderCustomOffsetFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return null;
    } catch (e, stackTrace) {
      DomainLogger.error(
        'SaveTaskCommand: Error getting default planned date reminder custom offset [$TaskErrorIds.saveCommandDefaultReminderCustomOffsetFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return null;
    }
  }

  @override
  Future<SaveTaskCommandResponse> call(SaveTaskCommand request) async {
    Task? task;

    if (request.id != null) {
      task = await _taskRepository.getById(request.id!);
      if (task == null) {
        throw BusinessException("Task with id ${request.id} not found", TaskTranslationKeys.taskNotFoundError);
      }

      task.title = request.title;
      task.description = request.description;
      task.priority = request.priority;

      // Check if planned date is being changed
      final bool isPlannedDateChanged = request.plannedDate != task.plannedDate;
      task.plannedDate = request.plannedDate;

      task.deadlineDate = request.deadlineDate;
      task.estimatedTime = request.estimatedTime != null && request.estimatedTime! > 0 ? request.estimatedTime : null;

      // Handle completion status
      task.completedAt = request.completedAt;

      task.order = request.order ?? task.order;

      // Update reminder settings
      if (request.plannedDateReminderTime != null) {
        // Explicit reminder setting provided
        task.plannedDateReminderTime = request.plannedDateReminderTime!;
        task.plannedDateReminderCustomOffset = request.plannedDateReminderCustomOffset;
      } else if (isPlannedDateChanged) {
        if (task.plannedDate != null) {
          // When the date changes, the default reminder policy is applied.
          final (defaultReminder, customOffset) = await _getDefaultPlannedDateReminder();
          task.plannedDateReminderTime = defaultReminder;
          task.plannedDateReminderCustomOffset = customOffset;
        } else {
          // Date cleared -> clear reminder
          task.plannedDateReminderTime = ReminderTime.none;
          task.plannedDateReminderCustomOffset = null;
        }
      }

      if (request.deadlineDateReminderTime != null) {
        task.deadlineDateReminderTime = request.deadlineDateReminderTime!;
        task.deadlineDateReminderCustomOffset = request.deadlineDateReminderCustomOffset;
      }

      // Update recurrence settings if provided
      if (request.recurrenceType != null) {
        task.recurrenceType = request.recurrenceType!;
      }

      // Only update these if recurrence type is not none
      if (task.recurrenceType != RecurrenceType.none) {
        task.recurrenceInterval = request.recurrenceInterval;
        task.setRecurrenceDays(request.recurrenceDays);
        task.recurrenceStartDate = request.recurrenceStartDate;
        task.recurrenceEndDate = request.recurrenceEndDate;
        task.recurrenceCount = request.recurrenceCount;
      } else {
        // Clear recurrence settings if type is none
        task.recurrenceInterval = null;
        task.setRecurrenceDays(null);
        task.recurrenceStartDate = null;
        task.recurrenceEndDate = null;
        task.recurrenceCount = null;
        task.recurrenceConfiguration = null;
      }

      // Only update recurrenceParentId if explicitly provided in the request.
      // This preserves the existing value when updating for completion toggle or other changes.
      if (request.recurrenceParentId != null) {
        task.recurrenceParentId = request.recurrenceParentId;
      }

      if (request.recurrenceConfiguration != null) {
        task.recurrenceConfiguration = request.recurrenceConfiguration;
      }

      await _taskRepository.update(task);
    } else {
      // Get the last task to determine the order
      final lastTasks = await _taskRepository.getList(
        0,
        1,
        customWhereFilter: CustomWhereFilter(
          "parent_task_id ${request.parentTaskId != null ? '= ?' : 'IS NULL'} AND deleted_date IS NULL",
          request.parentTaskId != null ? [request.parentTaskId!] : [],
        ),
        customOrder: [CustomOrder(field: "order", direction: SortDirection.desc)],
      );

      const int orderStep = 1000;
      final lastOrder = lastTasks.items.isNotEmpty ? lastTasks.items.first.order : 0;
      final newOrder = request.order ?? ((lastOrder + orderStep).toDouble());

      // Resolve default reminder for new task
      ReminderTime plannedDateReminderTime;
      int? plannedDateReminderCustomOffset = request.plannedDateReminderCustomOffset;

      if (request.plannedDateReminderTime != null) {
        plannedDateReminderTime = request.plannedDateReminderTime!;
      } else if (request.plannedDate != null) {
        final (defaultReminder, customOffset) = await _getDefaultPlannedDateReminder();
        plannedDateReminderTime = defaultReminder;
        plannedDateReminderCustomOffset = customOffset;
      } else {
        plannedDateReminderTime = ReminderTime.none;
      }

      task = Task(
          id: KeyHelper.generateStringId(),
          createdDate: DateTime.now().toUtc(),
          title: request.title,
          description: request.description,
          priority: request.priority,
          plannedDate: request.plannedDate,
          deadlineDate: request.deadlineDate,
          estimatedTime: request.estimatedTime == null
              ? await _getDefaultEstimatedTime()
              : (request.estimatedTime! > 0 ? request.estimatedTime : null),
          completedAt: request.completedAt,
          parentTaskId: request.parentTaskId,
          order: newOrder,
          plannedDateReminderTime: plannedDateReminderTime,
          plannedDateReminderCustomOffset: plannedDateReminderCustomOffset,
          deadlineDateReminderTime: request.deadlineDateReminderTime ?? ReminderTime.none,
          deadlineDateReminderCustomOffset: request.deadlineDateReminderCustomOffset,
          recurrenceType: request.recurrenceType ?? RecurrenceType.none,
          recurrenceInterval: request.recurrenceInterval,
          recurrenceStartDate: request.recurrenceStartDate,
          recurrenceEndDate: request.recurrenceEndDate,
          recurrenceCount: request.recurrenceCount,
          recurrenceParentId: request.recurrenceParentId,
          recurrenceConfiguration: request.recurrenceConfiguration);

      if (request.recurrenceDays != null) {
        task.setRecurrenceDays(request.recurrenceDays);
      }

      await _taskRepository.add(task);
    }

    // Auto-add time record when task is completed and has estimated time but no existing time records
    final bool isTaskCompleted = request.completedAt != null;
    if (isTaskCompleted && task.estimatedTime != null && task.estimatedTime! > 0) {
      // Check if there are already time records for this task
      final existingTimeRecords = await _taskTimeRecordRepository.getList(
        0, 1, // Only need to check if any exist
        customWhereFilter: CustomWhereFilter('task_id = ? AND deleted_date IS NULL', [task.id]),
      );

      // If no time records exist, create one with the estimated time
      if (existingTimeRecords.items.isEmpty) {
        final now = DateTime.now().toUtc();

        await TaskTimeRecordService.addDurationToTaskTimeRecord(
          repository: _taskTimeRecordRepository,
          taskId: task.id,
          targetDate: now,
          durationToAdd: task.estimatedTime! * 60, // Convert minutes to seconds
        );
      }
    }

    // Add initial tags if provided
    if (request.tagIdsToAdd != null) {
      for (final tagId in request.tagIdsToAdd!) {
        final taskTag = TaskTag(
          id: KeyHelper.generateStringId(),
          taskId: task.id,
          tagId: tagId,
          createdDate: DateTime.now().toUtc(),
        );
        await _taskTagRepository.add(taskTag);
      }
    }

    return SaveTaskCommandResponse(
      id: task.id,
      createdDate: task.createdDate,
      modifiedDate: task.modifiedDate,
    );
  }
}
