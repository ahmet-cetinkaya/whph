import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/domain/features/tasks/task.dart';

class SaveTaskCommand implements IRequest<SaveTaskCommandResponse> {
  final String? id;
  final String title;
  final String? description;
  final EisenhowerPriority? priority;
  final DateTime? plannedDate;
  final DateTime? deadlineDate;
  final int? estimatedTime;
  final int? elapsedTime;
  final bool isCompleted;

  SaveTaskCommand(
      {this.id,
      required this.title,
      this.description,
      this.priority,
      this.plannedDate,
      this.deadlineDate,
      this.estimatedTime,
      this.elapsedTime,
      this.isCompleted = false});
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

  SaveTaskCommandHandler({required ITaskRepository taskService}) : _taskRepository = taskService;

  @override
  Future<SaveTaskCommandResponse> call(SaveTaskCommand request) async {
    Task? task;

    if (request.id != null) {
      task = await _taskRepository.getById(request.id!);
      if (task == null) {
        throw Exception('Task with id ${request.id} not found');
      }

      task.title = request.title;
      task.description = request.description;
      task.priority = request.priority;
      task.plannedDate = request.plannedDate;
      task.deadlineDate = request.deadlineDate;
      task.estimatedTime = request.estimatedTime;
      task.elapsedTime = request.elapsedTime;
      task.isCompleted = request.isCompleted;
      await _taskRepository.update(task);
    } else {
      task = Task(
          id: nanoid(),
          createdDate: DateTime(0),
          title: request.title,
          description: request.description,
          priority: request.priority,
          plannedDate: request.plannedDate,
          deadlineDate: request.deadlineDate,
          estimatedTime: request.estimatedTime,
          elapsedTime: request.elapsedTime,
          isCompleted: false);
      await _taskRepository.add(task);
    }

    return SaveTaskCommandResponse(
      id: task.id,
      createdDate: task.createdDate,
      modifiedDate: task.modifiedDate,
    );
  }
}
