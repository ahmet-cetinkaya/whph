import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/core/application/features/tasks/constants/task_translation_keys.dart';

class DeleteTaskCommand implements IRequest<DeleteTaskCommandResponse> {
  final String id;

  DeleteTaskCommand({required this.id});
}

class DeleteTaskCommandResponse {}

class DeleteTaskCommandHandler implements IRequestHandler<DeleteTaskCommand, DeleteTaskCommandResponse> {
  final ITaskRepository _taskRepository;

  DeleteTaskCommandHandler({required ITaskRepository taskRepository}) : _taskRepository = taskRepository;

  @override
  Future<DeleteTaskCommandResponse> call(DeleteTaskCommand request) async {
    Task? task = await _taskRepository.getById(request.id);
    if (task == null) {
      throw BusinessException('Task not found', TaskTranslationKeys.taskNotFoundError);
    }

    await _taskRepository.delete(task);

    return DeleteTaskCommandResponse();
  }
}
