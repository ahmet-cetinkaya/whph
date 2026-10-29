import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';

/// Service for managing habit time records with hour-based bucketing (D12).
///
/// Each device owns one bucket per (habit, UTC hour, isEstimated), identified
/// by a deterministic id. Adds increment the own bucket; set-total is
/// hour-level on the non-estimated dimension only: the own non-estimated
/// bucket becomes `target − Σ(other devices' live non-estimated buckets)`.
/// Estimated buckets are a separate dimension, never counted as "other" and
/// never written by set-total.
class HabitTimeRecordService {
  /// Creates hour boundaries for the given date
  static (DateTime startOfHour, DateTime endOfHour) createHourBoundaries(
      DateTime targetDate) {
    final startOfHour = DateTime.utc(
        targetDate.year, targetDate.month, targetDate.day, targetDate.hour);
    final endOfHour = startOfHour.add(const Duration(hours: 1));
    return (startOfHour, endOfHour);
  }

  /// The id of this device's bucket for [habitId] at [targetDate]'s hour.
  static String bucketId({
    required String habitId,
    required DateTime targetDate,
    required String deviceId,
    required bool isEstimated,
  }) =>
      syncTimeBucketId(
        kind: timeBucketKindHabit,
        ownerId: habitId,
        at: targetDate,
        deviceId: deviceId,
        isEstimated: isEstimated,
      );

  /// D12: finds this device's bucket for the hour by its deterministic id.
  /// Legacy random-id buckets are never returned (another device's).
  static Future<HabitTimeRecord> findOrCreateHabitTimeRecord({
    required IHabitTimeRecordRepository repository,
    required String habitId,
    required DateTime targetDate,
    required String deviceId,
    required bool isEstimated,
    int initialDuration = 0,
  }) async {
    final id = bucketId(
        habitId: habitId,
        targetDate: targetDate,
        deviceId: deviceId,
        isEstimated: isEstimated);
    final existing = await repository.getById(id);
    if (existing != null && existing.deletedDate == null) {
      return existing;
    }
    final (startOfHour, _) = createHourBoundaries(targetDate);
    final record = HabitTimeRecord(
      id: id,
      createdDate: startOfHour,
      habitId: habitId,
      duration: initialDuration,
      occurredAt: targetDate,
      isEstimated: isEstimated,
    );
    await repository.upsertRevive(record);
    return record;
  }

  /// D12: adds duration to this device's hour bucket.
  static Future<HabitTimeRecord> addDurationToHabitTimeRecord({
    required IHabitTimeRecordRepository repository,
    required String habitId,
    required DateTime targetDate,
    required String deviceId,
    required int durationToAdd,
    bool isEstimated = false,
  }) async {
    final record = await findOrCreateHabitTimeRecord(
      repository: repository,
      habitId: habitId,
      targetDate: targetDate,
      deviceId: deviceId,
      isEstimated: isEstimated,
      initialDuration: 0,
    );

    final updatedRecord = HabitTimeRecord(
      id: record.id,
      createdDate: record.createdDate,
      habitId: record.habitId,
      duration: record.duration + durationToAdd,
      occurredAt: record.occurredAt,
      isEstimated: record.isEstimated,
    );

    await repository.update(updatedRecord);
    return updatedRecord;
  }

  /// D12: adds estimated duration to this device's hour bucket.
  static Future<HabitTimeRecord> addEstimatedDurationToHabitTimeRecord({
    required IHabitTimeRecordRepository repository,
    required String habitId,
    required DateTime targetDate,
    required String deviceId,
    required int estimatedDuration,
  }) async {
    return addDurationToHabitTimeRecord(
      repository: repository,
      habitId: habitId,
      targetDate: targetDate,
      deviceId: deviceId,
      durationToAdd: estimatedDuration,
      isEstimated: true,
    );
  }

  /// D12 hour-level set-total on the non-estimated dimension: the own
  /// non-estimated bucket at the hour becomes
  /// `totalDuration − Σ(other devices' live non-estimated buckets at that
  /// hour)`. Estimated buckets are never read or written here.
  static Future<HabitTimeRecord> setTotalDurationForHabitTimeRecord({
    required IHabitTimeRecordRepository repository,
    required String habitId,
    required DateTime targetDate,
    required String deviceId,
    required int totalDuration,
  }) async {
    final (startOfHour, endOfHour) = createHourBoundaries(targetDate);
    final ownId = bucketId(
        habitId: habitId,
        targetDate: targetDate,
        deviceId: deviceId,
        isEstimated: false);

    final hourRecords = await repository.getByHabitIdAndDateRange(
        habitId, startOfHour, endOfHour);
    final othersTotal = hourRecords
        .where((record) =>
            record.id != ownId &&
            !record.isEstimated &&
            record.deletedDate == null)
        .fold<int>(0, (sum, record) => sum + record.duration);

    final existing = await repository.getById(ownId);
    final record = HabitTimeRecord(
      id: ownId,
      createdDate: startOfHour,
      habitId: habitId,
      duration: totalDuration - othersTotal,
      occurredAt: targetDate,
      isEstimated: false,
    );
    if (existing != null && existing.deletedDate == null) {
      await repository.update(record);
    } else {
      await repository.upsertRevive(record);
    }
    return record;
  }
}
