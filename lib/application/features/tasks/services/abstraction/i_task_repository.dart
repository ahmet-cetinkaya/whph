import 'package:whph/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/models/task_with_total_duration.dart';

abstract class ITaskRepository extends IRepository<Task, String> {
  Future<PaginatedList<TaskWithTotalDuration>> getListWithTotalDuration(
    int pageIndex,
    int pageSize, {
    bool includeDeleted = false,
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
  });
}
