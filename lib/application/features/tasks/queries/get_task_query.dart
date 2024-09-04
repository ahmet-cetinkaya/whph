import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/domain/features/tasks/task.dart';

class GetTaskQuery implements IRequest<GetTaskQueryResponse> {
  late int id;

  GetTaskQuery({required this.id});
}

class GetTaskQueryResponse extends Task {
  String? topicName;

  GetTaskQueryResponse(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      required super.title,
      this.topicName,
      super.description,
      super.priority,
      super.plannedDate,
      super.deadlineDate,
      super.estimatedTime,
      super.elapsedTime,
      required super.isCompleted});
}

class GetTaskQueryHandler implements IRequestHandler<GetTaskQuery, GetTaskQueryResponse> {
  late final ITaskRepository _taskRepository;

  GetTaskQueryHandler({required ITaskRepository taskRepository}) : _taskRepository = taskRepository;

  @override
  Future<GetTaskQueryResponse> call(GetTaskQuery request) async {
    Task? task = await _taskRepository.getById(
      request.id,
    );
    if (task == null) {
      throw Exception('Task with id ${request.id} not found');
    }

    return GetTaskQueryResponse(
        id: task.id,
        createdDate: task.createdDate,
        modifiedDate: task.modifiedDate,
        title: task.title,
        description: task.description,
        priority: task.priority,
        plannedDate: task.plannedDate,
        deadlineDate: task.deadlineDate,
        estimatedTime: task.estimatedTime,
        elapsedTime: task.elapsedTime,
        isCompleted: task.isCompleted);
  }
}
