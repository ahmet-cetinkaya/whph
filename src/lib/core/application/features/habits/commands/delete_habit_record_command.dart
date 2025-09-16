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
  })  : _habitRecordRepository = habitRecordRepository,
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
        await _adjustOrDeleteTimeRecord(existingRecord, habit.estimatedTime! * 60);
      } else {
        // If no record found in the hour bucket, look for records on the same day as a fallback
        final startOfDay = DateTime.utc(targetDate.year, targetDate.month, targetDate.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final dailyRecordFilter = CustomWhereFilter(
            'habit_id = ? AND created_date >= ? AND created_date < ?',
            [habitRecord.habitId, startOfDay, endOfDay]);

        final dailyRecord = await _habitTimeRecordRepository.getFirst(dailyRecordFilter);

        if (dailyRecord != null) {
          await _adjustOrDeleteTimeRecord(dailyRecord, habit.estimatedTime! * 60);
        }
      }
    }

    // Delete the habit record
    await _habitRecordRepository.delete(habitRecord);

    return DeleteHabitRecordCommandResponse();
  }

  /// Adjusts the duration of a time record by subtracting the specified amount.
  /// If the duration becomes 0 or negative, the record is deleted entirely.
  /// Otherwise, the record is updated with the reduced duration.
  Future<void> _adjustOrDeleteTimeRecord(dynamic record, int durationToSubtract) async {
    record.duration -= durationToSubtract;

    if (record.duration <= 0) {
      await _habitTimeRecordRepository.delete(record);
    } else {
      await _habitTimeRecordRepository.update(record);
    }
  }
}
