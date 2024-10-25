import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tasks/task.dart';

class GetListTasksQuery implements IRequest<GetListTasksQueryResponse> {
  late int pageIndex;
  late int pageSize;
  DateTime? filterByPlannedDate;
  DateTime? filterByDeadlineDate;
  List<String>? filterByTags;

  GetListTasksQuery(
      {required this.pageIndex,
      required this.pageSize,
      this.filterByPlannedDate,
      this.filterByDeadlineDate,
      this.filterByTags});
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
    PaginatedList<Task> tasks = await _taskRepository.getList(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: _getFilters(request),
    );

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

    if (request.filterByPlannedDate != null) {
      customWhereFilter = CustomWhereFilter("", []);

      var plannedDateStart = request.filterByPlannedDate!;
      var plannedDateEnd = request.filterByPlannedDate!.add(Duration(days: 1));

      customWhereFilter.query += "planned_date > ? AND planned_date < ?";

      customWhereFilter.variables.add(plannedDateStart);
      customWhereFilter.variables.add(plannedDateEnd);
    }

    if (request.filterByDeadlineDate != null) {
      customWhereFilter ??= CustomWhereFilter("", []);

      var dueDateStart = request.filterByDeadlineDate!;
      var dueDateEnd = request.filterByDeadlineDate!.add(Duration(days: 1));

      if (customWhereFilter.query.isNotEmpty) customWhereFilter.query += " OR ";
      customWhereFilter.query += "deadline_date > ? AND deadline_date < ?";

      customWhereFilter.variables.add(dueDateStart);
      customWhereFilter.variables.add(dueDateEnd);
    }

    if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
      customWhereFilter ??= CustomWhereFilter("", []);

      if (customWhereFilter.query.isNotEmpty) customWhereFilter.query += " OR ";
      customWhereFilter.query +=
          "(SELECT COUNT(*) FROM task_tag_table WHERE task_tag_table.task_id = task_table.id AND task_tag_table.tag_id IN (${request.filterByTags!.map((tag) => "'$tag'").toList().join(',')})) > 0";
    }

    return customWhereFilter;
  }
}
