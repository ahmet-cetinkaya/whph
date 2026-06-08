import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task_status.dart';

class GetTaskStatusQuery implements IRequest<GetTaskStatusQueryResponse> {
  final String id;

  GetTaskStatusQuery({required this.id});
}

class GetTaskStatusQueryResponse extends TaskStatus {
  GetTaskStatusQueryResponse({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required super.name,
    super.color,
    super.order = 0.0,
    super.isBuiltIn = false,
    super.isDoneStatus = false,
  });
}

class GetTaskStatusQueryHandler implements IRequestHandler<GetTaskStatusQuery, GetTaskStatusQueryResponse> {
  final ITaskStatusRepository _taskStatusRepository;

  GetTaskStatusQueryHandler({required ITaskStatusRepository taskStatusRepository})
      : _taskStatusRepository = taskStatusRepository;

  @override
  Future<GetTaskStatusQueryResponse> call(GetTaskStatusQuery request) async {
    final status = await _taskStatusRepository.getById(request.id);
    if (status == null) {
      throw BusinessException('Task status not found', TaskTranslationKeys.taskStatusNotFoundError);
    }

    return GetTaskStatusQueryResponse(
      id: status.id,
      createdDate: status.createdDate,
      modifiedDate: status.modifiedDate,
      deletedDate: status.deletedDate,
      name: status.name,
      color: status.color,
      order: status.order,
      isBuiltIn: status.isBuiltIn,
      isDoneStatus: status.isDoneStatus,
    );
  }
}
