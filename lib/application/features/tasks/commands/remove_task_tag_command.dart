import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';

class RemoveTaskTagCommand implements IRequest<RemoveTaskTagCommandResponse> {
  String id;

  RemoveTaskTagCommand({
    required this.id,
  });
}

class RemoveTaskTagCommandResponse {
  final String id;

  RemoveTaskTagCommandResponse({
    required this.id,
  });
}

class RemoveTaskTagCommandHandler implements IRequestHandler<RemoveTaskTagCommand, RemoveTaskTagCommandResponse> {
  final ITaskTagRepository _taskTagRepository;

  RemoveTaskTagCommandHandler({required ITaskTagRepository taskTagRepository}) : _taskTagRepository = taskTagRepository;

  @override
  Future<RemoveTaskTagCommandResponse> call(RemoveTaskTagCommand request) async {
    TaskTag? taskTag = await _taskTagRepository.getById(request.id);
    if (taskTag == null) {
      throw BusinessException('TaskTag with id ${request.id} not found');
    }
    if (taskTag.deletedDate != null) {
      throw BusinessException('TaskTag with id ${request.id} is already deleted');
    }
    await _taskTagRepository.delete(taskTag);

    return RemoveTaskTagCommandResponse(
      id: taskTag.id,
    );
  }
}
