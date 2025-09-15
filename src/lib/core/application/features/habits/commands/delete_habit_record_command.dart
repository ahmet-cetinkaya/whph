import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';

class DeleteHabitRecordCommand implements IRequest<DeleteHabitRecordCommandResponse> {
  final String id;

  DeleteHabitRecordCommand({required this.id});
}

class DeleteHabitRecordCommandResponse {}

class DeleteHabitRecordCommandHandler
    implements IRequestHandler<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse> {
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitRepository _habitRepository;
  final IHabitTimeRecordRepository _habitTimeRecordRepository;

  DeleteHabitRecordCommandHandler({
    required IHabitRecordRepository habitRecordRepository,
    required IHabitRepository habitRepository,
    required IHabitTimeRecordRepository habitTimeRecordRepository,
  }) : _habitRecordRepository = habitRecordRepository,
       _habitRepository = habitRepository,
       _habitTimeRecordRepository = habitTimeRecordRepository;

  @override
  Future<DeleteHabitRecordCommandResponse> call(DeleteHabitRecordCommand request) async {
    HabitRecord? habitRecord = await _habitRecordRepository.getById(request.id);
    if (habitRecord == null) {
      throw BusinessException('Habit record not found', HabitTranslationKeys.habitRecordNotFoundError);
    }

    // Get the habit to check if it has an estimated time
    final habit = await _habitRepository.getById(habitRecord.habitId);
    if (habit?.estimatedTime != null && habit!.estimatedTime! > 0) {
      // Find the time record in the same hour bucket as the habit record
      final targetDate = habitRecord.occurredAt;
      final startOfHour = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, targetDate.hour);
      final endOfHour = startOfHour.add(const Duration(hours: 1));

      final filter = CustomWhereFilter(
          'habit_id = ? AND created_date >= ? AND created_date < ?', [habitRecord.habitId, startOfHour, endOfHour]);

      final existingRecord = await _habitTimeRecordRepository.getFirst(filter);

      if (existingRecord != null) {
        // Subtract the estimated time from the existing record
        existingRecord.duration -= habit.estimatedTime!;

        if (existingRecord.duration <= 0) {
          // If duration becomes 0 or negative, delete the record entirely
          await _habitTimeRecordRepository.delete(existingRecord);
        } else {
          // Otherwise, update with the reduced duration
          await _habitTimeRecordRepository.update(existingRecord);
        }
      } else {
        // If no record found in the hour bucket, find the most recent time record and subtract from it
        // This handles cases where time zone or hour bucket issues occur
        final recentRecordFilter = CustomWhereFilter(
            'habit_id = ? AND duration >= ?', [habitRecord.habitId, habit.estimatedTime!]);

        final recentRecord = await _habitTimeRecordRepository.getFirst(recentRecordFilter);

        if (recentRecord != null) {
          recentRecord.duration -= habit.estimatedTime!;

          if (recentRecord.duration <= 0) {
            await _habitTimeRecordRepository.delete(recentRecord);
          } else {
            await _habitTimeRecordRepository.update(recentRecord);
          }
        }
      }
    }

    // Delete the habit record
    await _habitRecordRepository.delete(habitRecord);

    return DeleteHabitRecordCommandResponse();
  }
}
