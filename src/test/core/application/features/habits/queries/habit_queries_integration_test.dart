import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/commands/update_habit_order_command.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';

void main() {
  group('Habit Queries Integration Tests', () {
    late AppDatabase database;
    late DriftHabitRepository habitRepository;
    late DriftHabitTagRepository habitTagsRepository;
    late DriftHabitRecordRepository habitRecordRepository;
    late DriftHabitTimeRecordRepository habitTimeRecordRepository;
    late GetListHabitsQueryHandler getListHabitsHandler;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      database = AppDatabase.forTesting();
      habitRepository = DriftHabitRepository.withDatabase(database);
      habitTagsRepository = DriftHabitTagRepository.withDatabase(database);
      habitRecordRepository = DriftHabitRecordRepository.withDatabase(database);
      habitTimeRecordRepository = DriftHabitTimeRecordRepository.withDatabase(database);

      getListHabitsHandler = GetListHabitsQueryHandler(
        habitRepository: habitRepository,
        habitTagRepository: habitTagsRepository,
        habitRecordRepository: habitRecordRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('should sort habits locally by name case-insensitively', () async {
      final habit1 = Habit(
        id: '1',
        name: 'Apple',
        createdDate: DateTime.now(),
        description: '',
      );
      final habit2 = Habit(
        id: '2',
        name: 'Banana',
        createdDate: DateTime.now(),
        description: '',
      );
      final habit3 = Habit(
        id: '3',
        name: 'apple 2',
        createdDate: DateTime.now(),
        description: '',
      );
      final habit4 = Habit(
        id: '4',
        name: 'card',
        createdDate: DateTime.now(),
        description: '',
      );

      await habitRepository.add(habit1);
      await habitRepository.add(habit2);
      await habitRepository.add(habit3);
      await habitRepository.add(habit4);

      final query = GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        sortBy: [SortOption(field: HabitSortFields.name, direction: SortDirection.asc)],
        sortByCustomSort: false,
      );

      final result = await getListHabitsHandler(query);

      expect(result.items.length, 4);
      expect(result.items[0].name, 'Apple');
      expect(result.items[1].name, 'apple 2');
      expect(result.items[2].name, 'Banana');
      expect(result.items[3].name, 'card');

      // Verify group names are correct
      expect(result.items[0].groupName, 'A');
      expect(result.items[1].groupName, 'A');
      expect(result.items[2].groupName, 'B');
      expect(result.items[3].groupName, 'C');
    });

    test('returns persisted habit types through raw and list mappings', () async {
      final habit = Habit(
        id: 'bad-habit',
        type: HabitType.bad,
        name: 'Avoid',
        createdDate: DateTime.utc(2024, 1, 1),
        description: '',
      );
      await habitRepository.add(habit);

      final storedHabit = await habitRepository.getById(habit.id);
      final list = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        sortBy: [SortOption(field: HabitSortFields.name, direction: SortDirection.asc)],
      ));

      expect(storedHabit!.type, HabitType.bad);
      expect(list.items.single.type, HabitType.bad);
    });

    test('sorts habits by actual time and reports accumulated minutes', () async {
      final createdDate = DateTime.utc(2024, 1, 1);
      await habitRepository.add(Habit(
        id: 'low-duration',
        name: 'Low',
        createdDate: createdDate,
        description: '',
      ));
      await habitRepository.add(Habit(
        id: 'high-duration',
        name: 'High',
        createdDate: createdDate,
        description: '',
      ));

      await habitTimeRecordRepository.add(HabitTimeRecord(
        id: 'time-low',
        habitId: 'low-duration',
        duration: 600,
        createdDate: createdDate,
      ));
      await habitTimeRecordRepository.add(HabitTimeRecord(
        id: 'time-high-1',
        habitId: 'high-duration',
        duration: 900,
        createdDate: createdDate,
      ));
      await habitTimeRecordRepository.add(HabitTimeRecord(
        id: 'time-high-2',
        habitId: 'high-duration',
        duration: 900,
        createdDate: createdDate,
      ));

      final result = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        sortBy: [SortOption(field: HabitSortFields.actualTime, direction: SortDirection.desc)],
      ));

      expect(result.items.map((item) => item.id).toList(), ['high-duration', 'low-duration']);
      expect(result.items.first.actualTime, 30);
      expect(result.items.last.actualTime, 10);
    });

    test('orders custom-sorted habits by rank, creation date, and id', () async {
      // Given
      final createdDate = DateTime.utc(2024, 1, 1);
      final habits = [
        Habit(id: 'custom-c', name: 'C', description: '', createdDate: createdDate, order: 'V'),
        Habit(id: 'custom-b', name: 'B', description: '', createdDate: createdDate, order: 'U'),
        Habit(id: 'custom-a', name: 'A', description: '', createdDate: createdDate, order: 'U'),
      ];
      for (final habit in habits) {
        await habitRepository.add(habit);
      }

      // When
      final query = GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        sortByCustomSort: true,
      );
      final results = await Future.wait(List.generate(5, (_) => getListHabitsHandler(query)));

      // Then
      for (final result in results) {
        expect(result.items.map((habit) => habit.id), ['custom-a', 'custom-b', 'custom-c']);
      }
    });

    test('keeps grouping ahead of custom habit ordering', () async {
      // Given
      final habits = [
        Habit(id: 'group-b', name: 'Beta', description: '', createdDate: DateTime.utc(2024, 1, 1), order: 'U'),
        Habit(
            id: 'group-a-later',
            name: 'Alpha later',
            description: '',
            createdDate: DateTime.utc(2024, 1, 2),
            order: 'V'),
        Habit(
            id: 'group-a-first',
            name: 'Alpha first',
            description: '',
            createdDate: DateTime.utc(2024, 1, 1),
            order: 'U'),
      ];
      for (final habit in habits) {
        await habitRepository.add(habit);
      }

      // When
      final result = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        groupBy: SortOption(field: HabitSortFields.name, direction: SortDirection.asc),
        sortByCustomSort: true,
      ));

      // Then
      expect(result.items.map((habit) => habit.id), ['group-a-first', 'group-a-later', 'group-b']);
    });

    test('custom sort e2e reorders habits through commands and queries', () async {
      final habits = [
        Habit(id: 'habit-1', name: 'Echo', description: '', createdDate: DateTime.utc(2024, 1, 1), order: 'U'),
        Habit(id: 'habit-2', name: 'Delta', description: '', createdDate: DateTime.utc(2024, 1, 2), order: 'V'),
        Habit(id: 'habit-3', name: 'Charlie', description: '', createdDate: DateTime.utc(2024, 1, 3), order: 'W'),
        Habit(id: 'habit-4', name: 'Bravo', description: '', createdDate: DateTime.utc(2024, 1, 4), order: 'X'),
        Habit(id: 'habit-5', name: 'Alpha', description: '', createdDate: DateTime.utc(2024, 1, 5), order: 'Y'),
      ];
      for (final habit in habits) {
        await habitRepository.add(habit);
      }
      final updateOrder = UpdateHabitOrderCommandHandler(habitRepository);

      Future<void> expectCustomOrder(List<String> expectedIds) async {
        final result = await getListHabitsHandler(GetListHabitsQuery(
          pageIndex: 0,
          pageSize: 10,
          sortByCustomSort: true,
          groupBy: null,
        ));
        expect(result.items.map((habit) => habit.id).toList(), expectedIds);
      }

      await updateOrder(UpdateHabitOrderCommand(
        habitId: 'habit-5',
        targetIndex: 0,
      ));
      await expectCustomOrder(['habit-5', 'habit-1', 'habit-2', 'habit-3', 'habit-4']);

      await updateOrder(UpdateHabitOrderCommand(
        habitId: 'habit-1',
        targetIndex: 2,
      ));
      await expectCustomOrder(['habit-5', 'habit-2', 'habit-1', 'habit-3', 'habit-4']);

      await updateOrder(UpdateHabitOrderCommand(
        habitId: 'habit-5',
        targetIndex: 4,
      ));
      await expectCustomOrder(['habit-2', 'habit-1', 'habit-3', 'habit-4', 'habit-5']);

      final groupedResult = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        sortByCustomSort: true,
        groupBy: SortOption(field: HabitSortFields.name, direction: SortDirection.asc),
      ));
      expect(groupedResult.items.map((habit) => habit.id).toList(),
          ['habit-5', 'habit-4', 'habit-3', 'habit-2', 'habit-1']);

      final nonCustomResult = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        sortByCustomSort: false,
        sortBy: [SortOption(field: HabitSortFields.name, direction: SortDirection.asc)],
      ));
      expect(nonCustomResult.items.map((habit) => habit.id).toList(),
          ['habit-5', 'habit-4', 'habit-3', 'habit-2', 'habit-1']);
    });

    test('keeps failed bad habits visible and hides flawless bad habits in mixed completion filters', () async {
      // Given
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      final habits = [
        Habit(
          id: 'good-incomplete',
          name: 'A good incomplete',
          description: '',
          createdDate: today,
        ),
        Habit(
          id: 'good-complete',
          name: 'B good complete',
          description: '',
          createdDate: today,
        ),
        Habit(
          id: 'bad-failed',
          name: 'C bad failed',
          description: '',
          createdDate: today,
          type: HabitType.bad,
        ),
        Habit(
          id: 'bad-flawless',
          name: 'D bad flawless',
          description: '',
          createdDate: today,
          type: HabitType.bad,
        ),
      ];
      for (final habit in habits) {
        await habitRepository.add(habit);
      }
      await habitRecordRepository.add(HabitRecord(
        id: 'good-complete-record',
        habitId: 'good-complete',
        occurredAt: today,
        createdDate: today,
      ));
      await habitRecordRepository.add(HabitRecord(
        id: 'bad-failed-record',
        habitId: 'bad-failed',
        occurredAt: today,
        createdDate: today,
        status: HabitRecordStatus.notDone,
      ));

      // When
      final todayResult = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 2,
        excludeCompleted: true,
        sortBy: [SortOption(field: HabitSortFields.name, direction: SortDirection.asc)],
      ));
      final dateResult = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 2,
        excludeCompletedForDate: today,
        sortBy: [SortOption(field: HabitSortFields.name, direction: SortDirection.asc)],
      ));

      // Then
      expect(todayResult.items.map((item) => item.id), ['good-incomplete', 'bad-failed']);
      expect(todayResult.totalItemCount, 2);
      expect(dateResult.items.map((item) => item.id), ['good-incomplete', 'bad-failed']);
      expect(dateResult.totalItemCount, 2);
    });

    test('returns an incomplete good habit with a period goal', () async {
      // Given
      final today = DateTime(2026, 1, 15, 12);
      await habitRepository.add(Habit(
        id: 'good-goal-incomplete',
        name: 'Good goal incomplete',
        description: '',
        createdDate: today,
        hasGoal: true,
        targetFrequency: 2,
        periodDays: 7,
      ));
      await habitRecordRepository.add(HabitRecord(
        id: 'good-goal-record',
        habitId: 'good-goal-incomplete',
        occurredAt: today,
        createdDate: today,
        status: HabitRecordStatus.complete,
      ));

      // When
      final result = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        excludeCompletedForDate: today,
      ));

      // Then
      expect(result.items.map((habit) => habit.id), contains('good-goal-incomplete'));
    });

    test('preserves repository pagination total after period filtering', () async {
      // Given
      final today = DateTime(2026, 1, 15, 12);
      await habitRepository.add(Habit(
        id: 'good-goal-incomplete',
        name: 'Good goal incomplete',
        description: '',
        createdDate: today,
        hasGoal: true,
        targetFrequency: 2,
        periodDays: 7,
      ));
      await habitRepository.add(Habit(
        id: 'good-goal-complete',
        name: 'Good goal complete',
        description: '',
        createdDate: today,
        hasGoal: true,
        targetFrequency: 1,
        periodDays: 7,
      ));
      await habitRecordRepository.add(HabitRecord(
        id: 'good-goal-complete-record',
        habitId: 'good-goal-complete',
        occurredAt: today,
        createdDate: today,
        status: HabitRecordStatus.complete,
      ));

      // When
      final result = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        excludeCompletedForDate: today,
      ));

      // Then
      expect(result.totalItemCount, 2);
    });

    test('does not hide bad habits outside their applicable date range', () async {
      // Given
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));
      final preCreationHabit = Habit(
        id: 'bad-pre-creation',
        name: 'Bad pre-creation',
        description: '',
        createdDate: today,
        type: HabitType.bad,
      );
      final futureHabit = Habit(
        id: 'bad-future',
        name: 'Bad future',
        description: '',
        createdDate: yesterday,
        type: HabitType.bad,
      );
      final archivedHabit = Habit(
        id: 'bad-archived',
        name: 'Bad archived',
        description: '',
        createdDate: yesterday.subtract(const Duration(days: 1)),
        archivedDate: yesterday,
        type: HabitType.bad,
      );
      for (final habit in [preCreationHabit, futureHabit, archivedHabit]) {
        await habitRepository.add(habit);
        await (database.update(database.habitTable)..where((row) => row.id.equals(habit.id))).write(
          HabitTableCompanion(createdDate: Value(habit.createdDate)),
        );
      }

      // When
      final preCreationResult = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        excludeCompletedForDate: yesterday,
      ));
      final futureResult = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        excludeCompletedForDate: tomorrow,
      ));
      final archivedResult = await getListHabitsHandler(GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        excludeCompletedForDate: today,
      ));

      // Then
      expect(preCreationResult.items.map((item) => item.id), contains('bad-pre-creation'));
      expect(futureResult.items.map((item) => item.id), contains('bad-future'));
      expect(archivedResult.items.map((item) => item.id), contains('bad-archived'));
    });
  });
}
