import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/tasks/services/task_time_record_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';

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
  final ReminderTime? deadlineDateReminderTime;
  final RecurrenceType? recurrenceType;
  final int? recurrenceInterval;
  final List<WeekDays>? recurrenceDays;
  final DateTime? recurrenceStartDate;
  final DateTime? recurrenceEndDate;
  final int? recurrenceCount;
  final String? recurrenceParentId;

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
    this.deadlineDateReminderTime,
    this.recurrenceType,
    this.recurrenceInterval,
    this.recurrenceDays,
    DateTime? recurrenceStartDate,
    DateTime? recurrenceEndDate,
    this.recurrenceCount,
    this.recurrenceParentId,
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
    } on FormatException catch (e, s) {
      // Handle parsing errors specifically
      Logger.warning('Failed to parse default estimated time setting. Error: $e\n$s');
      return TaskConstants.defaultEstimatedTime;
    } catch (e) {
      // Handle any other unexpected errors
      Logger.error('Unexpected error getting default estimated time: $e');
      return TaskConstants.defaultEstimatedTime;
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
      task.plannedDate = request.plannedDate;
      task.deadlineDate = request.deadlineDate;
      task.estimatedTime = request.estimatedTime != null && request.estimatedTime! > 0 ? request.estimatedTime : null;

      // Handle completion status
      task.completedAt = request.completedAt;

      task.order = request.order ?? task.order;

      // Always update reminder settings
      if (request.plannedDateReminderTime != null) {
        task.plannedDateReminderTime = request.plannedDateReminderTime!;
      }

      if (request.deadlineDateReminderTime != null) {
        task.deadlineDateReminderTime = request.deadlineDateReminderTime!;
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
      }

      // Always update recurrenceParentId if provided in the request, regardless of recurrence type
      // This allows users to clear a parent ID (set to null) while keeping other recurrence settings
      task.recurrenceParentId = request.recurrenceParentId;

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
          plannedDateReminderTime: request.plannedDateReminderTime ?? ReminderTime.none,
          deadlineDateReminderTime: request.deadlineDateReminderTime ?? ReminderTime.none,
          recurrenceType: request.recurrenceType ?? RecurrenceType.none,
          recurrenceInterval: request.recurrenceInterval,
          recurrenceStartDate: request.recurrenceStartDate,
          recurrenceEndDate: request.recurrenceEndDate,
          recurrenceCount: request.recurrenceCount,
          recurrenceParentId: request.recurrenceParentId);

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
