import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';

/// Reorders a habit within the full habit set so that it lands exactly at
/// [targetIndex].
///
/// Like the task equivalent, this command is *positional*: the UI reports where
/// the item was dropped and the handler — the single source of truth for
/// ordering — computes a collision-safe rank against the authoritative,
/// order-sorted habit list, renormalizing when the neighbors can no longer
/// accept a reliable midpoint. This guarantees the persisted order matches the
/// visual drop position after a refresh.
///
/// [targetIndex] is the desired final index of the moved habit *within the list
/// of other habits excluding itself* (0 = first, N = last).
class UpdateHabitOrderCommand implements IRequest<UpdateHabitOrderResponse> {
  final String habitId;
  final int targetIndex;

  /// Optional hint: id of the habit that should end up immediately *before* the
  /// moved habit.
  final String? beforeHabitId;

  /// Optional hint: id of the habit that should end up immediately *after* the
  /// moved habit.
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
  final double order;

  UpdateHabitOrderResponse(this.habitId, this.order);
}

class UpdateHabitOrderCommandHandler implements IRequestHandler<UpdateHabitOrderCommand, UpdateHabitOrderResponse> {
  final IHabitRepository _habitRepository;

  UpdateHabitOrderCommandHandler(this._habitRepository);

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

    final position = _resolvePosition(request, siblings);

    final currentOrders = siblings.map((h) => h.order).toList();
    final beforeOrder = position > 0 ? siblings[position - 1].order : null;
    final afterOrder = position < siblings.length ? siblings[position].order : null;

    double newOrder;
    if (OrderRank.needsNormalization(currentOrders) || _cannotFit(beforeOrder, afterOrder)) {
      newOrder = await _renormalizeAndPlace(habit, siblings, position);
    } else {
      newOrder = OrderRank.neighborRank(beforeOrder: beforeOrder, afterOrder: afterOrder);
      habit.order = newOrder;
      habit.modifiedDate = DateTime.now().toUtc();
      await _habitRepository.update(habit);
    }

    return UpdateHabitOrderResponse(habit.id, newOrder);
  }

  int _resolvePosition(UpdateHabitOrderCommand request, List<Habit> siblings) {
    if (request.afterHabitId != null) {
      final idx = siblings.indexWhere((h) => h.id == request.afterHabitId);
      if (idx != -1) return idx; // Insert *before* the "after" neighbor.
    }
    if (request.beforeHabitId != null) {
      final idx = siblings.indexWhere((h) => h.id == request.beforeHabitId);
      if (idx != -1) return idx + 1; // Insert *after* the "before" neighbor.
    }
    return request.targetIndex.clamp(0, siblings.length);
  }

  bool _cannotFit(double? beforeOrder, double? afterOrder) {
    if (beforeOrder == null || afterOrder == null) return false;
    return (afterOrder - beforeOrder) < OrderRank.minimumOrderGap;
  }

  /// Renumbers the whole habit set to clean [OrderRank.initialStep] multiples
  /// and inserts [habit] at [position], returning its assigned order.
  Future<double> _renormalizeAndPlace(Habit habit, List<Habit> siblings, int position) async {
    final now = DateTime.now().toUtc();
    final ordered = List<Habit>.from(siblings);
    final clampedPosition = position.clamp(0, ordered.length);
    ordered.insert(clampedPosition, habit);

    double step = OrderRank.initialStep;
    double placedOrder = OrderRank.initialStep;
    for (final h in ordered) {
      h.order = step;
      h.modifiedDate = now;
      if (h.id == habit.id) placedOrder = step;
      step += OrderRank.initialStep;
    }

    await _habitRepository.updateAll(ordered);
    return placedOrder;
  }
}
