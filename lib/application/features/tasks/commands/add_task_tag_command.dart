import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';

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
      throw Exception('Task tag already exists');
    }

    var taskTag = TaskTag(
      id: nanoid(),
      createdDate: DateTime(0),
      taskId: request.taskId,
      tagId: request.tagId,
    );
    await _taskTagRepository.add(taskTag);

    return AddTaskTagCommandResponse(
      id: taskTag.id,
    );
  }
}
