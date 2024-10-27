import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tasks/task.dart';

class GetListTasksQuery implements IRequest<GetListTasksQueryResponse> {
  final int pageIndex;
  final int pageSize;
  final DateTime? filterByPlannedStartDate;
  final DateTime? filterByPlannedEndDate;
  final DateTime? filterByDeadlineStartDate;
  final DateTime? filterByDeadlineEndDate;
  final List<String>? filterByTags;
  final bool? filterByCompleted;

  GetListTasksQuery(
      {required this.pageIndex,
      required this.pageSize,
      this.filterByPlannedStartDate,
      this.filterByPlannedEndDate,
      this.filterByDeadlineStartDate,
      this.filterByDeadlineEndDate,
      this.filterByTags,
      this.filterByCompleted});
}

class TaskListItem {
  String id;
  String title;
  EisenhowerPriority? priority;
  DateTime? plannedDate;
  DateTime? deadlineDate;
  bool isCompleted;

  TaskListItem(
      {required this.id,
      required this.title,
      required this.isCompleted,
      this.priority,
      this.plannedDate,
      this.deadlineDate});
}

class GetListTasksQueryResponse extends PaginatedList<TaskListItem> {
  GetListTasksQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
}

class GetListTasksQueryHandler implements IRequestHandler<GetListTasksQuery, GetListTasksQueryResponse> {
  late final ITaskRepository _taskRepository;

  GetListTasksQueryHandler({required ITaskRepository taskRepository}) : _taskRepository = taskRepository;

  @override
  Future<GetListTasksQueryResponse> call(GetListTasksQuery request) async {
    PaginatedList<Task> tasks = await _taskRepository.getList(request.pageIndex, request.pageSize,
        customWhereFilter: _getFilters(request), customOrder: [CustomOrder(field: "created_date", ascending: false)]);

    return GetListTasksQueryResponse(
      items: tasks.items
          .map((e) => TaskListItem(
              id: e.id,
              title: e.title,
              isCompleted: e.isCompleted,
              priority: e.priority,
              plannedDate: e.plannedDate,
              deadlineDate: e.deadlineDate))
          .toList(),
      totalItemCount: tasks.totalItemCount,
      totalPageCount: tasks.totalPageCount,
      pageIndex: tasks.pageIndex,
      pageSize: tasks.pageSize,
    );
  }

  CustomWhereFilter? _getFilters(GetListTasksQuery request) {
    CustomWhereFilter? customWhereFilter;

    if (request.filterByPlannedStartDate != null || request.filterByPlannedEndDate != null) {
      customWhereFilter = CustomWhereFilter.empty();

      var plannedDateStart = request.filterByPlannedStartDate ?? DateTime(0);
      var plannedDateEnd = request.filterByPlannedEndDate ?? DateTime(9999);

      customWhereFilter.query += "planned_date > ? AND planned_date < ?";

      customWhereFilter.variables.add(plannedDateStart);
      customWhereFilter.variables.add(plannedDateEnd);
    }

    if (request.filterByDeadlineStartDate != null || request.filterByDeadlineEndDate != null) {
      customWhereFilter ??= CustomWhereFilter.empty();

      var dueDateStart = request.filterByDeadlineStartDate ?? DateTime(0);
      var dueDateEnd = request.filterByDeadlineEndDate ?? DateTime(9999);

      if (customWhereFilter.query.isNotEmpty) customWhereFilter.query += " AND ";
      customWhereFilter.query += "deadline_date > ? AND deadline_date < ?";

      customWhereFilter.variables.add(dueDateStart);
      customWhereFilter.variables.add(dueDateEnd);
    }

    if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
      customWhereFilter ??= CustomWhereFilter.empty();

      if (customWhereFilter.query.isNotEmpty) customWhereFilter.query += " AND ";
      customWhereFilter.query +=
          "(SELECT COUNT(*) FROM task_tag_table WHERE task_tag_table.task_id = task_table.id AND task_tag_table.tag_id IN (${request.filterByTags!.map((tag) => '?').join(',')}) AND task_tag_table.deleted_date IS NULL) > 0";
      customWhereFilter.variables.addAll(request.filterByTags!);
    }

    if (request.filterByCompleted != null) {
      customWhereFilter ??= CustomWhereFilter.empty();

      if (customWhereFilter.query.isNotEmpty) customWhereFilter.query += " AND ";
      customWhereFilter.query += "is_completed = ?";
      customWhereFilter.variables.add(request.filterByCompleted!);
    }

    return customWhereFilter;
  }
}
