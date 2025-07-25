import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/tasks/task_tag.dart';
import 'package:whph/src/core/application/features/tasks/constants/task_translation_keys.dart';

class AddTaskTagCommand implements IRequest<AddTaskTagCommandResponse> {
  String taskId;
  String tagId;

  AddTaskTagCommand({
    required this.taskId,
    required this.tagId,
  });
}

class AddTaskTagCommandResponse {
  final String id;

  AddTaskTagCommandResponse({
    required this.id,
  });
}

class AddTaskTagCommandHandler implements IRequestHandler<AddTaskTagCommand, AddTaskTagCommandResponse> {
  final ITaskTagRepository _taskTagRepository;

  AddTaskTagCommandHandler({required ITaskTagRepository taskTagRepository}) : _taskTagRepository = taskTagRepository;

  @override
  Future<AddTaskTagCommandResponse> call(AddTaskTagCommand request) async {
    if (await _taskTagRepository.anyByTaskIdAndTagId(request.taskId, request.tagId)) {
      throw BusinessException('Task tag already exists', TaskTranslationKeys.taskTagAlreadyExistsError);
    }

    final taskTag = TaskTag(
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now().toUtc(),
      taskId: request.taskId,
      tagId: request.tagId,
    );
    await _taskTagRepository.add(taskTag);

    return AddTaskTagCommandResponse(
      id: taskTag.id,
    );
  }
}
