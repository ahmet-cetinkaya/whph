import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/tasks/task.dart';

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
      throw BusinessException('Task with id ${request.id} not found');
    }

    await _taskRepository.delete(task);

    return DeleteTaskCommandResponse();
  }
}
