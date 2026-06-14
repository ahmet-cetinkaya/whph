import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

class GetListTaskStatusesQuery implements IRequest<GetListTaskStatusesQueryResponse> {
  final int pageIndex;
  final int pageSize;
  final bool includeDeleted;

  const GetListTaskStatusesQuery({
    this.pageIndex = 0,
    this.pageSize = 100,
    this.includeDeleted = false,
  });
}

class TaskStatusListItem {
  final String id;
  final String name;
  final String? color;
  final double order;
  final bool isBuiltIn;
  final bool isDoneStatus;

  TaskStatusListItem({
    required this.id,
    required this.name,
    this.color,
    required this.order,
    required this.isBuiltIn,
    required this.isDoneStatus,
  });
}

class GetListTaskStatusesQueryResponse extends PaginatedList<TaskStatusListItem> {
  GetListTaskStatusesQueryResponse({
    required super.items,
    required super.totalItemCount,
    required super.pageIndex,
    required super.pageSize,
  });
}

class GetListTaskStatusesQueryHandler
    implements IRequestHandler<GetListTaskStatusesQuery, GetListTaskStatusesQueryResponse> {
  final ITaskStatusRepository _taskStatusRepository;

  GetListTaskStatusesQueryHandler({required ITaskStatusRepository taskStatusRepository})
      : _taskStatusRepository = taskStatusRepository;

  @override
  Future<GetListTaskStatusesQueryResponse> call(GetListTaskStatusesQuery request) async {
    final result = await _taskStatusRepository.getList(
      request.pageIndex,
      request.pageSize,
      customOrder: [CustomOrder(field: 'order', direction: SortDirection.asc)],
    );

    // Merge: use DB values for builtin statuses if they exist, otherwise use defaults
    final mergedStatuses = <TaskStatusListItem>[];
    final existingIds = <String>{};

    for (final status in result.items.map((s) => TaskStatusListItem(
          id: s.id,
          name: s.name,
          color: s.color,
          order: s.order,
          isBuiltIn: s.isBuiltIn,
          isDoneStatus: s.isDoneStatus,
        ))) {
      if (!existingIds.contains(status.id)) {
        Logger.debug('GetList: Adding status ${status.id} with name "${status.name}" (isBuiltIn: ${status.isBuiltIn})');
        mergedStatuses.add(status);
        existingIds.add(status.id);
      }
    }

    // Ensure built-in statuses are present (use default values if not found in DB)
    _addBuiltinIfMissing(mergedStatuses, existingIds, TaskStatusConstants.todoId, TaskStatusConstants.todoColor,
        TaskStatusConstants.todoOrder);
    _addBuiltinIfMissing(mergedStatuses, existingIds, TaskStatusConstants.doneId, TaskStatusConstants.doneColor,
        TaskStatusConstants.doneOrder);

    return GetListTaskStatusesQueryResponse(
      items: mergedStatuses,
      totalItemCount: mergedStatuses.length,
      pageIndex: request.pageIndex,
      pageSize: request.pageSize,
    );
  }

  void _addBuiltinIfMissing(
    List<TaskStatusListItem> mergedStatuses,
    Set<String> existingIds,
    String id,
    String defaultColor,
    double defaultOrder,
  ) {
    if (existingIds.contains(id)) return;

    // Check if it's a builtin status
    final isDone = id == TaskStatusConstants.doneId;

    mergedStatuses.add(TaskStatusListItem(
      id: id,
      name: '',
      color: defaultColor,
      order: defaultOrder,
      isBuiltIn: true,
      isDoneStatus: isDone,
    ));
    existingIds.add(id);
  }
}
