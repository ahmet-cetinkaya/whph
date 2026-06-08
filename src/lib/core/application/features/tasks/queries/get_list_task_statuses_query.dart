import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
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

    final items = result.items
        .map((status) => TaskStatusListItem(
              id: status.id,
              name: status.name,
              color: status.color,
              order: status.order,
              isBuiltIn: status.isBuiltIn,
              isDoneStatus: status.isDoneStatus,
            ))
        .toList();

    return GetListTaskStatusesQueryResponse(
      items: items,
      totalItemCount: result.totalItemCount,
      pageIndex: result.pageIndex,
      pageSize: result.pageSize,
    );
  }
}
