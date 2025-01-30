import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';

class GetListTasksQuery implements IRequest<GetListTasksQueryResponse> {
  final int pageIndex;
  final int pageSize;
  final DateTime? filterByPlannedStartDate;
  final DateTime? filterByPlannedEndDate;
  final DateTime? filterByDeadlineStartDate;
  final DateTime? filterByDeadlineEndDate;
  final bool filterDateOr;
  final List<String>? filterByTags;
  final bool? filterByCompleted;
  final String? searchQuery;

  GetListTasksQuery({
    required this.pageIndex,
    required this.pageSize,
    this.filterByPlannedStartDate,
    this.filterByPlannedEndDate,
    this.filterByDeadlineStartDate,
    this.filterByDeadlineEndDate,
    this.filterDateOr = false,
    this.filterByTags,
    this.filterByCompleted,
    this.searchQuery,
  });
}

class TaskListItem {
  String id;
  String title;
  EisenhowerPriority? priority;
  DateTime? plannedDate;
  DateTime? deadlineDate;
  bool isCompleted;
  List<TagListItem> tags;
  int? estimatedTime;
  int totalElapsedTime = 0;

  TaskListItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    this.priority,
    this.plannedDate,
    this.deadlineDate,
    this.tags = const [],
    this.estimatedTime,
  });
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
  late final ITaskTagRepository _taskTagRepository;
  late final ITagRepository _tagRepository;

  GetListTasksQueryHandler(
      {required ITaskRepository taskRepository,
      required ITaskTagRepository taskTagRepository,
      required ITagRepository tagRepository})
      : _taskRepository = taskRepository,
        _taskTagRepository = taskTagRepository,
        _tagRepository = tagRepository;

  @override
  Future<GetListTasksQueryResponse> call(GetListTasksQuery request) async {
    PaginatedList<Task> tasks = await _taskRepository.getList(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: _getFilters(request),
      customOrder: [
        CustomOrder(field: "priority"),
        CustomOrder(field: "created_date", ascending: false),
      ],
    );

    List<TaskListItem> taskListItems = [];

    for (final task in tasks.items) {
      // Fetch tags for each task
      PaginatedList<TaskTag> taskTags =
          await _taskTagRepository.getList(0, 5, customWhereFilter: CustomWhereFilter("task_id = ?", [task.id]));

      final tagItems = await Future.wait(taskTags.items.map((tt) async {
        final tag = await _tagRepository.getById(tt.tagId);

        return TagListItem(
          id: tt.tagId,
          name: tag?.name ?? "",
          color: tag?.color,
        );
      }).toList());

      taskListItems.add(TaskListItem(
        id: task.id,
        title: task.title,
        isCompleted: task.isCompleted,
        priority: task.priority,
        plannedDate: task.plannedDate,
        deadlineDate: task.deadlineDate,
        tags: tagItems,
        estimatedTime: task.estimatedTime,
      ));
    }

    return GetListTasksQueryResponse(
      items: taskListItems,
      totalItemCount: tasks.totalItemCount,
      totalPageCount: tasks.totalPageCount,
      pageIndex: tasks.pageIndex,
      pageSize: tasks.pageSize,
    );
  }

  CustomWhereFilter? _getFilters(GetListTasksQuery request) {
    CustomWhereFilter? customWhereFilter;

    // Search filter
    if (request.searchQuery?.isNotEmpty ?? false) {
      customWhereFilter = CustomWhereFilter("title LIKE ?", ["%${request.searchQuery}%"]);
    }

    // Date filters
    if (request.filterDateOr) {
      customWhereFilter ??= CustomWhereFilter.empty();
      customWhereFilter.query += " (";
    }
    if (request.filterByPlannedStartDate != null || request.filterByPlannedEndDate != null) {
      customWhereFilter ??= CustomWhereFilter.empty();

      final plannedDateStart = request.filterByPlannedStartDate ?? DateTime(0);
      final plannedDateEnd = request.filterByPlannedEndDate ?? DateTime(9999);

      customWhereFilter.query += "(planned_date >= ? AND planned_date < ?)";

      customWhereFilter.variables.add(plannedDateStart);
      customWhereFilter.variables.add(plannedDateEnd);
    }

    if (request.filterByDeadlineStartDate != null || request.filterByDeadlineEndDate != null) {
      customWhereFilter ??= CustomWhereFilter.empty();

      final dueDateStart = request.filterByDeadlineStartDate ?? DateTime(0);
      final dueDateEnd = request.filterByDeadlineEndDate ?? DateTime(9999);

      if (customWhereFilter.query.isNotEmpty) customWhereFilter.query += request.filterDateOr ? " OR " : " AND ";
      customWhereFilter.query += "(deadline_date >= ? AND deadline_date < ?)";

      customWhereFilter.variables.add(dueDateStart);
      customWhereFilter.variables.add(dueDateEnd);
    }
    if (request.filterDateOr) {
      customWhereFilter!.query += " )";
    }

    // Tag filter
    if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
      customWhereFilter ??= CustomWhereFilter.empty();

      if (customWhereFilter.query.isNotEmpty) customWhereFilter.query += " AND ";
      customWhereFilter.query +=
          "(SELECT COUNT(*) FROM task_tag_table WHERE task_tag_table.task_id = task_table.id AND task_tag_table.tag_id IN (${request.filterByTags!.map((tag) => '?').join(',')}) AND task_tag_table.deleted_date IS NULL) > 0";
      customWhereFilter.variables.addAll(request.filterByTags!);
    }

    // Completed filter
    if (request.filterByCompleted != null) {
      customWhereFilter ??= CustomWhereFilter.empty();

      if (customWhereFilter.query.isNotEmpty) customWhereFilter.query += " AND ";
      customWhereFilter.query += "(is_completed = ?)";
      customWhereFilter.variables.add(request.filterByCompleted! ? 1 : 0);
    }

    return customWhereFilter;
  }
}
