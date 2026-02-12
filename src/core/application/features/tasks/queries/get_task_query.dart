import 'package:mediatr/mediatr.dart';
import 'package:application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:acore/acore.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:application/features/tasks/constants/task_translation_keys.dart';

class GetTaskQuery implements IRequest<GetTaskQueryResponse> {
  late String id;

  GetTaskQuery({required this.id});
}

class GetTaskQueryResponse extends Task {
  int totalDuration;
  double subTasksCompletionPercentage;
  List<Task> subTasks;
  Task? parentTask;

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
      super.completedAt,
      required super.parentTaskId,
      required this.subTasksCompletionPercentage,
      required this.subTasks,
      this.parentTask,
      super.plannedDateReminderTime = ReminderTime.none,
      super.plannedDateReminderCustomOffset,
      super.deadlineDateReminderTime = ReminderTime.none,
      super.deadlineDateReminderCustomOffset,
      super.recurrenceType = RecurrenceType.none,
      super.recurrenceInterval,
      super.recurrenceDaysString,
      super.recurrenceStartDate,
      super.recurrenceEndDate,
      super.recurrenceCount,
      super.recurrenceParentId,
      super.recurrenceConfiguration});
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
      throw BusinessException('Task not found', TaskTranslationKeys.taskNotFoundError);
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

    Task? fetchedParentTask;
    if (task.parentTaskId != null) {
      fetchedParentTask = await _taskRepository.getById(task.parentTaskId!);
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
      completedAt: task.completedAt,
      parentTaskId: task.parentTaskId,
      subTasksCompletionPercentage: subTasksCompletionPercentage,
      subTasks: subTasks,
      parentTask: fetchedParentTask,
      plannedDateReminderTime: task.plannedDateReminderTime,
      plannedDateReminderCustomOffset: task.plannedDateReminderCustomOffset,
      deadlineDateReminderTime: task.deadlineDateReminderTime,
      deadlineDateReminderCustomOffset: task.deadlineDateReminderCustomOffset,
      recurrenceType: task.recurrenceType,
      recurrenceInterval: task.recurrenceInterval,
      recurrenceDaysString: task.recurrenceDaysString,
      recurrenceStartDate: task.recurrenceStartDate,
      recurrenceEndDate: task.recurrenceEndDate,
      recurrenceCount: task.recurrenceCount,
      recurrenceParentId: task.recurrenceParentId,
      recurrenceConfiguration: task.recurrenceConfiguration,
      deletedDate: task.deletedDate,
    );
  }
}
