import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';

class GetTaskQuery implements IRequest<GetTaskQueryResponse> {
  late String id;

  GetTaskQuery({required this.id});
}

class GetTaskQueryResponse extends Task {
  int totalDuration = 0;

  GetTaskQueryResponse(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required super.title,
      super.description,
      super.priority,
      super.plannedDate,
      super.deadlineDate,
      super.estimatedTime,
      required this.totalDuration,
      required super.isCompleted});
}

class GetTaskQueryHandler implements IRequestHandler<GetTaskQuery, GetTaskQueryResponse> {
  final ITaskRepository _taskRepository;
  final ITaskTimeRecordRepository _taskTimeRecordRepository;

  GetTaskQueryHandler({
    required ITaskRepository taskRepository,
    required ITaskTimeRecordRepository taskTimeRecordRepository,
  })  : _taskRepository = taskRepository,
        _taskTimeRecordRepository = taskTimeRecordRepository;

  @override
  Future<GetTaskQueryResponse> call(GetTaskQuery request) async {
    Task? task = await _taskRepository.getById(request.id);
    if (task == null) {
      throw BusinessException('Task with id ${request.id} not found');
    }

    final totalDuration = await _taskTimeRecordRepository.getTotalDurationByTaskId(request.id);

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
        totalDuration: totalDuration,
        isCompleted: task.isCompleted);
  }
}
