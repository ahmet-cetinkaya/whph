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
      final targetDate = habitRecord.occurredAt;
      final estimatedTimeInSeconds = habit.estimatedTime! * 60;

      // Strategy 1: Look for exact time record created at hour boundary (this matches the add logic)
      final startOfHour = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, targetDate.hour);
      final exactTimeRecord =
          await _findTimeRecordByExactTime(habitRecord.habitId, startOfHour, estimatedTimeInSeconds);

      if (exactTimeRecord != null) {
        await _adjustOrDeleteTimeRecord(exactTimeRecord, estimatedTimeInSeconds);
        return DeleteHabitRecordCommandResponse();
      }

      // Strategy 2: Look in hour bucket
      final endOfHour = startOfHour.add(const Duration(hours: 1));

      final hourFilter = CustomWhereFilter(
          'habit_id = ? AND created_date >= ? AND created_date < ?', [habitRecord.habitId, startOfHour, endOfHour]);

      final hourRecord = await _habitTimeRecordRepository.getFirst(hourFilter);

      if (hourRecord != null) {
        await _adjustOrDeleteTimeRecord(hourRecord, estimatedTimeInSeconds);
        return DeleteHabitRecordCommandResponse();
      }

      // Strategy 3: Look in daily range as fallback
      final startOfDay = DateTime.utc(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

      final dailyFilter = CustomWhereFilter(
          'habit_id = ? AND created_date >= ? AND created_date <= ?', [habitRecord.habitId, startOfDay, endOfDay]);

      final dailyRecord = await _habitTimeRecordRepository.getFirst(dailyFilter);

      if (dailyRecord != null) {
        await _adjustOrDeleteTimeRecord(dailyRecord, estimatedTimeInSeconds);
      } else {
        // Strategy 4: Find the most suitable time record to adjust on the same day
        // This limits the search to the same day as the habit record to avoid deleting unrelated time data
        final recordDate = habitRecord.occurredAt;
        final startOfDay = DateTime.utc(recordDate.year, recordDate.month, recordDate.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final sameDayFilter = CustomWhereFilter(
          'habit_id = ? AND created_date >= ? AND created_date < ? AND duration >= ?',
          [habitRecord.habitId, startOfDay, endOfDay, estimatedTimeInSeconds]
        );

        final suitableRecord = await _habitTimeRecordRepository.getFirst(sameDayFilter);

        if (suitableRecord != null) {
          await _adjustOrDeleteTimeRecord(suitableRecord, estimatedTimeInSeconds);
        }
      }
    }

    // Delete the habit record
    await _habitRecordRepository.delete(habitRecord);

    return DeleteHabitRecordCommandResponse();
  }

  /// Looks for a time record created at the exact time with approximately the expected duration
  Future<dynamic> _findTimeRecordByExactTime(String habitId, DateTime exactTime, int expectedDuration) async {
    final filter = CustomWhereFilter('habit_id = ? AND created_date = ?', [habitId, exactTime]);

    final record = await _habitTimeRecordRepository.getFirst(filter);

    // Only return the record if it contains the expected duration (it might have been accumulated)
    if (record != null && record.duration >= expectedDuration) {
      return record;
    }

    return null;
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
