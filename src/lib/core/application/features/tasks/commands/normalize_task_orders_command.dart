import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';

/// Renumbers the `order` of all non-deleted tasks within a sibling set (tasks
/// sharing the same [parentTaskId]) to clean [OrderRank.initialStep] multiples,
/// preserving their current relative order.
///
/// Used to repair collapsed/duplicate/near-zero order values (e.g. from
/// migrations, sync merges, or accumulated fractional midpoint reorders) so the
/// next drag lands reliably.
class NormalizeTaskOrdersCommand implements IRequest<NormalizeTaskOrdersResponse> {
  final String? parentTaskId;

  const NormalizeTaskOrdersCommand({this.parentTaskId});
}

class NormalizeTaskOrdersResponse {
  final int normalizedCount;

  NormalizeTaskOrdersResponse(this.normalizedCount);
}

class NormalizeTaskOrdersCommandHandler
    implements IRequestHandler<NormalizeTaskOrdersCommand, NormalizeTaskOrdersResponse> {
  final ITaskRepository _taskRepository;

  NormalizeTaskOrdersCommandHandler(this._taskRepository);

  @override
  Future<NormalizeTaskOrdersResponse> call(NormalizeTaskOrdersCommand request) async {
    final tasks = await _taskRepository.getAll(
      customWhereFilter: CustomWhereFilter(
        'parent_task_id ${request.parentTaskId != null ? '= ?' : 'IS NULL'} AND deleted_date IS NULL',
        request.parentTaskId != null ? [request.parentTaskId!] : [],
      ),
      customOrder: [
        CustomOrder(field: "order", direction: SortDirection.asc),
        CustomOrder(field: "created_date", direction: SortDirection.asc),
        CustomOrder(field: "id", direction: SortDirection.asc),
      ],
    );

    if (tasks.isEmpty) {
      return NormalizeTaskOrdersResponse(0);
    }

    tasks.sort((a, b) {
      final orderComparison = a.order.compareTo(b.order);
      if (orderComparison != 0) return orderComparison;

      final createdDateComparison = a.createdDate.compareTo(b.createdDate);
      if (createdDateComparison != 0) return createdDateComparison;

      return a.id.compareTo(b.id);
    });

    OrderRank.assignSequential<Task>(tasks, setOrder: (task, order) => task.order = order);
    await _taskRepository.updateMultiple(tasks);

    return NormalizeTaskOrdersResponse(tasks.length);
  }
}
