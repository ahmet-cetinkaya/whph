import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/shared/services/sibling_reorder_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';

/// Reorders a task within its sibling set (tasks sharing the same parent) so
/// that it lands exactly at the requested drop position.
///
/// The command is *identity-first, index-fallback*: the UI reports where the
/// item was dropped via [beforeTaskId]/[afterTaskId] neighbor hints, with
/// [targetIndex] as a fallback used only when neither hint resolves against the
/// current sibling set (e.g. a neighbor was concurrently deleted). The handler
/// — the single source of truth for ordering — computes a collision-safe rank
/// against the authoritative, order-sorted sibling list, renormalizing the
/// whole set when the neighbors can no longer accept a reliable midpoint. This
/// guarantees the persisted order matches the visual drop position after a
/// refresh.
///
/// Sibling scope is always the moved task's *own* [Task.parentTaskId], read
/// from the persisted task rather than supplied by the caller. A flat "show
/// sub-tasks" list can display siblings from different parent scopes side by
/// side, and the UI has no reliable way to report the dragged item's true
/// scope — deriving it from the loaded task is the only source that can't
/// disagree with where the task actually lives.
///
/// Position precedence (see [SiblingReorderService]): [afterTaskId] →
/// [beforeTaskId] → [targetIndex].
class UpdateTaskOrderCommand implements IRequest<UpdateTaskOrderResponse> {
  final String taskId;
  final int targetIndex;
  final String? beforeTaskId;
  final String? afterTaskId;

  UpdateTaskOrderCommand({
    required this.taskId,
    required this.targetIndex,
    this.beforeTaskId,
    this.afterTaskId,
  });
}

class UpdateTaskOrderResponse {
  final String taskId;
  final String order;

  UpdateTaskOrderResponse(this.taskId, this.order);
}

class UpdateTaskOrderCommandHandler implements IRequestHandler<UpdateTaskOrderCommand, UpdateTaskOrderResponse> {
  final ITaskRepository _taskRepository;
  final SiblingReorderService _reorderService;

  UpdateTaskOrderCommandHandler(
    this._taskRepository, {
    SiblingReorderService reorderService = const SiblingReorderService(),
  }) : _reorderService = reorderService;

  /// Tasks reorder only among siblings with the same parent; habits are intentionally global.
  @override
  Future<UpdateTaskOrderResponse> call(UpdateTaskOrderCommand request) async {
    final task = await _taskRepository.getById(request.taskId);
    if (task == null) throw BusinessException('Task not found', TaskTranslationKeys.taskNotFoundError);

    // Scope is the moved task's own parent, never a caller-supplied value —
    // see the class doc for why.
    final scopeParentId = task.parentTaskId;

    // Authoritative sibling list (excludes the moved task), order-sorted.
    // The repository's SQL ORDER BY on `order` uses SQLite's default BINARY
    // collation, which agrees byte-for-byte with Dart's String.compareTo for
    // OrderRank's ASCII base-62 alphabet — no redundant re-sort needed.
    final siblings = await _taskRepository.getAll(
      customWhereFilter: CustomWhereFilter(
        'parent_task_id ${scopeParentId != null ? '= ?' : 'IS NULL'} AND id != ? AND deleted_date IS NULL',
        scopeParentId != null ? [scopeParentId, task.id] : [task.id],
      ),
      customOrder: [
        CustomOrder(field: "order", direction: SortDirection.asc),
        CustomOrder(field: "created_date", direction: SortDirection.asc),
        CustomOrder(field: "id", direction: SortDirection.asc),
      ],
    );

    final placement = _reorderService.computePlacement(
      moved: task,
      siblings: siblings,
      targetIndex: request.targetIndex,
      beforeId: request.beforeTaskId,
      afterId: request.afterTaskId,
      idOf: (t) => t.id,
      orderOf: (t) => t.order,
    );

    if (placement.requiresRenormalization) {
      // Apply the computed ranks right before persisting — the only place
      // these entities are written to.
      for (final sibling in placement.renumbered!) {
        sibling.order = placement.renumberedOrder![sibling.id]!;
      }
      // Single transactional batch — all-or-nothing renumbering.
      await _taskRepository.updateMultiple(placement.renumbered!);
    } else {
      task.order = placement.order;
      await _taskRepository.update(task);
    }

    return UpdateTaskOrderResponse(task.id, placement.order);
  }
}
