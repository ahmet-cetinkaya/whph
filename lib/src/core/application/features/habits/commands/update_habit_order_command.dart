import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/src/core/domain/features/habits/habit.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/application/features/habits/constants/habit_translation_keys.dart';

class UpdateHabitOrderCommand implements IRequest<UpdateHabitOrderResponse> {
  final String habitId;
  final double newOrder;

  UpdateHabitOrderCommand({
    required this.habitId,
    required this.newOrder,
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

    try {
      // Trust the calculated order from UI
      habit.order = request.newOrder;
      habit.modifiedDate = DateTime.now().toUtc();
      await _habitRepository.update(habit);

      return UpdateHabitOrderResponse(habit.id, request.newOrder);
    } on RankGapTooSmallException {
      // Normalize all orders if gaps are too small
      final allHabits = await _habitRepository.getAll(
        customWhereFilter: CustomWhereFilter('deleted_date IS NULL', []),
      );
      
      // Find the moved habit and update its order to reflect the user's intent
      final movedHabitIndex = allHabits.indexWhere((h) => h.id == request.habitId);
      if (movedHabitIndex != -1) {
        allHabits[movedHabitIndex].order = request.newOrder;
      }
      
      allHabits.sort((a, b) => a.order.compareTo(b.order));
      
      // Assign new normalized orders
      double orderStep = OrderRank.initialStep;
      final habitsToUpdate = <Habit>[];
      
      for (var h in allHabits) {
        h.order = orderStep;
        h.modifiedDate = DateTime.now().toUtc();
        habitsToUpdate.add(h);
        orderStep += OrderRank.initialStep;
      }

      // Batch update all habits
      await _habitRepository.updateAll(habitsToUpdate);

      // Find the final normalized order for the moved habit
      final finalOrder = habitsToUpdate.firstWhere((h) => h.id == request.habitId).order;
      return UpdateHabitOrderResponse(request.habitId, finalOrder);
    }
  }
}
