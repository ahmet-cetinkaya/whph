import 'package:whph/core/application/features/habits/services/habit_time_record_service.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';
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

  /// D5c: when the habit's effective `dailyTarget == 1` at creation the
  /// record id is deterministic (`habitId` + local day of `occurredAt`) and
  /// the row upserts/revives; otherwise records keep random ids.
  Future<void> addHabitRecord(
    String habitId,
    DateTime occurredAt,
    HabitRecordStatus status,
    DateTime createdDate, {
    bool deterministic = false,
  }) async {
    final id = deterministic
        ? syncIdentityId(identityKindHabitRecord, [
            habitId,
            occurredAt.toLocal().toIso8601String().substring(0, 10),
          ])
        : KeyHelper.generateStringId();
    final habitRecord = HabitRecord(
      id: id,
      createdDate: createdDate,
      habitId: habitId,
      occurredAt: occurredAt,
      status: status,
    );
    if (deterministic) {
      await _habitRecordRepository.upsertRevive(habitRecord);
    } else {
      await _habitRecordRepository.add(habitRecord);
    }
  }

  Future<void> toggleBadHabitMarker(
    String habitId,
    DateTime occurredAt,
    Iterable<HabitRecord> dayRecords,
  ) async {
    final notDoneRecords = dayRecords
        .where((record) => record.status == HabitRecordStatus.notDone)
        .toList();
    if (notDoneRecords.isEmpty) {
      await addHabitRecord(habitId, occurredAt, HabitRecordStatus.notDone,
          DateTime.now().toUtc());
      return;
    }

    for (final record in notDoneRecords) {
      await _habitRecordRepository.delete(record);
    }
  }

  Future<void> ensureBadHabitMarker(
    String habitId,
    DateTime occurredAt,
    Iterable<HabitRecord> dayRecords,
  ) async {
    final notDoneRecords = dayRecords
        .where((record) => record.status == HabitRecordStatus.notDone)
        .toList();
    if (notDoneRecords.isEmpty) {
      await addHabitRecord(habitId, occurredAt, HabitRecordStatus.notDone,
          DateTime.now().toUtc());
      return;
    }

    for (final duplicate in notDoneRecords.skip(1)) {
      await _habitRecordRepository.delete(duplicate);
    }
  }

  Future<void> addTimeRecordIfComplete(
    Habit habit,
    String habitId,
    DateTime occurredAt,
    HabitRecordStatus status,
  ) async {
    if (status == HabitRecordStatus.complete &&
        habit.estimatedTime != null &&
        habit.estimatedTime! > 0) {
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

    final timeRecords =
        await _habitTimeRecordRepository.getByHabitIdAndDateRange(
      habitId,
      startOfDay,
      endOfDay,
    );
    for (final timeRecord
        in timeRecords.where((record) => record.isEstimated)) {
      await _habitTimeRecordRepository.delete(timeRecord);
    }
  }
}
