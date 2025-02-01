import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/application/features/tasks/constants/task_translation_keys.dart';

class GetTaskQuery implements IRequest<GetTaskQueryResponse> {
  late String id;

  GetTaskQuery({required this.id});
}

class GetTaskQueryResponse extends Task {
  int totalDuration = 0;
  double subTasksCompletionPercentage = 0;
  List<Task> subTasks = [];

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
      required super.isCompleted,
      required super.parentTaskId,
      required this.subTasksCompletionPercentage,
      required this.subTasks});
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
      throw BusinessException(TaskTranslationKeys.taskNotFoundError);
    }

    final totalDuration = await _taskTimeRecordRepository.getTotalDurationByTaskId(request.id);

    final subTasks = await _taskRepository.getAll(
      customWhereFilter: CustomWhereFilter("parent_task_id = ?", [task.id]),
    );

    double subTasksCompletionPercentage = 0;
    if (subTasks.isNotEmpty) {
      final completedSubTasks = subTasks.where((subTask) => subTask.isCompleted).length;
      subTasksCompletionPercentage = (completedSubTasks / subTasks.length) * 100;
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
        totalDuration: totalDuration,
        isCompleted: task.isCompleted,
        parentTaskId: task.parentTaskId,
        subTasksCompletionPercentage: subTasksCompletionPercentage,
        subTasks: subTasks);
  }
}
