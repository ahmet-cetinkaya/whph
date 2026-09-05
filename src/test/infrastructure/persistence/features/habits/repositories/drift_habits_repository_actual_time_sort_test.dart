import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:acore/acore.dart' as acore;
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';

/// `getList` sorted by `actual_time` aggregates durations in its ORDER BY
/// clause. It kept using `SUM()` after the sibling query was moved to
/// `TOTAL()`, so sorting the habit list by time still crashed with
/// `SqliteException(1): integer overflow`.
void main() {
  group('Habit list actual_time sort', () {
    // Half of the max 64-bit signed integer. Two of these overflow `SUM()`
    // while staying clear of float precision loss in `TOTAL()`.
    const int halfMaxInt = 4611686018427387903;

    late AppDatabase database;
    late DriftHabitRepository habitRepository;
    late DriftHabitTimeRecordRepository timeRecordRepository;
    final now = DateTime.now();

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      database = AppDatabase.forTesting();
      habitRepository = DriftHabitRepository.withDatabase(database);
      timeRecordRepository = DriftHabitTimeRecordRepository.withDatabase(database);
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> addHabit(String id, String name, List<int> durations) async {
      await habitRepository.add(Habit(id: id, name: name, description: '', createdDate: now));
      for (final (index, duration) in durations.indexed) {
        await timeRecordRepository.add(HabitTimeRecord(
          id: '$id-record-$index',
          habitId: id,
          duration: duration,
          createdDate: now,
        ));
      }
    }

    test('survives duration overflow', () async {
      await addHabit('habit-overflow', 'Overflow', [halfMaxInt, halfMaxInt, 1000]);

      final result = await habitRepository
          .getList(0, 10, customOrder: [acore.CustomOrder(field: 'actual_time', direction: acore.SortDirection.desc)]);

      expect(result.items, hasLength(1));
    });

    test('orders habits by their recorded time', () async {
      await addHabit('habit-short', 'Short', [60]);
      await addHabit('habit-long', 'Long', [3600]);
      await addHabit('habit-medium', 'Medium', [600]);

      final result = await habitRepository
          .getList(0, 10, customOrder: [acore.CustomOrder(field: 'actual_time', direction: acore.SortDirection.desc)]);

      expect(result.items.map((habit) => habit.id).toList(), ['habit-long', 'habit-medium', 'habit-short']);
    });
  });
}
