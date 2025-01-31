import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/application/features/habits/constants/habit_translation_keys.dart';

class DeleteHabitCommand implements IRequest<DeleteHabitCommandResponse> {
  final String id;

  DeleteHabitCommand({required this.id});
}

class DeleteHabitCommandResponse {}

class DeleteHabitCommandHandler implements IRequestHandler<DeleteHabitCommand, DeleteHabitCommandResponse> {
  final IHabitRepository _habitRepository;

  DeleteHabitCommandHandler({required IHabitRepository habitRepository}) : _habitRepository = habitRepository;

  @override
  Future<DeleteHabitCommandResponse> call(DeleteHabitCommand request) async {
    Habit? habit = await _habitRepository.getById(request.id);
    if (habit == null) {
      throw BusinessException(HabitTranslationKeys.habitNotFoundError);
    }

    await _habitRepository.delete(habit);

    return DeleteHabitCommandResponse();
  }
}
