import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/domain/features/habits/habit.dart';

void main() {
  group('Habit Time Record Overflow Tests', () {
    late AppDatabase database;
    late DriftHabitTimeRecordRepository repository;
    late DriftHabitRepository habitRepository;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      database = AppDatabase.forTesting();
      repository = DriftHabitTimeRecordRepository.withDatabase(database);
      habitRepository = DriftHabitRepository.withDatabase(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('should handle duration overflow using TOTAL() instead of SUM()', () async {
      // 1. Create a habit
      final habit = Habit(
        id: 'habit-1',
        name: 'Test Habit',
        createdDate: DateTime.now(),
        description: '',
      );
      await habitRepository.add(habit);

      // 2. Insert records with values that sum up beyond max int
      // Max 64-bit signed integer is 9,223,372,036,854,775,807
      // We use half of that to avoid float precision issues when they sum up.
      const int halfMaxInt = 4611686018427387903; // maxInt / 2

      final record1 = HabitTimeRecord(
        id: 'record-1',
        habitId: 'habit-1',
        duration: halfMaxInt,
        createdDate: DateTime.now(),
      );
      final record2 = HabitTimeRecord(
        id: 'record-2',
        habitId: 'habit-1',
        duration: halfMaxInt,
        createdDate: DateTime.now(),
      );
      final record3 = HabitTimeRecord(
        id: 'record-3',
        habitId: 'habit-1',
        duration: 1000,
        createdDate: DateTime.now(),
      );

      await repository.add(record1);
      await repository.add(record2);
      await repository.add(record3);

      // 3. Verify getTotalDurationByHabitId doesn't throw and returns rounded result
      final totalDuration = await repository.getTotalDurationByHabitId('habit-1');

      expect(totalDuration, isNotNull);
      expect(totalDuration, greaterThan(halfMaxInt * 2));
    });

    test('should handle duration overflow in getTotalDurationsByHabitIds', () async {
      final habit = Habit(
        id: 'habit-2',
        name: 'Test Habit 2',
        createdDate: DateTime.now(),
        description: '',
      );
      await habitRepository.add(habit);

      const int halfMaxInt = 4611686018427387903;

      await repository.add(HabitTimeRecord(
        id: 'record-4',
        habitId: 'habit-2',
        duration: halfMaxInt,
        createdDate: DateTime.now(),
      ));
      await repository.add(HabitTimeRecord(
        id: 'record-5',
        habitId: 'habit-2',
        duration: halfMaxInt,
        createdDate: DateTime.now(),
      ));
      await repository.add(HabitTimeRecord(
        id: 'record-6',
        habitId: 'habit-2',
        duration: 1000,
        createdDate: DateTime.now(),
      ));

      final durations = await repository.getTotalDurationsByHabitIds(['habit-2']);

      expect(durations['habit-2'], isNotNull);
      expect(durations['habit-2'], greaterThan(halfMaxInt * 2));
    });
  });
}
