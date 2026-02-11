import 'package:domain/features/habits/habit_time_record.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:acore/acore.dart';

/// Service for managing habit time records with hour-based bucketing
class HabitTimeRecordService {
  /// Creates hour boundaries for the given date
  static (DateTime startOfHour, DateTime endOfHour) createHourBoundaries(DateTime targetDate) {
    final startOfHour = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, targetDate.hour);
    final endOfHour = startOfHour.add(const Duration(hours: 1));
    return (startOfHour, endOfHour);
  }

  /// Finds or creates a habit time record for the given hour bucket
  static Future<HabitTimeRecord> findOrCreateHabitTimeRecord({
    required IHabitTimeRecordRepository repository,
    required String habitId,
    required DateTime targetDate,
    int initialDuration = 0,
  }) async {
    final (startOfHour, endOfHour) = createHourBoundaries(targetDate);

    final filter =
        CustomWhereFilter('habit_id = ? AND created_date >= ? AND created_date < ?', [habitId, startOfHour, endOfHour]);

    final existingRecord = await repository.getFirst(filter);

    if (existingRecord != null) {
      return existingRecord;
    } else {
      // Create new time record
      final newRecord = HabitTimeRecord(
        id: KeyHelper.generateStringId(),
        createdDate: startOfHour, // Use hour bucket start time for consistency
        habitId: habitId,
        duration: initialDuration,
        occurredAt: targetDate,
        isEstimated: false, // Default to false, caller can specify if it's estimated
      );
      await repository.add(newRecord);
      return newRecord;
    }
  }

  /// Adds duration to an existing habit time record in the hour bucket
  static Future<HabitTimeRecord> addDurationToHabitTimeRecord({
    required IHabitTimeRecordRepository repository,
    required String habitId,
    required DateTime targetDate,
    required int durationToAdd,
    bool isEstimated = false,
  }) async {
    final record = await findOrCreateHabitTimeRecord(
      repository: repository,
      habitId: habitId,
      targetDate: targetDate,
      initialDuration: 0,
    );

    record.duration += durationToAdd;
    // Update isEstimated flag if this is adding estimated time to a new record
    if (record.duration == durationToAdd && isEstimated) {
      record.isEstimated = true;
    }
    await repository.update(record);
    return record;
  }

  /// Adds estimated duration to a habit time record in the hour bucket
  static Future<HabitTimeRecord> addEstimatedDurationToHabitTimeRecord({
    required IHabitTimeRecordRepository repository,
    required String habitId,
    required DateTime targetDate,
    required int estimatedDuration,
  }) async {
    return addDurationToHabitTimeRecord(
      repository: repository,
      habitId: habitId,
      targetDate: targetDate,
      durationToAdd: estimatedDuration,
      isEstimated: true,
    );
  }

  /// Sets total duration for a habit time record in the hour bucket
  static Future<HabitTimeRecord> setTotalDurationForHabitTimeRecord({
    required IHabitTimeRecordRepository repository,
    required String habitId,
    required DateTime targetDate,
    required int totalDuration,
  }) async {
    final record = await findOrCreateHabitTimeRecord(
      repository: repository,
      habitId: habitId,
      targetDate: targetDate,
      initialDuration: 0,
    );

    record.duration = totalDuration;
    await repository.update(record);
    return record;
  }
}
