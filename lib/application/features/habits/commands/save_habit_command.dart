import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/application/shared/utils/key_helper.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/application/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';

class SaveHabitCommand implements IRequest<SaveHabitCommandResponse> {
  final String? id;
  final String name;
  final String description;
  final int? estimatedTime;
  final DateTime? archivedDate;
  final bool? hasReminder;
  final String? reminderTime;
  final List<int>? reminderDays;
  final bool? hasGoal;
  final int? targetFrequency;
  final int? periodDays;

  SaveHabitCommand({
    this.id,
    required this.name,
    required this.description,
    this.estimatedTime,
    DateTime? archivedDate,
    this.hasReminder,
    this.reminderTime,
    this.reminderDays,
    this.hasGoal,
    this.targetFrequency,
    this.periodDays,
  }) : archivedDate = archivedDate != null ? DateTimeHelper.toUtcDateTime(archivedDate) : null;
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
        throw BusinessException('Habit not found', HabitTranslationKeys.habitNotFoundError);
      }

      // Get the actual reminderDays from the database to ensure we have the latest value
      final reminderDaysFromDb = await _habitRepository.getReminderDaysById(request.id!);
      habit.reminderDays = reminderDaysFromDb;

      habit.name = request.name;
      habit.description = request.description;
      habit.estimatedTime = request.estimatedTime;
      habit.archivedDate = request.archivedDate;

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

      // Update goal settings if provided
      if (request.hasGoal != null) {
        habit.hasGoal = request.hasGoal!;
      }
      if (request.targetFrequency != null) {
        habit.targetFrequency = request.targetFrequency!;
      }
      if (request.periodDays != null) {
        habit.periodDays = request.periodDays!;
      }

      await _habitRepository.update(habit);
    } else {
      // Create habit with default values
      habit = Habit(
        id: KeyHelper.generateStringId(),
        createdDate: DateTime.now().toUtc(),
        name: request.name,
        description: request.description,
        estimatedTime: request.estimatedTime,
        hasReminder: request.hasReminder ?? false,
        reminderTime: request.reminderTime,
        hasGoal: request.hasGoal ?? false,
        targetFrequency: request.targetFrequency ?? 1,
        periodDays: request.periodDays ?? 7,
        archivedDate: request.archivedDate,
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
