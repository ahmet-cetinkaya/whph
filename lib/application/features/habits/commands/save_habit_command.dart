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
  final bool? hasReminder;
  final String? reminderTime;
  final List<int>? reminderDays;

  SaveHabitCommand({
    this.id,
    required this.name,
    required this.description,
    this.estimatedTime,
    this.hasReminder,
    this.reminderTime,
    this.reminderDays,
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

      // Get the actual reminderDays from the database to ensure we have the latest value
      final reminderDaysFromDb = await _habitRepository.getReminderDaysById(request.id!);
      habit.reminderDays = reminderDaysFromDb;

      habit.name = request.name;
      habit.description = request.description;
      habit.estimatedTime = request.estimatedTime;

      // Update reminder settings if provided
      if (request.hasReminder != null) {
        habit.hasReminder = request.hasReminder!;
      }
      if (request.reminderTime != null) {
        habit.reminderTime = request.reminderTime;
      }
      if (request.reminderDays != null) {
        habit.setReminderDaysFromList(request.reminderDays!);
      }

      await _habitRepository.update(habit);
    } else {
      // Create habit with default values
      habit = Habit(
        id: nanoid(),
        createdDate: DateTime.now(),
        name: request.name,
        description: request.description,
        estimatedTime: request.estimatedTime,
        hasReminder: request.hasReminder ?? false,
        reminderTime: request.reminderTime,
      );

      // Set reminder days using the helper method
      if (request.reminderDays != null) {
        habit.setReminderDaysFromList(request.reminderDays!);
      }

      await _habitRepository.add(habit);
    }

    return SaveHabitCommandResponse(
      id: habit.id,
      createdDate: habit.createdDate,
      modifiedDate: habit.modifiedDate,
    );
  }
}
