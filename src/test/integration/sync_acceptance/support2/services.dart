// The real application services the edit catalog and the edge cases drive:
// time-record buckets, note order normalisation and the import handler, each
// over the database of one lab device.
import 'dart:typed_data';

import 'package:whph/core/application/features/notes/commands/normalize_note_orders_command.dart';
import 'package:whph/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/core/application/features/habits/services/habit_time_record_service.dart';
import 'package:whph/core/application/features/tasks/services/task_time_record_service.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import '../../../infrastructure/persistence/sync/local_reset_test_support.dart';
import 'lab.dart';

/// Points the app's database singleton at [device] before a service runs.
void _useDatabaseOf(LabDevice device) => AppDatabase.setInstanceForTesting(device.appDatabase);

Future<void> addTaskTime(LabDevice device, String taskId, DateTime at, int seconds) {
  _useDatabaseOf(device);
  return TaskTimeRecordService.addDurationToTaskTimeRecord(
    repository: DriftTaskTimeRecordRepository.withDatabase(device.appDatabase),
    taskId: taskId,
    targetDate: at,
    deviceId: device.name,
    durationToAdd: seconds,
  );
}

Future<void> setTaskTimeTotal(LabDevice device, String taskId, DateTime at, int totalSeconds) {
  _useDatabaseOf(device);
  final dayStart = DateTime.utc(at.year, at.month, at.day);
  return TaskTimeRecordService.setTotalDurationForDay(
    repository: DriftTaskTimeRecordRepository.withDatabase(device.appDatabase),
    taskId: taskId,
    dayStart: dayStart,
    targetHour: at,
    deviceId: device.name,
    totalDuration: totalSeconds,
  );
}

Future<void> addHabitTime(LabDevice device, String habitId, DateTime at, int seconds) {
  _useDatabaseOf(device);
  return HabitTimeRecordService.addDurationToHabitTimeRecord(
    repository: DriftHabitTimeRecordRepository.withDatabase(device.appDatabase),
    habitId: habitId,
    targetDate: at,
    deviceId: device.name,
    durationToAdd: seconds,
  );
}

Future<void> setHabitTimeTotal(LabDevice device, String habitId, DateTime at, int totalSeconds) {
  _useDatabaseOf(device);
  return HabitTimeRecordService.setTotalDurationForHabitTimeRecord(
    repository: DriftHabitTimeRecordRepository.withDatabase(device.appDatabase),
    habitId: habitId,
    targetDate: at,
    deviceId: device.name,
    totalDuration: totalSeconds,
  );
}

Future<void> addAppUsageTime(LabDevice device, String recordId, String appUsageId, DateTime at, int seconds) {
  _useDatabaseOf(device);
  return DriftAppUsageTimeRecordRepository.withDatabase(device.appDatabase).add(AppUsageTimeRecord(
    id: recordId,
    createdDate: at,
    appUsageId: appUsageId,
    duration: seconds,
    usageDate: at,
  ));
}

/// The note order screen after a drag: the handler renumbers every live note.
Future<void> normalizeNoteOrders(LabDevice device) {
  _useDatabaseOf(device);
  return NormalizeNoteOrdersCommandHandler(DriftNoteRepository.withDatabase(device.appDatabase))
      .call(const NormalizeNoteOrdersCommand());
}

/// Imports [exportJson] through the real handler (`merge` keeps what is there).
Future<void> importExport(LabDevice device, String exportJson, ImportStrategy strategy) {
  _useDatabaseOf(device);
  return device.security.importHandler(exportJson)(ImportDataCommand(Uint8List(0), strategy));
}

/// The summed duration of the time records of [ownerColumn] = [ownerId].
Future<int> totalDuration(LabDevice device, String table, String ownerColumn, String ownerId) async {
  final rows = await device.db.rows(
      "SELECT COALESCE(SUM(duration), 0) AS total FROM $table WHERE $ownerColumn = '$ownerId' AND deleted_date IS NULL");
  return rows.single['total'] as int;
}
