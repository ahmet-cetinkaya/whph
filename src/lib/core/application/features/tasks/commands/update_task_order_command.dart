import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';

/// Reorders a task within its sibling set (tasks sharing the same
/// [parentTaskId]) so that it lands exactly at [targetIndex].
///
/// The command is intentionally *positional*: the UI only reports where the
/// item was dropped, and the handler — which is the single source of truth for
/// ordering — computes a collision-safe rank against the authoritative,
/// order-sorted sibling list. This avoids the class of bugs where the UI
/// computes a fragile fractional rank that disagrees with the persisted order
/// after a refresh.
///
/// [targetIndex] is the desired final index of the moved task *within the list
/// of its siblings excluding itself* (0 = first position, N = last position
/// where N is the number of siblings). Optional neighbor ids can be supplied
/// as a robustness hint but the handler recomputes positions from the database
/// to stay authoritative.
class UpdateTaskOrderCommand implements IRequest<UpdateTaskOrderResponse> {
  final String taskId;
  final String? parentTaskId;
  final int targetIndex;

  /// Optional hint: id of the sibling that should end up immediately *before*
  /// the moved task. Used only to resolve [targetIndex] robustly if the sibling
  /// set changed between the UI computing the drop and the command running.
  final String? beforeTaskId;

  /// Optional hint: id of the sibling that should end up immediately *after*
  /// the moved task.
  final String? afterTaskId;

  UpdateTaskOrderCommand({
    required this.taskId,
    this.parentTaskId,
    required this.targetIndex,
    this.beforeTaskId,
    this.afterTaskId,
  });
}

class UpdateTaskOrderResponse {
  final String taskId;
  final double order;

  UpdateTaskOrderResponse(this.taskId, this.order);
}

class UpdateTaskOrderCommandHandler implements IRequestHandler<UpdateTaskOrderCommand, UpdateTaskOrderResponse> {
  final ITaskRepository _taskRepository;

  UpdateTaskOrderCommandHandler(this._taskRepository);

  @override
  Future<UpdateTaskOrderResponse> call(UpdateTaskOrderCommand request) async {
    final task = await _taskRepository.getById(request.taskId);
    if (task == null) throw BusinessException('Task not found', TaskTranslationKeys.taskNotFoundError);

    // Authoritative sibling list (excludes the moved task), order-sorted.
    final siblings = await _taskRepository.getAll(
      customWhereFilter: CustomWhereFilter(
        'parent_task_id ${request.parentTaskId != null ? '= ?' : 'IS NULL'} AND id != ? AND deleted_date IS NULL',
        request.parentTaskId != null ? [request.parentTaskId!, task.id] : [task.id],
      ),
      customOrder: [CustomOrder(field: "order")],
    );
    siblings.sort((a, b) => a.order.compareTo(b.order));

    // Resolve the insertion position. Prefer the explicit neighbor hints when
    // they still resolve against the current sibling set; otherwise fall back
    // to the reported target index (clamped to valid bounds).
    final position = _resolvePosition(request, siblings);

    // If the sibling set can no longer accept a reliable midpoint insertion at
    // this position (duplicate/collapsed orders), renormalize everything first
    // so neighbors are cleanly spaced, then insert positionally.
    final currentOrders = siblings.map((t) => t.order).toList();
    final beforeOrder = position > 0 ? siblings[position - 1].order : null;
    final afterOrder = position < siblings.length ? siblings[position].order : null;

    double newOrder;
    if (OrderRank.needsNormalization(currentOrders) || _cannotFit(beforeOrder, afterOrder)) {
      newOrder = await _renormalizeAndPlace(task, siblings, position);
    } else {
      newOrder = OrderRank.neighborRank(beforeOrder: beforeOrder, afterOrder: afterOrder);
      task.order = newOrder;
      task.modifiedDate = DateTime.now().toUtc();
      await _taskRepository.update(task);
    }

    return UpdateTaskOrderResponse(task.id, newOrder);
  }

  /// Determines the 0-based insertion index within [siblings] (which excludes
  /// the moved task). Neighbor hints win when resolvable; otherwise the
  /// reported [UpdateTaskOrderCommand.targetIndex] is clamped to `[0, len]`.
  int _resolvePosition(UpdateTaskOrderCommand request, List<Task> siblings) {
    if (request.afterTaskId != null) {
      final idx = siblings.indexWhere((t) => t.id == request.afterTaskId);
      if (idx != -1) return idx; // Insert *before* the "after" neighbor.
    }
    if (request.beforeTaskId != null) {
      final idx = siblings.indexWhere((t) => t.id == request.beforeTaskId);
      if (idx != -1) return idx + 1; // Insert *after* the "before" neighbor.
    }
    return request.targetIndex.clamp(0, siblings.length);
  }

  bool _cannotFit(double? beforeOrder, double? afterOrder) {
    if (beforeOrder == null || afterOrder == null) return false;
    return (afterOrder - beforeOrder) < OrderRank.minimumOrderGap;
  }

  /// Renumbers the whole sibling set to clean [OrderRank.initialStep] multiples
  /// and inserts [task] at [position], returning its assigned order.
  Future<double> _renormalizeAndPlace(Task task, List<Task> siblings, int position) async {
    final now = DateTime.now().toUtc();
    final ordered = List<Task>.from(siblings);
    final clampedPosition = position.clamp(0, ordered.length);
    ordered.insert(clampedPosition, task);

    double step = OrderRank.initialStep;
    double placedOrder = OrderRank.initialStep;
    for (final t in ordered) {
      t.order = step;
      t.modifiedDate = now;
      await _taskRepository.update(t);
      if (t.id == task.id) placedOrder = step;
      step += OrderRank.initialStep;
    }
    return placedOrder;
  }
}
