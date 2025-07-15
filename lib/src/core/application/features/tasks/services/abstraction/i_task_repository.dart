import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/core/domain/features/tasks/models/task_with_total_duration.dart';

abstract class ITaskRepository extends app.IRepository<Task, String> {
  Future<PaginatedList<TaskWithTotalDuration>> getListWithTotalDuration(
    int pageIndex,
    int pageSize, {
    bool includeDeleted = false,
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
  });

  Future<List<Task>> getByParentTaskId(String parentTaskId);

  Future<List<Task>> getByRecurrenceParentId(String recurrenceParentId);
}
