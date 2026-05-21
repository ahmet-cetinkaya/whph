import 'package:whph/core/application/features/habits/services/habit_time_record_service.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';

class HabitRecordOperationsService {
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitTimeRecordRepository _habitTimeRecordRepository;

  HabitRecordOperationsService({
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTimeRecordRepository habitTimeRecordRepository,
  })  : _habitRecordRepository = habitRecordRepository,
        _habitTimeRecordRepository = habitTimeRecordRepository;

  Future<void> addHabitRecord(
    String habitId,
    DateTime occurredAt,
    HabitRecordStatus status,
    DateTime createdDate,
  ) async {
    final habitRecord = HabitRecord(
      id: KeyHelper.generateStringId(),
      createdDate: createdDate,
      habitId: habitId,
      occurredAt: occurredAt,
      status: status,
    );
    await _habitRecordRepository.add(habitRecord);
  }

  Future<void> addTimeRecordIfComplete(
    Habit habit,
    String habitId,
    DateTime occurredAt,
    HabitRecordStatus status,
  ) async {
    if (status == HabitRecordStatus.complete && habit.estimatedTime != null && habit.estimatedTime! > 0) {
      await HabitTimeRecordService.addEstimatedDurationToHabitTimeRecord(
        repository: _habitTimeRecordRepository,
        habitId: habitId,
        targetDate: occurredAt,
        estimatedDuration: (habit.estimatedTime! * 60).toInt(),
      );
    }
  }

  Future<void> clearAllRecordsForDay(
    String habitId,
    DateTime startOfDay,
    DateTime endOfDay,
    List<HabitRecord> recordsToDelete,
  ) async {
    for (final habitRecord in recordsToDelete) {
      await _habitRecordRepository.delete(habitRecord);
    }

    final timeRecords = await _habitTimeRecordRepository.getByHabitIdAndDateRange(
      habitId,
      startOfDay,
      endOfDay,
    );
    for (final timeRecord in timeRecords) {
      await _habitTimeRecordRepository.delete(timeRecord);
    }
  }
}
