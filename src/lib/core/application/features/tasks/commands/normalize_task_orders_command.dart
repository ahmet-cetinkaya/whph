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
      customOrder: [CustomOrder(field: "order")],
    );

    if (tasks.isEmpty) {
      return NormalizeTaskOrdersResponse(0);
    }

    tasks.sort((a, b) => a.order.compareTo(b.order));

    final now = DateTime.now().toUtc();
    double step = OrderRank.initialStep;
    final tasksToUpdate = <Task>[];

    for (final task in tasks) {
      task.order = step;
      task.modifiedDate = now;
      tasksToUpdate.add(task);
      step += OrderRank.initialStep;
    }

    await _taskRepository.updateMultiple(tasksToUpdate);

    return NormalizeTaskOrdersResponse(tasksToUpdate.length);
  }
}
