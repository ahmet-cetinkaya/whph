import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';

class DeleteTaskStatusCommand implements IRequest<DeleteTaskStatusCommandResponse> {
  final String id;

  DeleteTaskStatusCommand({required this.id});
}

class DeleteTaskStatusCommandResponse {}

class DeleteTaskStatusCommandHandler
    implements IRequestHandler<DeleteTaskStatusCommand, DeleteTaskStatusCommandResponse> {
  final ITaskStatusRepository _taskStatusRepository;
  final ITaskRepository _taskRepository;

  DeleteTaskStatusCommandHandler({
    required ITaskStatusRepository taskStatusRepository,
    required ITaskRepository taskRepository,
  })  : _taskStatusRepository = taskStatusRepository,
        _taskRepository = taskRepository;

  @override
  Future<DeleteTaskStatusCommandResponse> call(DeleteTaskStatusCommand request) async {
    final status = await _taskStatusRepository.getById(request.id);
    if (status == null) {
      throw BusinessException('Task status not found', TaskTranslationKeys.taskStatusNotFoundError);
    }

    if (status.isBuiltIn) {
      throw BusinessException('Cannot delete built-in status', TaskTranslationKeys.taskStatusBuiltInError);
    }

    final affectedTasks = await _taskRepository.getAll(
      customWhereFilter: CustomWhereFilter('status_id = ? AND deleted_date IS NULL', [request.id]),
    );
    for (final task in affectedTasks) {
      task.statusId = TaskStatusConstants.todoId;
      await _taskRepository.update(task);
    }

    await _taskStatusRepository.delete(status);

    return DeleteTaskStatusCommandResponse();
  }
}
