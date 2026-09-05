import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';

/// The per-tag duration reports aggregate durations across whole tags, so they
/// overflow `SUM()` sooner than the per-entity totals do. Each of these three
/// reports crashed the statistics screen with `SqliteException(1): integer
/// overflow` before they were switched to `TOTAL()`.
void main() {
  group('Tag Duration Report Overflow Tests', () {
    // Half of the max 64-bit signed integer. Two of these overflow `SUM()`
    // while staying clear of float precision loss in `TOTAL()`.
    const int halfMaxInt = 4611686018427387903;

    late AppDatabase database;
    late DriftTagRepository tagRepository;
    final now = DateTime.now();
    final rangeStart = now.subtract(const Duration(days: 1));
    final rangeEnd = now.add(const Duration(days: 1));

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      database = AppDatabase.forTesting();
      tagRepository = DriftTagRepository.withDatabase(database);
      await tagRepository.add(Tag(id: 'tag-1', name: 'Overflow tag', createdDate: now));
    });

    tearDown(() async {
      await database.close();
    });

    test('task tag report survives duration overflow', () async {
      final taskRepository = DriftTaskRepository.withDatabase(database);
      final timeRecordRepository = DriftTaskTimeRecordRepository.withDatabase(database);
      final taskTagRepository = DriftTaskTagRepository.withDatabase(database);

      await taskRepository.add(Task(id: 'task-1', title: 'Overflow task', createdDate: now));
      await taskTagRepository.add(TaskTag(id: 'task-tag-1', taskId: 'task-1', tagId: 'tag-1', createdDate: now));
      for (final (index, duration) in [halfMaxInt, halfMaxInt, 1000].indexed) {
        await timeRecordRepository.add(TaskTimeRecord(
          id: 'task-record-$index',
          taskId: 'task-1',
          duration: duration,
          createdDate: now,
        ));
      }

      final report = await taskTagRepository.getTopTagsByDuration(rangeStart, rangeEnd);

      expect(report, hasLength(1));
      expect(report.single.duration, greaterThan(halfMaxInt));
    });

    test('habit tag report survives duration overflow', () async {
      final habitRepository = DriftHabitRepository.withDatabase(database);
      final habitRecordRepository = DriftHabitRecordRepository.withDatabase(database);
      final habitTagRepository = DriftHabitTagRepository.withDatabase(database);

      // The report multiplies estimated_time by the record count, so a large
      // estimate over a few records is enough to overflow a 64-bit sum.
      await habitRepository.add(Habit(
        id: 'habit-1',
        name: 'Overflow habit',
        description: '',
        estimatedTime: halfMaxInt ~/ 60,
        createdDate: now,
      ));
      await habitTagRepository.add(HabitTag(id: 'habit-tag-1', habitId: 'habit-1', tagId: 'tag-1', createdDate: now));
      for (var i = 0; i < 3; i++) {
        await habitRecordRepository.add(HabitRecord(
          id: 'habit-record-$i',
          habitId: 'habit-1',
          occurredAt: now,
          createdDate: now,
        ));
      }

      final report = await habitTagRepository.getTopTagsByDuration(rangeStart, rangeEnd);

      expect(report, hasLength(1));
      expect(report.single.duration, greaterThan(halfMaxInt));
    });

    test('app usage tag report survives duration overflow', () async {
      final appUsageRepository = DriftAppUsageRepository.withDatabase(database);
      final timeRecordRepository = DriftAppUsageTimeRecordRepository.withDatabase(database);
      final appUsageTagRepository = DriftAppUsageTagRepository.withDatabase(database);

      await appUsageRepository.add(AppUsage(id: 'app-1', name: 'overflow-app', createdDate: now));
      await appUsageTagRepository
          .add(AppUsageTag(id: 'app-tag-1', appUsageId: 'app-1', tagId: 'tag-1', createdDate: now));
      for (final (index, duration) in [halfMaxInt, halfMaxInt, 1000].indexed) {
        await timeRecordRepository.add(AppUsageTimeRecord(
          id: 'app-record-$index',
          appUsageId: 'app-1',
          duration: duration,
          usageDate: now,
          createdDate: now,
        ));
      }

      final report = await appUsageTagRepository.getTopTagsByDuration(rangeStart, rangeEnd);

      expect(report, hasLength(1));
      expect(report.single.duration, greaterThan(halfMaxInt));
    });
  });
}
