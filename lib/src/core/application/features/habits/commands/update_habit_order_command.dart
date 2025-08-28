import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/application/features/habits/constants/habit_translation_keys.dart';

class UpdateHabitOrderCommand implements IRequest<UpdateHabitOrderResponse> {
  final String habitId;
  final double beforeHabitOrder;
  final double afterHabitOrder;

  UpdateHabitOrderCommand({
    required this.habitId,
    required this.beforeHabitOrder,
    required this.afterHabitOrder,
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

    final otherHabits = await _habitRepository.getAll(
      customWhereFilter: CustomWhereFilter(
        'id != ? AND deleted_date IS NULL',
        [habit.id],
      ),
      customOrder: [CustomOrder(field: "order")],
    );

    otherHabits.sort((a, b) => a.order.compareTo(b.order));

    try {
      double newOrder;

      // Directly use the calculated afterHabitOrder from UI
      newOrder = request.afterHabitOrder;

      // Check if the newOrder is valid and make adjustments if needed
      if (otherHabits.isNotEmpty) {
        if (newOrder <= 0) {
          // If trying to move to first position but order is invalid
          newOrder = otherHabits.first.order / 2;
        } else if (newOrder >= (otherHabits.isNotEmpty ? otherHabits.last.order : 0) + OrderRank.maxOrder) {
          // If order is too large, place it properly after the last item
          newOrder = (otherHabits.last.order) + OrderRank.initialStep;
        }
      } else {
        // If there are no other habits, use initial step
        newOrder = OrderRank.initialStep;
      }

      habit.order = newOrder;
      habit.modifiedDate = DateTime.now().toUtc();
      await _habitRepository.update(habit);

      return UpdateHabitOrderResponse(habit.id, newOrder);
    } on RankGapTooSmallException {
      // Normalize all orders if gaps are too small
      double orderStep = OrderRank.initialStep;

      // Include current habit in normalization
      final allHabits = [...otherHabits, habit]..sort((a, b) => a.order.compareTo(b.order));

      for (var h in allHabits) {
        h.order = orderStep;
        h.modifiedDate = DateTime.now().toUtc();
        await _habitRepository.update(h);
        orderStep += OrderRank.initialStep;
      }

      return UpdateHabitOrderResponse(habit.id, habit.order);
    }
  }
}
