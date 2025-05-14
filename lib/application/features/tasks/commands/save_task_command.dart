import 'package:mediatr/mediatr.dart';
import 'package:whph/application/shared/utils/key_helper.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/application/features/tasks/constants/task_translation_keys.dart';

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

  SaveTaskCommand(
      {this.id,
      required this.title,
      this.description,
      this.priority,
      this.plannedDate,
      this.deadlineDate,
      this.estimatedTime,
      this.isCompleted = false,
      this.tagIdsToAdd,
      this.parentTaskId,
      this.order,
      this.plannedDateReminderTime,
      this.deadlineDateReminderTime});
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
        throw BusinessException(TaskTranslationKeys.taskNotFoundError);
      }

      task.title = request.title;
      task.description = request.description;
      task.priority = request.priority;
      task.plannedDate = request.plannedDate;
      task.deadlineDate = request.deadlineDate;
      task.estimatedTime = request.estimatedTime;
      task.isCompleted = request.isCompleted;
      task.order = request.order ?? task.order;

      // Always update reminder settings
      if (request.plannedDateReminderTime != null) {
        task.plannedDateReminderTime = request.plannedDateReminderTime!;
      }

      if (request.deadlineDateReminderTime != null) {
        task.deadlineDateReminderTime = request.deadlineDateReminderTime!;
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
          createdDate: DateTime.now(),
          title: request.title,
          description: request.description,
          priority: request.priority,
          plannedDate: request.plannedDate,
          deadlineDate: request.deadlineDate,
          estimatedTime: request.estimatedTime,
          isCompleted: false,
          parentTaskId: request.parentTaskId,
          order: newOrder,
          plannedDateReminderTime: request.plannedDateReminderTime ?? ReminderTime.none,
          deadlineDateReminderTime: request.deadlineDateReminderTime ?? ReminderTime.none);
      await _taskRepository.add(task);
    }

    // Add initial tags if provided
    if (request.tagIdsToAdd != null) {
      for (final tagId in request.tagIdsToAdd!) {
        final taskTag = TaskTag(
          id: KeyHelper.generateStringId(),
          taskId: task.id,
          tagId: tagId,
          createdDate: DateTime.now(),
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
