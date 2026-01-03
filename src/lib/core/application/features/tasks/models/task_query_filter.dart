import 'package:acore/acore.dart';

/// Filter object for task queries to reduce parameter count in repository methods
class TaskQueryFilter {
  final List<String>? tags;
  final bool noTags;
  final DateTime? plannedStartDate;
  final DateTime? plannedEndDate;
  final DateTime? deadlineStartDate;
  final DateTime? deadlineEndDate;
  final bool dateOr;
  final bool? completed;
  final DateTime? completedStartDate;
  final DateTime? completedEndDate;
  final String? search;
  final String? parentTaskId;
  final bool includeParentAndSubTasks;
  final List<CustomOrder>? sortBy;
  final bool sortByCustomSort;

  final bool ignoreArchivedTagVisibility;
  final bool enableGrouping;

  const TaskQueryFilter({
    this.tags,
    this.noTags = false,
    this.plannedStartDate,
    this.plannedEndDate,
    this.deadlineStartDate,
    this.deadlineEndDate,
    this.dateOr = false,
    this.completed,
    this.completedStartDate,
    this.completedEndDate,
    this.search,
    this.parentTaskId,
    this.includeParentAndSubTasks = false,
    this.sortBy,
    this.sortByCustomSort = false,
    this.ignoreArchivedTagVisibility = false,
    this.enableGrouping = false,
  });

  TaskQueryFilter copyWith({
    List<String>? tags,
    bool? noTags,
    DateTime? plannedStartDate,
    DateTime? plannedEndDate,
    DateTime? deadlineStartDate,
    DateTime? deadlineEndDate,
    bool? dateOr,
    bool? completed,
    DateTime? completedStartDate,
    DateTime? completedEndDate,
    String? search,
    String? parentTaskId,
    bool? includeParentAndSubTasks,
    List<CustomOrder>? sortBy,
    bool? sortByCustomSort,
    bool? ignoreArchivedTagVisibility,
    bool? enableGrouping,
  }) {
    return TaskQueryFilter(
      tags: tags ?? this.tags,
      noTags: noTags ?? this.noTags,
      plannedStartDate: plannedStartDate ?? this.plannedStartDate,
      plannedEndDate: plannedEndDate ?? this.plannedEndDate,
      deadlineStartDate: deadlineStartDate ?? this.deadlineStartDate,
      deadlineEndDate: deadlineEndDate ?? this.deadlineEndDate,
      dateOr: dateOr ?? this.dateOr,
      completed: completed ?? this.completed,
      completedStartDate: completedStartDate ?? this.completedStartDate,
      completedEndDate: completedEndDate ?? this.completedEndDate,
      search: search ?? this.search,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      includeParentAndSubTasks: includeParentAndSubTasks ?? this.includeParentAndSubTasks,
      sortBy: sortBy ?? this.sortBy,
      sortByCustomSort: sortByCustomSort ?? this.sortByCustomSort,
      ignoreArchivedTagVisibility: ignoreArchivedTagVisibility ?? this.ignoreArchivedTagVisibility,
      enableGrouping: enableGrouping ?? this.enableGrouping,
    );
  }
}
