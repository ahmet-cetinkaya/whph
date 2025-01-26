import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';

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

  SaveTaskCommand(
      {this.id,
      required this.title,
      this.description,
      this.priority,
      this.plannedDate,
      this.deadlineDate,
      this.estimatedTime,
      this.isCompleted = false,
      this.tagIdsToAdd});
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
        throw BusinessException('Task with id ${request.id} not found');
      }

      task.title = request.title;
      task.description = request.description;
      task.priority = request.priority;
      task.plannedDate = request.plannedDate;
      task.deadlineDate = request.deadlineDate;
      task.estimatedTime = request.estimatedTime;
      task.isCompleted = request.isCompleted;
      await _taskRepository.update(task);
    } else {
      task = Task(
          id: nanoid(),
          createdDate: DateTime.now(),
          title: request.title,
          description: request.description,
          priority: request.priority,
          plannedDate: request.plannedDate,
          deadlineDate: request.deadlineDate,
          estimatedTime: request.estimatedTime,
          isCompleted: false);
      await _taskRepository.add(task);
    }

    // Add initial tags if provided
    if (request.tagIdsToAdd != null) {
      for (var tagId in request.tagIdsToAdd!) {
        var taskTag = TaskTag(
          id: nanoid(),
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
