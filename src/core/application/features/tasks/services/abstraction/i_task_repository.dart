import 'package:application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/tasks/models/task_with_total_duration.dart';
import 'package:application/features/tasks/models/task_query_filter.dart';
import 'package:application/features/tasks/models/task_list_item.dart';

abstract class ITaskRepository extends app.IRepository<Task, String> {
  Future<PaginatedList<TaskWithTotalDuration>> getListWithTotalDuration(
    int pageIndex,
    int pageSize, {
    bool includeDeleted = false,
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
  });

  /// Retrieves a paginated list of tasks using a filter object.
  Future<PaginatedList<TaskWithTotalDuration>> getListWithOptions({
    required int pageIndex,
    required int pageSize,
    TaskQueryFilter? filter,
    bool includeDeleted = false,
  });

  /// Retrieves a paginated list of tasks using a filter object.
  /// This method is an alias for [getListWithOptions].
  Future<PaginatedList<TaskWithTotalDuration>> getListWithFilter({
    required int pageIndex,
    required int pageSize,
    TaskQueryFilter? filter,
    bool includeDeleted = false,
  }) {
    return getListWithOptions(
      pageIndex: pageIndex,
      pageSize: pageSize,
      filter: filter,
      includeDeleted: includeDeleted,
    );
  }

  Future<PaginatedList<TaskListItem>> getListWithDetails({
    required int pageIndex,
    required int pageSize,
    TaskQueryFilter? filter,
    bool includeDeleted = false,
  });

  Future<List<Task>> getByParentTaskId(String parentTaskId);

  Future<List<Task>> getByRecurrenceParentId(String recurrenceParentId);
}
