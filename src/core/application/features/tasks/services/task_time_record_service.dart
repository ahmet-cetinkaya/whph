import 'package:domain/features/tasks/task_time_record.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:acore/acore.dart';

/// Service for managing task time records with hour-based bucketing
class TaskTimeRecordService {
  /// Creates hour boundaries for the given date
  static (DateTime startOfHour, DateTime endOfHour) createHourBoundaries(DateTime targetDate) {
    final startOfHour = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, targetDate.hour);
    final endOfHour = startOfHour.add(const Duration(hours: 1));
    return (startOfHour, endOfHour);
  }

  /// Finds or creates a task time record for the given hour bucket
  static Future<TaskTimeRecord> findOrCreateTaskTimeRecord({
    required ITaskTimeRecordRepository repository,
    required String taskId,
    required DateTime targetDate,
    int initialDuration = 0,
  }) async {
    final (startOfHour, endOfHour) = createHourBoundaries(targetDate);

    final filter =
        CustomWhereFilter('task_id = ? AND created_date >= ? AND created_date < ?', [taskId, startOfHour, endOfHour]);

    final existingRecord = await repository.getFirst(filter);

    if (existingRecord != null) {
      return existingRecord;
    } else {
      // Create new time record
      final newRecord = TaskTimeRecord(
        id: KeyHelper.generateStringId(),
        createdDate: startOfHour, // Use hour bucket start time for consistency
        taskId: taskId,
        duration: initialDuration,
      );
      await repository.add(newRecord);
      return newRecord;
    }
  }

  /// Adds duration to an existing task time record in the hour bucket
  static Future<TaskTimeRecord> addDurationToTaskTimeRecord({
    required ITaskTimeRecordRepository repository,
    required String taskId,
    required DateTime targetDate,
    required int durationToAdd,
  }) async {
    final record = await findOrCreateTaskTimeRecord(
      repository: repository,
      taskId: taskId,
      targetDate: targetDate,
      initialDuration: 0,
    );

    // Create a new object to avoid issues with object references in tests
    final updatedRecord = TaskTimeRecord(
      id: record.id,
      createdDate: record.createdDate,
      taskId: record.taskId,
      duration: record.duration + durationToAdd,
    );

    await repository.update(updatedRecord);
    return updatedRecord;
  }

  /// Sets total duration for a task time record in the hour bucket
  static Future<TaskTimeRecord> setTotalDurationForTaskTimeRecord({
    required ITaskTimeRecordRepository repository,
    required String taskId,
    required DateTime targetDate,
    required int totalDuration,
  }) async {
    final record = await findOrCreateTaskTimeRecord(
      repository: repository,
      taskId: taskId,
      targetDate: targetDate,
      initialDuration: 0,
    );

    // Create a new object to avoid issues with object references in tests
    final updatedRecord = TaskTimeRecord(
      id: record.id,
      createdDate: record.createdDate,
      taskId: record.taskId,
      duration: totalDuration,
    );

    await repository.update(updatedRecord);
    return updatedRecord;
  }
}
