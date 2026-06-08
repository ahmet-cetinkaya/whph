import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:acore/acore.dart';

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
      customOrder: [CustomOrder(field: 'sort_order', direction: SortDirection.asc)],
    );

    // Ensure built-in statuses are always present in the response
    final builtInStatuses = [
      TaskStatusListItem(
        id: TaskStatusConstants.todoId,
        name: '',
        color: TaskStatusConstants.todoColor,
        order: TaskStatusConstants.todoOrder,
        isBuiltIn: true,
        isDoneStatus: false,
      ),
      TaskStatusListItem(
        id: TaskStatusConstants.doneId,
        name: '',
        color: TaskStatusConstants.doneColor,
        order: TaskStatusConstants.doneOrder,
        isBuiltIn: true,
        isDoneStatus: true,
      ),
    ];

    // Merge: built-ins first (in order), then custom statuses not already present
    final mergedStatuses = <TaskStatusListItem>[];
    final existingIds = <String>{};

    for (final status in [
      ...builtInStatuses,
      ...result.items.map((s) => TaskStatusListItem(
            id: s.id,
            name: s.name,
            color: s.color,
            order: s.order,
            isBuiltIn: s.isBuiltIn,
            isDoneStatus: s.isDoneStatus,
          ))
    ]) {
      if (!existingIds.contains(status.id)) {
        mergedStatuses.add(status);
        existingIds.add(status.id);
      }
    }

    return GetListTaskStatusesQueryResponse(
      items: mergedStatuses,
      totalItemCount: mergedStatuses.length,
      pageIndex: request.pageIndex,
      pageSize: request.pageSize,
    );
  }
}
