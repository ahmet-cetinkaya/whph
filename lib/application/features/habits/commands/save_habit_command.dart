import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/domain/features/habits/habit.dart';

class SaveHabitCommand implements IRequest<SaveHabitCommandResponse> {
  final String? id;
  final String name;
  final String description;

  SaveHabitCommand({
    this.id,
    required this.name,
    required this.description,
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
        throw Exception('Habit with id ${request.id} not found');
      }

      await _update(habit, request);
    } else {
      habit = await _add(habit, request);
    }

    return SaveHabitCommandResponse(
      id: habit.id,
      createdDate: habit.createdDate,
      modifiedDate: habit.modifiedDate,
    );
  }

  Future<Habit> _add(Habit? habit, SaveHabitCommand request) async {
    habit = Habit(
      id: nanoid(),
      createdDate: DateTime(0),
      name: request.name,
      description: request.description,
    );
    await _habitRepository.add(habit);
    return habit;
  }

  Future<Habit> _update(Habit habit, SaveHabitCommand request) async {
    habit.name = request.name;
    habit.description = request.description;
    await _habitRepository.update(habit);
    return habit;
  }
}
