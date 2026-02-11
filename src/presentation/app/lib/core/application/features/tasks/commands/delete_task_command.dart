import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';

class DeleteTaskCommand implements IRequest<DeleteTaskCommandResponse> {
  final String id;

  DeleteTaskCommand({required this.id});
}

class DeleteTaskCommandResponse {}

class DeleteTaskCommandHandler implements IRequestHandler<DeleteTaskCommand, DeleteTaskCommandResponse> {
  final ITaskRepository _taskRepository;
  final ITaskTagRepository _taskTagRepository;
  final ITaskTimeRecordRepository _taskTimeRecordRepository;

  DeleteTaskCommandHandler({
    required ITaskRepository taskRepository,
    required ITaskTagRepository taskTagRepository,
    required ITaskTimeRecordRepository taskTimeRecordRepository,
  })  : _taskRepository = taskRepository,
        _taskTagRepository = taskTagRepository,
        _taskTimeRecordRepository = taskTimeRecordRepository;

  @override
  Future<DeleteTaskCommandResponse> call(DeleteTaskCommand request) async {
    Task? task = await _taskRepository.getById(request.id);
    if (task == null) {
      throw BusinessException('Task not found', TaskTranslationKeys.taskNotFoundError);
    }

    // Cascade delete: Delete all related entities first
    await _deleteRelatedEntities(request.id);

    // Delete the task itself
    await _taskRepository.delete(task);

    return DeleteTaskCommandResponse();
  }

  /// Deletes all entities related to the task
  Future<void> _deleteRelatedEntities(String taskId) async {
    // Delete task tags
    final taskTags = await _taskTagRepository.getByTaskId(taskId);
    for (final taskTag in taskTags) {
      await _taskTagRepository.delete(taskTag);
    }

    // Delete task time records
    final taskTimeRecords = await _taskTimeRecordRepository.getByTaskId(taskId);
    for (final taskTimeRecord in taskTimeRecords) {
      await _taskTimeRecordRepository.delete(taskTimeRecord);
    }

    // Delete child tasks (subtasks)
    final childTasks = await _taskRepository.getByParentTaskId(taskId);
    for (final childTask in childTasks) {
      // Recursively delete child tasks and their related entities
      await _deleteRelatedEntities(childTask.id);
      await _taskRepository.delete(childTask);
    }

    // Delete recurring task instances
    final recurringInstances = await _taskRepository.getByRecurrenceParentId(taskId);
    for (final recurringInstance in recurringInstances) {
      // Recursively delete recurring instances and their related entities
      await _deleteRelatedEntities(recurringInstance.id);
      await _taskRepository.delete(recurringInstance);
    }
  }
}
