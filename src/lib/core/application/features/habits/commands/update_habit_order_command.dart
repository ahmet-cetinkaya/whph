import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';

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

    // Trust the calculated order from UI
    habit.order = request.newOrder;
    habit.modifiedDate = DateTime.now().toUtc();
    await _habitRepository.update(habit);

    return UpdateHabitOrderResponse(habit.id, request.newOrder);
  }
}
