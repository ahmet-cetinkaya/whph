import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/shared/services/sibling_reorder_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';

/// Reorders a habit within the full habit set so that it lands exactly at the
/// requested drop position.
///
/// Like the task equivalent, this command is *identity-first, index-fallback*:
/// the UI reports where the item was dropped via [beforeHabitId]/[afterHabitId]
/// neighbor hints, with [targetIndex] as a fallback used only when neither hint
/// resolves. The handler — the single source of truth for ordering — computes a
/// collision-safe rank against the authoritative, order-sorted habit list,
/// renormalizing the whole set when the neighbors can no longer accept a
/// reliable midpoint. This guarantees the persisted order matches the visual
/// drop position after a refresh.
///
/// Position precedence (see [SiblingReorderService]): [afterHabitId] →
/// [beforeHabitId] → [targetIndex].
class UpdateHabitOrderCommand implements IRequest<UpdateHabitOrderResponse> {
  final String habitId;
  final int targetIndex;
  final String? beforeHabitId;
  final String? afterHabitId;

  UpdateHabitOrderCommand({
    required this.habitId,
    required this.targetIndex,
    this.beforeHabitId,
    this.afterHabitId,
  });
}

class UpdateHabitOrderResponse {
  final String habitId;
  final String order;

  UpdateHabitOrderResponse(this.habitId, this.order);
}

class UpdateHabitOrderCommandHandler implements IRequestHandler<UpdateHabitOrderCommand, UpdateHabitOrderResponse> {
  final IHabitRepository _habitRepository;
  final SiblingReorderService _reorderService;

  UpdateHabitOrderCommandHandler(
    this._habitRepository, {
    SiblingReorderService reorderService = const SiblingReorderService(),
  }) : _reorderService = reorderService;

  /// Habits reorder globally; tasks intentionally restrict reordering to a shared parent task.
  @override
  Future<UpdateHabitOrderResponse> call(UpdateHabitOrderCommand request) async {
    final habit = await _habitRepository.getById(request.habitId);
    if (habit == null) throw BusinessException('Habit not found', HabitTranslationKeys.habitNotFoundError);

    // Authoritative sibling list (all other non-deleted habits), order-sorted.
    final siblings = await _habitRepository.getAll(
      customWhereFilter: CustomWhereFilter('id != ? AND deleted_date IS NULL', [habit.id]),
      customOrder: [CustomOrder(field: "order")],
    );
    siblings.sort((a, b) => a.order.compareTo(b.order));

    final placement = _reorderService.computePlacement(
      moved: habit,
      siblings: siblings,
      targetIndex: request.targetIndex,
      beforeId: request.beforeHabitId,
      afterId: request.afterHabitId,
      idOf: (h) => h.id,
      orderOf: (h) => h.order,
    );

    if (placement.requiresRenormalization) {
      // Apply the computed ranks right before persisting — the only place
      // these entities are written to.
      for (final sibling in placement.renumbered!) {
        sibling.order = placement.renumberedOrder![sibling.id]!;
      }
      // Single transactional batch — all-or-nothing renumbering.
      await _habitRepository.updateMultiple(placement.renumbered!);
    } else {
      habit.order = placement.order;
      await _habitRepository.update(habit);
    }

    return UpdateHabitOrderResponse(habit.id, placement.order);
  }
}
