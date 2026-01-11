import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:acore/acore.dart';

// Manual Mocks

class MockHabitRepository extends Mock implements IHabitRepository {
  @override
  Future<Habit?> getById(String id, {bool includeDeleted = false}) {
    return super.noSuchMethod(Invocation.method(#getById, [id], {#includeDeleted: includeDeleted}),
        returnValue: Future.value(null));
  }

  @override
  Future<String> getReminderDaysById(String id) {
    return super.noSuchMethod(Invocation.method(#getReminderDaysById, [id]), returnValue: Future.value(''));
  }
}

class MockHabitRecordRepository extends Mock implements IHabitRecordRepository {
  List<HabitRecord> _recordsToReturn = [];

  void setRecords(List<HabitRecord> records) {
    _recordsToReturn = records;
  }

  @override
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
      String habitId, DateTime fromDate, DateTime toDate, int pageIndex, int pageSize) {
    // Return all records on first page, empty on subsequent for simplicity
    if (pageIndex == 0) {
      return Future.value(
          PaginatedList(items: _recordsToReturn, totalItemCount: _recordsToReturn.length, pageIndex: 0, pageSize: 100));
    }
    return Future.value(
        PaginatedList(items: [], totalItemCount: _recordsToReturn.length, pageIndex: pageIndex, pageSize: 100));
  }
}

class MockSettingRepository extends Mock implements ISettingRepository {
  @override
  Future<Setting?> getByKey(String key) {
    return super.noSuchMethod(Invocation.method(#getByKey, [key]), returnValue: Future.value(null));
  }
}

void main() {
  late MockHabitRepository habitRepository;
  late MockHabitRecordRepository habitRecordRepository;
  late MockSettingRepository settingRepository;
  late GetHabitQueryHandler handler;

  final habitId = 'habit-1';
  final habit = Habit(
    id: habitId,
    name: 'Test Habit',
    createdDate: DateTime.now().subtract(const Duration(days: 30)),
    description: '',
  );

  setUp(() {
    habitRepository = MockHabitRepository();
    habitRecordRepository = MockHabitRecordRepository();
    settingRepository = MockSettingRepository();
    handler = GetHabitQueryHandler(
      habitRepository: habitRepository,
      habitRecordRepository: habitRecordRepository,
      settingsRepository: settingRepository,
    );
    when(habitRepository.getReminderDaysById(habitId)).thenAnswer((_) async => '');
  });

  test('Streak should be strict when 3-state is disabled (gap breaks streak)', () async {
    // Arrange
    when(habitRepository.getById(habitId, includeDeleted: false)).thenAnswer((_) async => habit);
    when(settingRepository.getByKey(SettingKeys.habitThreeStateEnabled)).thenAnswer((_) async => null); // Disabled

    final now = DateTime.now();
    final records = [
      // Streak 1 (2 days)
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 0)).toUtc(),
          createdDate: now),
      HabitRecord(
          id: '2',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 1)).toUtc(),
          createdDate: now),

      // Gap at Day 2 (Missing)

      // Streak 2 (2 days)
      HabitRecord(
          id: '4',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 3)).toUtc(),
          createdDate: now),
      HabitRecord(
          id: '5',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 4)).toUtc(),
          createdDate: now),
    ];

    habitRecordRepository.setRecords(records);

    // Act
    final result = await handler(GetHabitQuery(id: habitId));

    // Assert
    // Should have 2 separate streaks. Both are valid (>= 2 days).
    expect(result.statistics.topStreaks.length, 2);
    expect(result.statistics.topStreaks.first.days, 2);
  });

  test('Streak should skip empty days when 3-state is enabled (gap does not break streak)', () async {
    // Arrange
    when(habitRepository.getById(habitId, includeDeleted: false)).thenAnswer((_) async => habit);
    when(settingRepository.getByKey(SettingKeys.habitThreeStateEnabled)).thenAnswer((_) async => Setting(
          id: 'setting-1',
          createdDate: DateTime.now(),
          key: SettingKeys.habitThreeStateEnabled,
          value: 'true',
          valueType: SettingValueType.bool,
        ));

    final now = DateTime.now();
    final records = [
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 0)).toUtc(),
          createdDate: now),
      HabitRecord(
          id: '2',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 1)).toUtc(),
          createdDate: now),

      // Gap at Day 2 (Missing - Skipped)

      HabitRecord(
          id: '4',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 3)).toUtc(),
          createdDate: now),
      HabitRecord(
          id: '5',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 4)).toUtc(),
          createdDate: now),
    ];

    habitRecordRepository.setRecords(records);

    // Act
    final result = await handler(GetHabitQuery(id: habitId));

    // Assert
    // Should bridge the gap. Streak count should be 4 (Day 0, 1, 3, 4). Day 2 (Skipped) is not counted.
    expect(result.statistics.topStreaks.isNotEmpty, true);
    expect(result.statistics.topStreaks.first.days, 4);
    expect(result.statistics.topStreaks.first.startDate, records[3].recordDate);
    expect(result.statistics.topStreaks.first.endDate, records[0].recordDate);
  });

  test('Streak should break on explicit Not Done even when 3-state is enabled', () async {
    // Arrange
    when(habitRepository.getById(habitId, includeDeleted: false)).thenAnswer((_) async => habit);
    when(settingRepository.getByKey(SettingKeys.habitThreeStateEnabled)).thenAnswer((_) async => Setting(
          id: 'setting-1',
          createdDate: DateTime.now(),
          key: SettingKeys.habitThreeStateEnabled,
          value: 'true',
          valueType: SettingValueType.bool,
        ));

    final now = DateTime.now();
    final records = [
      // Streak 1
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 0)).toUtc(),
          createdDate: now),
      HabitRecord(
          id: '2',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 1)).toUtc(),
          createdDate: now),

      // Explicit Not Done at Day 2
      HabitRecord(
          id: '3',
          habitId: habitId,
          status: HabitRecordStatus.notDone,
          occurredAt: now.subtract(const Duration(days: 2)).toUtc(),
          createdDate: now),

      // Streak 2
      HabitRecord(
          id: '4',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 3)).toUtc(),
          createdDate: now),
      HabitRecord(
          id: '5',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 4)).toUtc(),
          createdDate: now),
    ];

    habitRecordRepository.setRecords(records);

    // Act
    final result = await handler(GetHabitQuery(id: habitId));

    // Assert
    // Not Done breaks the streak.
    // We should have 2 streaks of 2 days (Day 0-1, Day 3-4).
    expect(result.statistics.topStreaks.length, 2);
    expect(result.statistics.topStreaks.first.days, 2);
  });
  test('Score should exclude empty days from denominator when 3-state is enabled (100%)', () async {
    // Arrange
    when(habitRepository.getById(habitId, includeDeleted: false)).thenAnswer((_) async => habit);
    when(settingRepository.getByKey(SettingKeys.habitThreeStateEnabled)).thenAnswer((_) async => Setting(
          id: 'setting-1',
          createdDate: DateTime.now(),
          key: SettingKeys.habitThreeStateEnabled,
          value: 'true',
          valueType: SettingValueType.bool,
        ));

    final now = DateTime.now();
    final records = [
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 0)).toUtc(),
          createdDate: now),
      // Day 1: Unknown (Empty)
      HabitRecord(
          id: '3',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 2)).toUtc(),
          createdDate: now),
    ];

    habitRecordRepository.setRecords(records);

    // Act
    final result = await handler(GetHabitQuery(id: habitId));

    // Assert
    // Total days in range: 3 (Day 0, 1, 2)
    // Valid days (3-state): 2 (Day 0, Day 2). Day 1 is excluded.
    // Score: 2 / 2 = 1.0
    expect(result.statistics.overallScore, 1.0);
  });

  test('Score should include empty days as "Not Done" when 3-state is disabled (66%)', () async {
    // Arrange
    when(habitRepository.getById(habitId, includeDeleted: false)).thenAnswer((_) async => habit);
    when(settingRepository.getByKey(SettingKeys.habitThreeStateEnabled)).thenAnswer((_) async => null); // Disabled

    final now = DateTime.now();
    final records = [
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 0)).toUtc(),
          createdDate: now),
      // Day 1: Unknown (Empty) -> Counts as Not Done
      HabitRecord(
          id: '3',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: now.subtract(const Duration(days: 2)).toUtc(),
          createdDate: now),
    ];

    habitRecordRepository.setRecords(records);

    // Act
    final result = await handler(GetHabitQuery(id: habitId));

    // Assert
    // Total days in range: 3
    // Denominator: 3
    // Score: 2 / 3 = 0.666...
    expect(result.statistics.overallScore, closeTo(0.666, 0.001));
  });

  test('Score handles partial completion for multi-occurrence habit', () async {
    // Arrange
    final multiHabit = Habit(
      id: habitId,
      name: 'Multi Habit',
      createdDate: DateTime.now().subtract(const Duration(days: 30)),
      description: '',
      dailyTarget: 2,
    );
    when(habitRepository.getById(habitId, includeDeleted: false)).thenAnswer((_) async => multiHabit);
    when(settingRepository.getByKey(SettingKeys.habitThreeStateEnabled)).thenAnswer((_) async => null);

    final now = DateTime.now();
    final records = [
      // Day 0: 1/2 completed (50%)
      HabitRecord(
          id: '1', habitId: habitId, status: HabitRecordStatus.complete, occurredAt: now.toUtc(), createdDate: now),
      // Day 1: 2/2 completed (100%)
      HabitRecord(
          id: '2', habitId: habitId, status: HabitRecordStatus.complete, occurredAt: now.subtract(const Duration(days: 1)).toUtc(), createdDate: now),
      HabitRecord(
          id: '3', habitId: habitId, status: HabitRecordStatus.complete, occurredAt: now.subtract(const Duration(days: 1)).toUtc(), createdDate: now),
    ];

    habitRecordRepository.setRecords(records);

    // Act
    final result = await handler(GetHabitQuery(id: habitId));

    // Assert
    // Day 0: 0.5
    // Day 1: 1.0
    // Total days (strict): 2
    // Avg: (0.5 + 1.0) / 2 = 0.75
    expect(result.statistics.overallScore, 0.75);
  });
}
