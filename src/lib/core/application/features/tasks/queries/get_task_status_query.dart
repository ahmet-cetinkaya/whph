import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:acore/acore.dart';

class GetTaskStatusQuery implements IRequest<GetTaskStatusQueryResponse> {
  final String id;

  GetTaskStatusQuery({required this.id});
}

class GetTaskStatusQueryResponse {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String name;
  final String? color;
  final double order;
  final bool isBuiltIn;
  final bool isDoneStatus;

  const GetTaskStatusQueryResponse({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
    this.deletedDate,
    required this.name,
    this.color,
    this.order = 0.0,
    this.isBuiltIn = false,
    this.isDoneStatus = false,
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
