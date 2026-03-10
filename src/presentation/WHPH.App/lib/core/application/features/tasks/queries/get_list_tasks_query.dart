import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/models/task_query_filter.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/utils/task_grouping_helper.dart';
import 'package:acore/acore.dart';

import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';

class GetListTasksQuery implements IRequest<GetListTasksQueryResponse> {
  final int pageIndex;
  final int pageSize;

  final DateTime? filterByPlannedStartDate;
  final DateTime? filterByPlannedEndDate;
  final DateTime? filterByDeadlineStartDate;
  final DateTime? filterByDeadlineEndDate;
  final bool filterDateOr;
  final bool includeNullDates;

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
  final bool enableGrouping;
  final SortOption<TaskSortFields>? groupBy;
  final List<String>? customTagSortOrder;

  GetListTasksQuery({
    required this.pageIndex,
    required this.pageSize,
    DateTime? filterByPlannedStartDate,
    DateTime? filterByPlannedEndDate,
    DateTime? filterByDeadlineStartDate,
    DateTime? filterByDeadlineEndDate,
    this.filterDateOr = false,
    this.includeNullDates = false,
    DateTime? filterByCompletedStartDate,
    DateTime? filterByCompletedEndDate,
    this.filterByTags,
    this.filterNoTags = false,
    this.filterByCompleted,
    this.filterBySearch,
    this.filterByParentTaskId,
    this.areParentAndSubTasksIncluded = false,
    this.sortBy,
    this.groupBy,
    this.sortByCustomSort = false,
    this.ignoreArchivedTagVisibility = false,
    this.enableGrouping = true,
    this.customTagSortOrder,
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
    bool includeNullDates = false,
    DateTime? filterByCompletedStartDate,
    DateTime? filterByCompletedEndDate,
    List<String>? filterByTags,
    bool filterNoTags = false,
    bool? filterByCompleted,
    String? filterBySearch,
    List<SortOption<TaskSortFields>>? sortBy,
    bool sortByCustomSort = false,
    bool ignoreArchivedTagVisibility = false,
    bool enableGrouping = true,
    SortOption<TaskSortFields>? groupBy,
    List<String>? customTagSortOrder,
  }) {
    return GetListTasksQuery(
      pageIndex: pageIndex,
      pageSize: pageSize,
      filterByPlannedStartDate: filterByPlannedStartDate,
      filterByPlannedEndDate: filterByPlannedEndDate,
      filterByDeadlineStartDate: filterByDeadlineStartDate,
      filterByDeadlineEndDate: filterByDeadlineEndDate,
      filterDateOr: filterDateOr,
      includeNullDates: includeNullDates,
      filterByCompletedStartDate: filterByCompletedStartDate,
      filterByCompletedEndDate: filterByCompletedEndDate,
      filterByTags: filterByTags,
      filterNoTags: filterNoTags,
      filterByCompleted: filterByCompleted,
      filterBySearch: filterBySearch,
      sortBy: sortBy,
      groupBy: groupBy,
      sortByCustomSort: sortByCustomSort,
      ignoreArchivedTagVisibility: ignoreArchivedTagVisibility,
      enableGrouping: enableGrouping,
      areParentAndSubTasksIncluded: true,
      filterByParentTaskId: null,
      customTagSortOrder: customTagSortOrder,
    );
  }
}

class GetListTasksQueryResponse extends PaginatedList<TaskListItem> {
  GetListTasksQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
}

class GetListTasksQueryHandler implements IRequestHandler<GetListTasksQuery, GetListTasksQueryResponse> {
  late final ITaskRepository _taskRepository;

  GetListTasksQueryHandler({required ITaskRepository taskRepository}) : _taskRepository = taskRepository;

  @override
  Future<GetListTasksQueryResponse> call(GetListTasksQuery request) async {
    final tasks = await _taskRepository.getListWithDetails(
      pageIndex: request.pageIndex,
      pageSize: request.pageSize,
      filter: TaskQueryFilter(
        tags: request.filterByTags,
        noTags: request.filterNoTags,
        plannedStartDate: request.filterByPlannedStartDate,
        plannedEndDate: request.filterByPlannedEndDate,
        deadlineStartDate: request.filterByDeadlineStartDate,
        deadlineEndDate: request.filterByDeadlineEndDate,
        dateOr: request.filterDateOr,
        includeNullDates: request.includeNullDates,
        completed: request.filterByCompleted,
        completedStartDate: request.filterByCompletedStartDate,
        completedEndDate: request.filterByCompletedEndDate,
        search: request.filterBySearch,
        parentTaskId: request.filterByParentTaskId,
        includeParentAndSubTasks: request.areParentAndSubTasksIncluded,
        sortBy: _getCustomOrders(request),
        sortByCustomSort: request.sortByCustomSort,
        ignoreArchivedTagVisibility: request.ignoreArchivedTagVisibility,
        enableGrouping: request.enableGrouping,
        customTagSortOrder: request.customTagSortOrder,
      ),
    );

    // Determine if group names should be translated based on sort field
    final groupField = request.enableGrouping
        ? request.groupBy ?? (request.sortBy?.isNotEmpty == true ? request.sortBy!.first : null)
        : null;
    final isGroupTranslatable = TaskGroupingHelper.isGroupTranslatable(groupField?.field);

    // Set isGroupNameTranslatable on each task
    final itemsWithTranslatableFlag = tasks.items.map((task) {
      if (task.groupName != null && isGroupTranslatable) {
        return task.copyWith(isGroupNameTranslatable: true);
      }
      return task;
    }).toList();

    return GetListTasksQueryResponse(
      items: itemsWithTranslatableFlag,
      totalItemCount: tasks.totalItemCount,
      pageIndex: request.pageIndex,
      pageSize: request.pageSize,
    );
  }

  List<CustomOrder> _getCustomOrders(GetListTasksQuery request) {
    List<CustomOrder> customOrders = [];
    SortOption<TaskSortFields>? groupField;

    // Prioritize grouping field if exists
    if (request.enableGrouping) {
      groupField = request.groupBy ?? (request.sortBy?.isNotEmpty == true ? request.sortBy!.first : null);
      if (groupField != null) {
        _addCustomOrder(customOrders, groupField);
      }
    }

    if (request.sortByCustomSort) {
      customOrders.add(CustomOrder(field: "order", direction: SortDirection.asc));
      return customOrders;
    }

    // Ensure sortBy is not null before iterating
    final sortOptions = request.sortBy ?? [];

    for (var option in sortOptions) {
      // Avoid duplicating the group field if it's already added
      if (request.enableGrouping && groupField != null && option.field == groupField.field) {
        continue;
      }
      _addCustomOrder(customOrders, option);
    }
    return customOrders;
  }

  void _addCustomOrder(List<CustomOrder> orders, SortOption<TaskSortFields> option) {
    if (option.field == TaskSortFields.createdDate) {
      orders.add(CustomOrder(field: "created_date", direction: option.direction));
    } else if (option.field == TaskSortFields.deadlineDate) {
      orders.add(CustomOrder(field: "deadline_date", direction: option.direction));
    } else if (option.field == TaskSortFields.totalDuration) {
      orders.add(CustomOrder(field: "total_duration", direction: option.direction));
    } else if (option.field == TaskSortFields.estimatedTime) {
      orders.add(CustomOrder(field: "estimated_time", direction: option.direction));
    } else if (option.field == TaskSortFields.modifiedDate) {
      orders.add(CustomOrder(field: "modified_date", direction: option.direction));
    } else if (option.field == TaskSortFields.plannedDate) {
      orders.add(CustomOrder(field: "planned_date", direction: option.direction));
    } else if (option.field == TaskSortFields.priority) {
      orders.add(CustomOrder(field: "priority", direction: option.direction));
    } else if (option.field == TaskSortFields.title) {
      orders.add(CustomOrder(field: "title", direction: option.direction));
    } else if (option.field == TaskSortFields.tag) {
      orders.add(CustomOrder(field: "tag", direction: option.direction));
    }
  }
}
