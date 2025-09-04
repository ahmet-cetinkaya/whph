import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';

class SaveTaskCommand implements IRequest<SaveTaskCommandResponse> {
  final String? id;
  final String title;
  final String? description;
  final EisenhowerPriority? priority;
  final DateTime? plannedDate;
  final DateTime? deadlineDate;
  final int? estimatedTime;
  final bool isCompleted;
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

  SaveTaskCommand({
    this.id,
    required this.title,
    this.description,
    this.priority,
    DateTime? plannedDate,
    DateTime? deadlineDate,
    this.estimatedTime,
    this.isCompleted = false,
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
  })  : plannedDate = plannedDate != null ? DateTimeHelper.toUtcDateTime(plannedDate) : null,
        deadlineDate = deadlineDate != null ? DateTimeHelper.toUtcDateTime(deadlineDate) : null,
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

  SaveTaskCommandHandler({required ITaskRepository taskService, required ITaskTagRepository taskTagRepository})
      : _taskRepository = taskService,
        _taskTagRepository = taskTagRepository;

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
      task.estimatedTime = request.estimatedTime != null && request.estimatedTime! >= 0 ? request.estimatedTime : null;
      task.isCompleted = request.isCompleted;
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

        // Update recurrence days if provided
        if (request.recurrenceDays != null) {
          task.setRecurrenceDays(request.recurrenceDays);
        }

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
          estimatedTime: request.estimatedTime != null && request.estimatedTime! >= 0 ? request.estimatedTime : null,
          isCompleted: request.isCompleted,
          parentTaskId: request.parentTaskId,
          order: newOrder,
          plannedDateReminderTime: request.plannedDateReminderTime ?? ReminderTime.none,
          deadlineDateReminderTime: request.deadlineDateReminderTime ?? ReminderTime.none,
          recurrenceType: request.recurrenceType ?? RecurrenceType.none,
          recurrenceInterval: request.recurrenceInterval,
          recurrenceStartDate: request.recurrenceStartDate,
          recurrenceEndDate: request.recurrenceEndDate,
          recurrenceCount: request.recurrenceCount);

      if (request.recurrenceDays != null) {
        task.setRecurrenceDays(request.recurrenceDays);
      }

      await _taskRepository.add(task);
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
