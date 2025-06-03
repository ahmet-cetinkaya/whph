import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/corePackages/acore/repository/models/custom_order.dart';
import 'package:whph/corePackages/acore/repository/models/custom_where_filter.dart';
import 'package:whph/corePackages/acore/repository/models/paginated_list.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/core/domain/features/tasks/task_tag.dart';
import 'package:whph/corePackages/acore/time/date_time_helper.dart';
import 'package:whph/corePackages/acore/queries/models/sort_option.dart';

enum TaskSortFields {
  createdDate,
  deadlineDate,
  totalDuration,
  estimatedTime,
  modifiedDate,
  plannedDate,
  priority,
  title,
}

class GetListTasksQuery implements IRequest<GetListTasksQueryResponse> {
  final int pageIndex;
  final int pageSize;

  final DateTime? filterByPlannedStartDate;
  final DateTime? filterByPlannedEndDate;
  final DateTime? filterByDeadlineStartDate;
  final DateTime? filterByDeadlineEndDate;
  final bool filterDateOr;

  final List<String>? filterByTags;
  final bool filterNoTags;

  final bool? filterByCompleted;

  final String? filterBySearch;

  final String? filterByParentTaskId;
  final bool areParentAndSubTasksIncluded;

  final List<SortOption<TaskSortFields>>? sortBy;
  final bool sortByCustomSort;

  GetListTasksQuery({
    required this.pageIndex,
    required this.pageSize,
    DateTime? filterByPlannedStartDate,
    DateTime? filterByPlannedEndDate,
    DateTime? filterByDeadlineStartDate,
    DateTime? filterByDeadlineEndDate,
    this.filterDateOr = false,
    this.filterByTags,
    this.filterNoTags = false,
    this.filterByCompleted,
    this.filterBySearch,
    this.filterByParentTaskId,
    this.areParentAndSubTasksIncluded = false,
    this.sortBy,
    this.sortByCustomSort = false,
  })  : filterByPlannedStartDate =
            filterByPlannedStartDate != null ? DateTimeHelper.toUtcDateTime(filterByPlannedStartDate) : null,
        filterByPlannedEndDate =
            filterByPlannedEndDate != null ? DateTimeHelper.toUtcDateTime(filterByPlannedEndDate) : null,
        filterByDeadlineStartDate =
            filterByDeadlineStartDate != null ? DateTimeHelper.toUtcDateTime(filterByDeadlineStartDate) : null,
        filterByDeadlineEndDate =
            filterByDeadlineEndDate != null ? DateTimeHelper.toUtcDateTime(filterByDeadlineEndDate) : null;
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
  String? parentTaskId;
  double order = 0;

  // Reminder properties
  ReminderTime plannedDateReminderTime = ReminderTime.none;
  ReminderTime deadlineDateReminderTime = ReminderTime.none;

  double subTasksCompletionPercentage = 0;
  List<TaskListItem> subTasks;

  TaskListItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    this.priority,
    this.plannedDate,
    this.deadlineDate,
    this.tags = const [],
    this.estimatedTime,
    this.parentTaskId,
    this.subTasksCompletionPercentage = 0,
    this.order = 0,
    this.subTasks = const [],
    this.totalElapsedTime = 0,
    this.plannedDateReminderTime = ReminderTime.none,
    this.deadlineDateReminderTime = ReminderTime.none,
  });

  TaskListItem copyWith({
    String? id,
    String? title,
    EisenhowerPriority? priority,
    DateTime? plannedDate,
    DateTime? deadlineDate,
    bool? isCompleted,
    List<TagListItem>? tags,
    int? estimatedTime,
    int? totalElapsedTime,
    String? parentTaskId,
    double? subTasksCompletionPercentage,
    List<TaskListItem>? subTasks,
    ReminderTime? plannedDateReminderTime,
    ReminderTime? deadlineDateReminderTime,
  }) {
    return TaskListItem(
      id: id ?? this.id,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      plannedDate: plannedDate ?? this.plannedDate,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      isCompleted: isCompleted ?? this.isCompleted,
      tags: tags ?? this.tags,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      totalElapsedTime: totalElapsedTime ?? this.totalElapsedTime,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      subTasksCompletionPercentage: subTasksCompletionPercentage ?? this.subTasksCompletionPercentage,
      subTasks: subTasks ?? this.subTasks,
      plannedDateReminderTime: plannedDateReminderTime ?? this.plannedDateReminderTime,
      deadlineDateReminderTime: deadlineDateReminderTime ?? this.deadlineDateReminderTime,
    );
  }
}

class GetListTasksQueryResponse extends PaginatedList<TaskListItem> {
  GetListTasksQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
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
    final tasks = await _taskRepository.getListWithTotalDuration(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: _getFilters(request),
      customOrder: _getCustomOrders(request),
    );

    // Fixing task orders with order value 0
    var needsReorder = tasks.items.any((task) => task.order == 0);
    if (needsReorder) {
      const int orderStep = 1000;
      var orderCounter = orderStep;

      for (var task in tasks.items) {
        if (task.order == 0) {
          task.order = orderCounter.toDouble();
          task.modifiedDate = DateTime.now().toUtc();
          await _taskRepository.update(task);
          orderCounter += orderStep;
        }
      }
    }

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

      final subTasks = await _taskRepository.getAll(
        customWhereFilter: CustomWhereFilter("parent_task_id = ?", [task.id]),
      );

      double subTasksCompletionPercentage = 0;
      if (subTasks.isNotEmpty) {
        final completedSubTasks = subTasks.where((subTask) => subTask.isCompleted).length;
        subTasksCompletionPercentage = (completedSubTasks / subTasks.length) * 100;
      }

      taskListItems.add(TaskListItem(
        id: task.id,
        title: task.title,
        isCompleted: task.isCompleted,
        priority: task.priority,
        plannedDate: task.plannedDate,
        deadlineDate: task.deadlineDate,
        tags: tagItems,
        estimatedTime: task.estimatedTime,
        totalElapsedTime: task.totalDuration,
        parentTaskId: task.parentTaskId,
        order: task.order,
        subTasksCompletionPercentage: subTasksCompletionPercentage,
        plannedDateReminderTime: task.plannedDateReminderTime,
        deadlineDateReminderTime: task.deadlineDateReminderTime,
      ));
    }

    return GetListTasksQueryResponse(
      items: taskListItems,
      totalItemCount: tasks.totalItemCount,
      pageIndex: request.pageIndex,
      pageSize: request.pageSize,
    );
  }

  CustomWhereFilter? _getFilters(GetListTasksQuery request) {
    final conditions = <String>[];
    final variables = <Object>[];

    // Search
    if (request.filterBySearch?.isNotEmpty ?? false) {
      conditions.add('title LIKE ?');
      variables.add('%${request.filterBySearch}%');
    }

    // Date filters
    final plannedFilters = <String>[];
    if (request.filterByPlannedStartDate != null || request.filterByPlannedEndDate != null) {
      plannedFilters.add('planned_date >= ? AND planned_date <= ?');
      variables.add(request.filterByPlannedStartDate ?? DateTime(0));
      variables.add(request.filterByPlannedEndDate ?? DateTime(9999));
    }
    final deadlineFilters = <String>[];
    if (request.filterByDeadlineStartDate != null || request.filterByDeadlineEndDate != null) {
      deadlineFilters.add('deadline_date >= ? AND deadline_date <= ?');
      variables.add(request.filterByDeadlineStartDate ?? DateTime(0));
      variables.add(request.filterByDeadlineEndDate ?? DateTime(9999));
    }
    if (plannedFilters.isNotEmpty || deadlineFilters.isNotEmpty) {
      final joiner = request.filterDateOr ? ' OR ' : ' AND ';
      final dateBlock = <String>[...plannedFilters, ...deadlineFilters];
      conditions.add('(${dateBlock.join(joiner)})');
    }

    // Tag filter
    if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
      final placeholders = List.filled(request.filterByTags!.length, '?').join(',');
      conditions.add(
          '(SELECT COUNT(*) FROM task_tag_table WHERE task_id = task_table.id AND tag_id IN ($placeholders) AND deleted_date IS NULL) > 0');
      variables.addAll(request.filterByTags!);
    }

    // No tags filter
    if (request.filterNoTags) {
      conditions
          .add('(SELECT COUNT(*) FROM task_tag_table WHERE task_id = task_table.id AND deleted_date IS NULL) = 0');
    }

    // Completed filter
    if (request.filterByCompleted != null) {
      conditions.add('is_completed = ?');
      variables.add(request.filterByCompleted! ? 1 : 0);
    }

    // Parent task filter
    if (!request.areParentAndSubTasksIncluded) {
      if (request.filterByParentTaskId != null) {
        conditions.add('parent_task_id = ?');
        variables.add(request.filterByParentTaskId!);
      } else {
        conditions.add('parent_task_id IS NULL');
      }
    }

    if (conditions.isEmpty) return null;
    return CustomWhereFilter(conditions.join(' AND '), variables);
  }

  List<CustomOrder> _getCustomOrders(GetListTasksQuery request) {
    if (request.sortByCustomSort) {
      return [CustomOrder(field: "order")];
    }

    // Ensure sortBy is not null before iterating
    final sortOptions = request.sortBy ?? [];

    List<CustomOrder> customOrders = [];
    for (var option in sortOptions) {
      if (option.field == TaskSortFields.createdDate) {
        customOrders.add(CustomOrder(field: "created_date", direction: option.direction));
      } else if (option.field == TaskSortFields.deadlineDate) {
        customOrders.add(CustomOrder(field: "deadline_date", direction: option.direction));
      } else if (option.field == TaskSortFields.totalDuration) {
        customOrders.add(CustomOrder(field: "total_duration", direction: option.direction));
      } else if (option.field == TaskSortFields.estimatedTime) {
        customOrders.add(CustomOrder(field: "estimated_time", direction: option.direction));
      } else if (option.field == TaskSortFields.modifiedDate) {
        customOrders.add(CustomOrder(field: "modified_date", direction: option.direction));
      } else if (option.field == TaskSortFields.plannedDate) {
        customOrders.add(CustomOrder(field: "planned_date", direction: option.direction));
      } else if (option.field == TaskSortFields.priority) {
        customOrders.add(CustomOrder(field: "priority", direction: option.direction));
      } else if (option.field == TaskSortFields.title) {
        customOrders.add(CustomOrder(field: "title", direction: option.direction));
      }
    }
    return customOrders;
  }
}
