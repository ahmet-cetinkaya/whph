import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/models/task_with_total_duration.dart';

abstract class ITaskRepository extends app.IRepository<Task, String> {
  Future<PaginatedList<TaskWithTotalDuration>> getListWithTotalDuration(
    int pageIndex,
    int pageSize, {
    bool includeDeleted = false,
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
  });

  // New method to handle complex filtering with all options
  Future<PaginatedList<TaskWithTotalDuration>> getListWithOptions({
    required int pageIndex,
    required int pageSize,
    List<String>? filterByTags,
    bool filterNoTags = false,
    DateTime? filterByPlannedStartDate,
    DateTime? filterByPlannedEndDate,
    DateTime? filterByDeadlineStartDate,
    DateTime? filterByDeadlineEndDate,
    bool filterDateOr = false,
    bool? filterByCompleted,
    DateTime? filterByCompletedStartDate,
    DateTime? filterByCompletedEndDate,
    String? filterBySearch,
    String? filterByParentTaskId,
    bool areParentAndSubTasksIncluded = false,
    List<CustomOrder>? sortBy,
    bool sortByCustomSort = false,
    bool ignoreArchivedTagVisibility = false,
    bool includeDeleted = false,
  });

  Future<List<Task>> getByParentTaskId(String parentTaskId);

  Future<List<Task>> getByRecurrenceParentId(String recurrenceParentId);
}
