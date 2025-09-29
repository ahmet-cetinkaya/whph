import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/shared/utils/logger.dart';

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

  final DateTime? filterByCompletedStartDate;
  final DateTime? filterByCompletedEndDate;

  final List<String>? filterByTags;
  final bool filterNoTags;

  final bool? filterByCompleted;

  final String? filterBySearch;

  final String? filterByParentTaskId;
  final bool areParentAndSubTasksIncluded;

  final List<SortOption<TaskSortFields>>? sortBy;
  final bool sortByCustomSort;
  final bool ignoreArchivedTagVisibility;

  GetListTasksQuery({
    required this.pageIndex,
    required this.pageSize,
    DateTime? filterByPlannedStartDate,
    DateTime? filterByPlannedEndDate,
    DateTime? filterByDeadlineStartDate,
    DateTime? filterByDeadlineEndDate,
    this.filterDateOr = false,
    DateTime? filterByCompletedStartDate,
    DateTime? filterByCompletedEndDate,
    this.filterByTags,
    this.filterNoTags = false,
    this.filterByCompleted,
    this.filterBySearch,
    this.filterByParentTaskId,
    this.areParentAndSubTasksIncluded = false,
    this.sortBy,
    this.sortByCustomSort = false,
    this.ignoreArchivedTagVisibility = false,
  })  : filterByPlannedStartDate =
            filterByPlannedStartDate != null ? DateTimeHelper.toUtcDateTime(filterByPlannedStartDate) : null,
        filterByPlannedEndDate =
            filterByPlannedEndDate != null ? DateTimeHelper.toUtcDateTime(filterByPlannedEndDate) : null,
        filterByDeadlineStartDate =
            filterByDeadlineStartDate != null ? DateTimeHelper.toUtcDateTime(filterByDeadlineStartDate) : null,
        filterByDeadlineEndDate =
            filterByDeadlineEndDate != null ? DateTimeHelper.toUtcDateTime(filterByDeadlineEndDate) : null,
        filterByCompletedStartDate =
            filterByCompletedStartDate != null ? DateTimeHelper.toUtcDateTime(filterByCompletedStartDate) : null,
        filterByCompletedEndDate =
            filterByCompletedEndDate != null ? DateTimeHelper.toUtcDateTime(filterByCompletedEndDate) : null;

  /// Factory constructor for search queries that includes subtasks
  factory GetListTasksQuery.forSearch({
    required int pageIndex,
    required int pageSize,
    DateTime? filterByPlannedStartDate,
    DateTime? filterByPlannedEndDate,
    DateTime? filterByDeadlineStartDate,
    DateTime? filterByDeadlineEndDate,
    bool filterDateOr = false,
    DateTime? filterByCompletedStartDate,
    DateTime? filterByCompletedEndDate,
    List<String>? filterByTags,
    bool filterNoTags = false,
    bool? filterByCompleted,
    String? filterBySearch,
    List<SortOption<TaskSortFields>>? sortBy,
    bool sortByCustomSort = false,
    bool ignoreArchivedTagVisibility = false,
  }) {
    return GetListTasksQuery(
      pageIndex: pageIndex,
      pageSize: pageSize,
      filterByPlannedStartDate: filterByPlannedStartDate,
      filterByPlannedEndDate: filterByPlannedEndDate,
      filterByDeadlineStartDate: filterByDeadlineStartDate,
      filterByDeadlineEndDate: filterByDeadlineEndDate,
      filterDateOr: filterDateOr,
      filterByCompletedStartDate: filterByCompletedStartDate,
      filterByCompletedEndDate: filterByCompletedEndDate,
      filterByTags: filterByTags,
      filterNoTags: filterNoTags,
      filterByCompleted: filterByCompleted,
      filterBySearch: filterBySearch,
      sortBy: sortBy,
      sortByCustomSort: sortByCustomSort,
      ignoreArchivedTagVisibility: ignoreArchivedTagVisibility,
      areParentAndSubTasksIncluded: true,
      filterByParentTaskId: null,
    );
  }
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
    final tasks = await _taskRepository.getListWithOptions(
      pageIndex: request.pageIndex,
      pageSize: request.pageSize,
      filterByTags: request.filterByTags,
      filterNoTags: request.filterNoTags,
      filterByPlannedStartDate: request.filterByPlannedStartDate,
      filterByPlannedEndDate: request.filterByPlannedEndDate,
      filterByDeadlineStartDate: request.filterByDeadlineStartDate,
      filterByDeadlineEndDate: request.filterByDeadlineEndDate,
      filterDateOr: request.filterDateOr,
      filterByCompleted: request.filterByCompleted,
      filterByCompletedStartDate: request.filterByCompletedStartDate,
      filterByCompletedEndDate: request.filterByCompletedEndDate,
      filterBySearch: request.filterBySearch,
      filterByParentTaskId: request.filterByParentTaskId,
      areParentAndSubTasksIncluded: request.areParentAndSubTasksIncluded,
      sortBy: _getCustomOrders(request),
      sortByCustomSort: request.sortByCustomSort,
      ignoreArchivedTagVisibility: request.ignoreArchivedTagVisibility,
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
        try {
          final tag = await _tagRepository.getById(tt.tagId);

          return TagListItem(
            id: tt.tagId,
            name: tag?.name ?? "Unknown Tag",
            color: tag?.color,
          );
        } catch (e) {
          Logger.error('Failed to fetch tag ${tt.tagId} for task ${task.id}: $e');
          return TagListItem(
            id: tt.tagId,
            name: "Error Loading Tag",
            color: null,
          );
        }
      }).toList());

      final subTasks = await _taskRepository.getAll(
        customWhereFilter: CustomWhereFilter("parent_task_id = ?", [task.id]),
      );

      double subTasksCompletionPercentage = 0;
      if (subTasks.isNotEmpty) {
        final completedSubTasks = subTasks.where((subTask) => subTask.isCompleted).length;
        subTasksCompletionPercentage = (completedSubTasks / subTasks.length) * 100;
      }

      // Convert subtasks to TaskListItem
      final subTaskListItems = subTasks
          .map((subTask) => TaskListItem(
                id: subTask.id,
                title: subTask.title,
                isCompleted: subTask.isCompleted,
                priority: subTask.priority,
                plannedDate: subTask.plannedDate,
                deadlineDate: subTask.deadlineDate,
                estimatedTime: subTask.estimatedTime,
                parentTaskId: subTask.parentTaskId,
                order: subTask.order,
                plannedDateReminderTime: subTask.plannedDateReminderTime,
                deadlineDateReminderTime: subTask.deadlineDateReminderTime,
              ))
          .toList();

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
        subTasks: subTaskListItems,
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

  List<CustomOrder> _getCustomOrders(GetListTasksQuery request) {
    if (request.sortByCustomSort) {
      return [CustomOrder(field: "order", direction: SortDirection.asc)];
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
