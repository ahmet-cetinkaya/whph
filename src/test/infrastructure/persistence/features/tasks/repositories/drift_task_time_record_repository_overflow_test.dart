import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/domain/features/tasks/task.dart';

/// Duration sums must use SQLite's `TOTAL()`, not `SUM()`: `SUM()` returns a
/// 64-bit integer and aborts the whole query with `SQLITE_ERROR` once the sum
/// overflows, which crashed the task list in production.
void main() {
  group('Task Time Record Overflow Tests', () {
    // Half of the max 64-bit signed integer. Two of these overflow `SUM()`
    // while staying clear of float precision loss in `TOTAL()`.
    const int halfMaxInt = 4611686018427387903;

    late AppDatabase database;
    late DriftTaskTimeRecordRepository repository;
    late DriftTaskRepository taskRepository;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      database = AppDatabase.forTesting();
      repository = DriftTaskTimeRecordRepository.withDatabase(database);
      taskRepository = DriftTaskRepository.withDatabase(database);
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> addOverflowingRecords(String taskId, String recordIdPrefix) async {
      await taskRepository.add(Task(
        id: taskId,
        title: 'Overflow task $taskId',
        createdDate: DateTime.now(),
      ));

      final durations = [halfMaxInt, halfMaxInt, 1000];
      for (var i = 0; i < durations.length; i++) {
        await repository.add(TaskTimeRecord(
          id: '$recordIdPrefix-$i',
          taskId: taskId,
          duration: durations[i],
          createdDate: DateTime.now(),
        ));
      }
    }

    test('getTotalDurationByTaskId survives duration overflow', () async {
      await addOverflowingRecords('task-1', 'record-a');

      final totalDuration = await repository.getTotalDurationByTaskId('task-1');

      expect(totalDuration, greaterThan(halfMaxInt));
    });

    test('getTotalDurationsByTaskIds survives duration overflow', () async {
      await addOverflowingRecords('task-2', 'record-b');

      final totals = await repository.getTotalDurationsByTaskIds(['task-2']);

      expect(totals['task-2'], greaterThan(halfMaxInt));
    });

    test('getTotalDurationsByTaskIds still reports zero for tasks without records', () async {
      await taskRepository.add(Task(
        id: 'task-3',
        title: 'No records',
        createdDate: DateTime.now(),
      ));

      final totals = await repository.getTotalDurationsByTaskIds(['task-3']);

      expect(totals['task-3'], 0);
    });

    test('getTotalDurationByTaskId reports exact sums for realistic durations', () async {
      await taskRepository.add(Task(
        id: 'task-4',
        title: 'Realistic durations',
        createdDate: DateTime.now(),
      ));
      for (var i = 0; i < 3; i++) {
        await repository.add(TaskTimeRecord(
          id: 'record-d-$i',
          taskId: 'task-4',
          duration: 3600,
          createdDate: DateTime.now(),
        ));
      }

      final totalDuration = await repository.getTotalDurationByTaskId('task-4');

      expect(totalDuration, 10800);
    });
  });
}
