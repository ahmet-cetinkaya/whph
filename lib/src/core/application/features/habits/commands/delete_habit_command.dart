import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/habits/habit.dart';
import 'package:whph/src/core/application/features/habits/constants/habit_translation_keys.dart';

class DeleteHabitCommand implements IRequest<DeleteHabitCommandResponse> {
  final String id;

  DeleteHabitCommand({required this.id});
}

class DeleteHabitCommandResponse {}

class DeleteHabitCommandHandler implements IRequestHandler<DeleteHabitCommand, DeleteHabitCommandResponse> {
  final IHabitRepository _habitRepository;
  final IHabitTagsRepository _habitTagsRepository;
  final IHabitRecordRepository _habitRecordRepository;

  DeleteHabitCommandHandler({
    required IHabitRepository habitRepository,
    required IHabitTagsRepository habitTagsRepository,
    required IHabitRecordRepository habitRecordRepository,
  }) : _habitRepository = habitRepository,
       _habitTagsRepository = habitTagsRepository,
       _habitRecordRepository = habitRecordRepository;

  @override
  Future<DeleteHabitCommandResponse> call(DeleteHabitCommand request) async {
    Habit? habit = await _habitRepository.getById(request.id);
    if (habit == null) {
      throw BusinessException('Habit not found', HabitTranslationKeys.habitNotFoundError);
    }

    // Cascade delete: Delete all related entities first
    await _deleteRelatedEntities(request.id);

    // Delete the habit itself
    await _habitRepository.delete(habit);

    return DeleteHabitCommandResponse();
  }

  /// Deletes all entities related to the habit
  Future<void> _deleteRelatedEntities(String habitId) async {
    // Delete habit tags
    final habitTags = await _habitTagsRepository.getByHabitId(habitId);
    for (final habitTag in habitTags) {
      await _habitTagsRepository.delete(habitTag);
    }

    // Delete habit records
    final habitRecords = await _habitRecordRepository.getByHabitId(habitId);
    for (final habitRecord in habitRecords) {
      await _habitRecordRepository.delete(habitRecord);
    }
  }
}
