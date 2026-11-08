import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';

/// Service for managing task time records with hour-based bucketing (D12).
///
/// Each device owns one bucket per (task, UTC hour), identified by a
/// deterministic id; adds increment the own bucket, set-total writes the
/// day-level delta into the own bucket and zeroes the own day's other hours.
class TaskTimeRecordService {
  /// Creates hour boundaries for the given date
  static (DateTime startOfHour, DateTime endOfHour) createHourBoundaries(
      DateTime targetDate) {
    final startOfHour = DateTime.utc(
        targetDate.year, targetDate.month, targetDate.day, targetDate.hour);
    final endOfHour = startOfHour.add(const Duration(hours: 1));
    return (startOfHour, endOfHour);
  }

  /// Creates the UTC day window `[start, start + 24 h)` of [targetDate].
  static (DateTime startOfDay, DateTime endOfDay) createDayBoundaries(
      DateTime targetDate) {
    final startOfDay =
        DateTime.utc(targetDate.year, targetDate.month, targetDate.day);
    return (startOfDay, startOfDay.add(const Duration(days: 1)));
  }

  /// The id of this device's bucket for [taskId] at [targetDate]'s hour.
  static String bucketId(
          {required String taskId,
          required DateTime targetDate,
          required String deviceId}) =>
      syncTimeBucketId(
        kind: timeBucketKindTask,
        ownerId: taskId,
        at: targetDate,
        deviceId: deviceId,
      );

  /// D12: finds this device's bucket for the hour by its deterministic id.
  /// Legacy random-id buckets are never returned (they count as another
  /// device's) and a missing bucket is created via upsertRevive.
  static Future<TaskTimeRecord> findOrCreateTaskTimeRecord({
    required ITaskTimeRecordRepository repository,
    required String taskId,
    required DateTime targetDate,
    required String deviceId,
    int initialDuration = 0,
  }) async {
    final id =
        bucketId(taskId: taskId, targetDate: targetDate, deviceId: deviceId);
    final existing = await repository.getById(id);
    if (existing != null && existing.deletedDate == null) {
      return existing;
    }
    final (startOfHour, _) = createHourBoundaries(targetDate);
    final record = TaskTimeRecord(
      id: id,
      createdDate: startOfHour,
      taskId: taskId,
      duration: initialDuration,
    );
    await repository.upsertRevive(record);
    return record;
  }

  /// D12: adds duration to this device's hour bucket.
  static Future<TaskTimeRecord> addDurationToTaskTimeRecord({
    required ITaskTimeRecordRepository repository,
    required String taskId,
    required DateTime targetDate,
    required String deviceId,
    required int durationToAdd,
  }) async {
    final record = await findOrCreateTaskTimeRecord(
      repository: repository,
      taskId: taskId,
      targetDate: targetDate,
      deviceId: deviceId,
      initialDuration: 0,
    );

    final updatedRecord = TaskTimeRecord(
      id: record.id,
      createdDate: record.createdDate,
      taskId: record.taskId,
      duration: record.duration + durationToAdd,
    );

    await repository.update(updatedRecord);
    return updatedRecord;
  }

  /// D12 day-level set-total: the own bucket at the target hour becomes
  /// `target − Σ(live buckets of other devices in that UTC day)` and this
  /// device's other buckets of the day are set to 0 (updated, not deleted).
  /// Nothing is soft-deleted; the day total on this device equals [totalDuration].
  static Future<TaskTimeRecord> setTotalDurationForDay({
    required ITaskTimeRecordRepository repository,
    required String taskId,
    required DateTime dayStart,
    required DateTime targetHour,
    required String deviceId,
    required int totalDuration,
  }) async {
    final endOfDay = dayStart.add(const Duration(days: 1));

    // Clamped target hour (D12): never outside the day window.
    final clampedHour = targetHour.isBefore(dayStart)
        ? dayStart
        : (targetHour.isBefore(endOfDay)
            ? targetHour
            : endOfDay.subtract(const Duration(hours: 1)));

    final dayRecords = (await repository.getAll(
      includeDeleted: false,
      customWhereFilter: CustomWhereFilter(
        'task_id = ? AND created_date >= ? AND created_date < ?',
        [taskId, dayStart, endOfDay],
      ),
    ))
        .toList();

    final ownTargetId =
        bucketId(taskId: taskId, targetDate: clampedHour, deviceId: deviceId);
    final othersTotal = dayRecords
        .where((record) => record.id != ownTargetId)
        .fold<int>(0, (sum, record) => sum + record.duration);

    // Zero the own day buckets other than the target hour's (kept rows, not deletes).
    for (final record in dayRecords) {
      final isOwnBucket = record.id ==
          bucketId(
              taskId: taskId,
              targetDate: record.createdDate,
              deviceId: deviceId);
      if (isOwnBucket && record.id != ownTargetId && record.duration != 0) {
        await repository.update(TaskTimeRecord(
          id: record.id,
          createdDate: record.createdDate,
          taskId: record.taskId,
          duration: 0,
        ));
      }
    }

    final (startOfHour, _) = createHourBoundaries(clampedHour);
    final ownRecord = TaskTimeRecord(
      id: ownTargetId,
      createdDate: startOfHour,
      taskId: taskId,
      duration: totalDuration - othersTotal,
    );
    final existing = await repository.getById(ownTargetId);
    if (existing != null && existing.deletedDate == null) {
      await repository.update(ownRecord);
    } else {
      await repository.upsertRevive(ownRecord);
    }
    return ownRecord;
  }
}
