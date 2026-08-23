import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/shared/services/sibling_reorder_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';

/// Reorders a task within its sibling set (tasks sharing the same
/// [parentTaskId]) so that it lands exactly at the requested drop position.
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
/// Position precedence (see [SiblingReorderService]): [afterTaskId] →
/// [beforeTaskId] → [targetIndex].
class UpdateTaskOrderCommand implements IRequest<UpdateTaskOrderResponse> {
  final String taskId;
  final String? parentTaskId;
  final int targetIndex;
  final String? beforeTaskId;
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

  /// Tasks reorder only among siblings with the same [parentTaskId]; habits are intentionally global.
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

    final placement = _reorderService.computePlacement(
      moved: task,
      siblings: siblings,
      targetIndex: request.targetIndex,
      beforeId: request.beforeTaskId,
      afterId: request.afterTaskId,
      idOf: (t) => t.id,
      orderOf: (t) => t.order,
      setOrder: (t, order) => t.order = order,
    );

    if (placement.requiresRenormalization) {
      // Single transactional batch — all-or-nothing renumbering.
      await _taskRepository.updateMultiple(placement.renumbered!);
    } else {
      await _taskRepository.update(task);
    }

    return UpdateTaskOrderResponse(task.id, placement.order);
  }
}
