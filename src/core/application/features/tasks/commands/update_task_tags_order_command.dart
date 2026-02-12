import 'package:mediatr/mediatr.dart';
import 'package:application/features/tasks/services/abstraction/i_task_tag_repository.dart';

class UpdateTaskTagsOrderCommand implements IRequest<void> {
  final String taskId;
  final Map<String, int> tagOrders;

  UpdateTaskTagsOrderCommand({
    required this.taskId,
    required this.tagOrders,
  });
}

class UpdateTaskTagsOrderCommandHandler implements IRequestHandler<UpdateTaskTagsOrderCommand, void> {
  final ITaskTagRepository _taskTagRepository;

  UpdateTaskTagsOrderCommandHandler({required ITaskTagRepository taskTagRepository})
      : _taskTagRepository = taskTagRepository;

  @override
  Future<void> call(UpdateTaskTagsOrderCommand request) async {
    await _taskTagRepository.updateTagOrders(request.taskId, request.tagOrders);
  }
}
