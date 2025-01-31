import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/application/features/habits/constants/habit_translation_keys.dart';

class SaveHabitCommand implements IRequest<SaveHabitCommandResponse> {
  final String? id;
  final String name;
  final String description;
  final int? estimatedTime;

  SaveHabitCommand({
    this.id,
    required this.name,
    required this.description,
    this.estimatedTime,
  });
}

class SaveHabitCommandResponse {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;

  SaveHabitCommandResponse({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
  });
}

class SaveHabitCommandHandler implements IRequestHandler<SaveHabitCommand, SaveHabitCommandResponse> {
  final IHabitRepository _habitRepository;

  SaveHabitCommandHandler({required IHabitRepository habitRepository}) : _habitRepository = habitRepository;

  @override
  Future<SaveHabitCommandResponse> call(SaveHabitCommand request) async {
    Habit? habit;

    if (request.id != null) {
      habit = await _habitRepository.getById(request.id!);
      if (habit == null) {
        throw BusinessException(HabitTranslationKeys.habitNotFoundError);
      }

      habit.name = request.name;
      habit.description = request.description;
      habit.estimatedTime = request.estimatedTime;
      await _habitRepository.update(habit);
    } else {
      habit = Habit(
        id: nanoid(),
        createdDate: DateTime.now(),
        name: request.name,
        description: request.description,
        estimatedTime: request.estimatedTime,
      );
      await _habitRepository.add(habit);
    }

    return SaveHabitCommandResponse(
      id: habit.id,
      createdDate: habit.createdDate,
      modifiedDate: habit.modifiedDate,
    );
  }
}
