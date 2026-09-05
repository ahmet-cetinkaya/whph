import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
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
  final testDate = DateTime(2026, 1, 21, 12, 0, 0);
  final habit = Habit(
    id: habitId,
    name: 'Test Habit',
    createdDate: testDate.subtract(const Duration(days: 30)),
    description: '',
    archivedDate: testDate, // Set to testDate so score calculation uses consistent dates
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

    final records = [
      // Streak 1 (2 days)
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 0)).toUtc(),
          createdDate: testDate),
      HabitRecord(
          id: '2',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 1)).toUtc(),
          createdDate: testDate),

      // Gap at Day 2 (Missing)

      // Streak 2 (2 days)
      HabitRecord(
          id: '4',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 3)).toUtc(),
          createdDate: testDate),
      HabitRecord(
          id: '5',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 4)).toUtc(),
          createdDate: testDate),
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
          createdDate: testDate,
          key: SettingKeys.habitThreeStateEnabled,
          value: 'true',
          valueType: SettingValueType.bool,
        ));

    final records = [
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 0)).toUtc(),
          createdDate: testDate),
      HabitRecord(
          id: '2',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 1)).toUtc(),
          createdDate: testDate),

      // Gap at Day 2 (Missing - Skipped)

      HabitRecord(
          id: '4',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 3)).toUtc(),
          createdDate: testDate),
      HabitRecord(
          id: '5',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 4)).toUtc(),
          createdDate: testDate),
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
          createdDate: testDate,
          key: SettingKeys.habitThreeStateEnabled,
          value: 'true',
          valueType: SettingValueType.bool,
        ));

    final records = [
      // Streak 1
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 0)).toUtc(),
          createdDate: testDate),
      HabitRecord(
          id: '2',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 1)).toUtc(),
          createdDate: testDate),

      // Explicit Not Done at Day 2
      HabitRecord(
          id: '3',
          habitId: habitId,
          status: HabitRecordStatus.notDone,
          occurredAt: testDate.subtract(const Duration(days: 2)).toUtc(),
          createdDate: testDate),

      // Streak 2
      HabitRecord(
          id: '4',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 3)).toUtc(),
          createdDate: testDate),
      HabitRecord(
          id: '5',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 4)).toUtc(),
          createdDate: testDate),
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
          createdDate: testDate,
          key: SettingKeys.habitThreeStateEnabled,
          value: 'true',
          valueType: SettingValueType.bool,
        ));

    final records = [
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 0)).toUtc(),
          createdDate: testDate),
      // Day 1: Skipped (Empty)
      HabitRecord(
          id: '3',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 2)).toUtc(),
          createdDate: testDate),
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

    final records = [
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 0)).toUtc(),
          createdDate: testDate),
      // Day 1: Skipped (Empty) -> Counts as Not Done
      HabitRecord(
          id: '3',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 2)).toUtc(),
          createdDate: testDate),
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
      createdDate: testDate.subtract(const Duration(days: 30)),
      description: '',
      dailyTarget: 2,
      archivedDate: testDate, // Set to testDate so score calculation uses consistent dates
    );
    when(habitRepository.getById(habitId, includeDeleted: false)).thenAnswer((_) async => multiHabit);
    when(settingRepository.getByKey(SettingKeys.habitThreeStateEnabled)).thenAnswer((_) async => null);

    final records = [
      // Day 0: 1/2 completed (50%)
      HabitRecord(
          id: '1',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.toUtc(),
          createdDate: testDate),
      // Day 1: 2/2 completed (100%)
      HabitRecord(
          id: '2',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 1)).toUtc(),
          createdDate: testDate),
      HabitRecord(
          id: '3',
          habitId: habitId,
          status: HabitRecordStatus.complete,
          occurredAt: testDate.subtract(const Duration(days: 1)).toUtc(),
          createdDate: testDate),
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

  group('bad habit statistics', () {
    Habit badHabit({required DateTime createdDate, DateTime? archivedDate}) => Habit(
          id: habitId,
          type: HabitType.bad,
          name: 'Bad habit',
          description: '',
          createdDate: createdDate,
          archivedDate: archivedDate,
        );

    HabitRecord record(String id, DateTime day, HabitRecordStatus status) => HabitRecord(
          id: id,
          habitId: habitId,
          status: status,
          occurredAt: day,
          createdDate: day,
        );

    Future<GetHabitQueryResponse> getStatistics(Habit habit, List<HabitRecord> records) async {
      when(habitRepository.getById(habitId, includeDeleted: false)).thenAnswer((_) async => habit);
      when(settingRepository.getByKey(SettingKeys.habitThreeStateEnabled)).thenAnswer((_) async => null);
      habitRecordRepository.setRecords(records);
      return handler(GetHabitQuery(id: habitId));
    }

    test('Given ten flawless applicable days When loaded Then score and running streak are perfect', () async {
      final today = DateTime.now();
      final creationDay = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 9));
      final complete =
          record('preserved-complete', creationDay.add(const Duration(days: 3)), HabitRecordStatus.complete);

      final response = await getStatistics(badHabit(createdDate: creationDay), [complete]);

      expect(response.statistics.overallScore, 1.0);
      expect(response.statistics.topStreaks.single.days, 10);
      expect(response.statistics.topStreaks.single.endDate, DateTime(today.year, today.month, today.day));
    });

    test('Given one failure in ten days When loaded Then only the applicable failure lowers the score', () async {
      final creationDay = DateTime(2026, 2, 10);
      final archiveDay = creationDay.add(const Duration(days: 9));
      final records = [
        record('failure', creationDay.add(const Duration(days: 4)), HabitRecordStatus.notDone),
        record('ignored-complete', creationDay.add(const Duration(days: 6)), HabitRecordStatus.complete),
        record('pre-creation-failure', creationDay.subtract(const Duration(days: 1)), HabitRecordStatus.notDone),
      ];

      final response = await getStatistics(badHabit(createdDate: creationDay, archivedDate: archiveDay), records);

      expect(response.statistics.overallScore, 0.9);
      expect(response.statistics.totalRecords, 1);
    });

    test('Given creation today When loaded Then the denominator contains that single day', () async {
      final today = DateTime.now();
      final creationDay = DateTime(today.year, today.month, today.day, 23, 30);

      final response = await getStatistics(badHabit(createdDate: creationDay), const []);

      expect(response.statistics.overallScore, 1.0);
      expect(response.statistics.topStreaks.single.days, 1);
    });

    test('Given creation after today When loaded Then empty metrics are finite', () async {
      final today = DateTime.now();
      final futureCreationDay = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));

      final response = await getStatistics(badHabit(createdDate: futureCreationDay), const []);

      expect(response.statistics.overallScore, 0.0);
      expect(response.statistics.monthlyScore, 0.0);
      expect(response.statistics.yearlyScore, 0.0);
      expect(response.statistics.topStreaks, isEmpty);
    });

    test('Given a failure between past and current success runs When loaded Then it breaks the streak', () async {
      final today = DateTime.now();
      final endDay = DateTime(today.year, today.month, today.day);
      final creationDay = endDay.subtract(const Duration(days: 9));
      final failureDay = creationDay.add(const Duration(days: 3));

      final response = await getStatistics(
        badHabit(createdDate: creationDay),
        [record('break', failureDay, HabitRecordStatus.notDone)],
      );

      expect(response.statistics.topStreaks.map((streak) => streak.days), [6, 3]);
      expect(response.statistics.topStreaks.first.endDate, endDay);
      expect(response.statistics.topStreaks.last.endDate, failureDay.subtract(const Duration(days: 1)));
    });

    test('Given creation and archive bounds When loaded Then only inclusive applicable days are scored', () async {
      final creationDay = DateTime(2026, 3, 30, 23, 30);
      final archiveDay = DateTime(2026, 4, 1, 0, 30);
      final records = [
        record('before', DateTime(2026, 3, 29), HabitRecordStatus.notDone),
        record('creation-day', DateTime(2026, 3, 30), HabitRecordStatus.notDone),
        record('after-archive', DateTime(2026, 4, 2), HabitRecordStatus.notDone),
      ];

      final response = await getStatistics(badHabit(createdDate: creationDay, archivedDate: archiveDay), records);

      expect(response.statistics.overallScore, closeTo(2 / 3, 0.0001));
      expect(response.statistics.monthlyScore, 1.0);
      expect(response.statistics.yearlyScore, closeTo(2 / 3, 0.0001));
    });

    test('Given a UTC failure near midnight When loaded Then its local calendar day breaks the streak', () async {
      final occurredAt = DateTime.utc(2026, 4, 13, 0, 30);
      final localFailure = occurredAt.toLocal();
      final failureDay = DateTime(localFailure.year, localFailure.month, localFailure.day);
      final creationDay = failureDay.subtract(const Duration(days: 2));
      final archiveDay = failureDay.add(const Duration(days: 2));

      final response = await getStatistics(
        badHabit(createdDate: creationDay, archivedDate: archiveDay),
        [record('utc-failure', occurredAt, HabitRecordStatus.notDone)],
      );

      expect(response.statistics.overallScore, 0.8);
      expect(response.statistics.topStreaks.map((streak) => streak.days), [2, 2]);
    });

    test('Given a recently created habit When loaded Then the trend spans the trailing twelve months', () async {
      final today = DateTime.now();
      final endDay = DateTime(today.year, today.month, today.day);
      final creationDay = endDay.subtract(const Duration(days: 9));

      final response = await getStatistics(badHabit(createdDate: creationDay), const []);

      final trend = response.statistics.monthlyScores;
      expect(trend.length, 12);
      expect(trend.map((entry) => DateTime(entry.key.year, entry.key.month)).toSet().length, 12);
      expect(trend.every((entry) => entry.key.day == 1), isTrue);
      expect(trend.last.key, DateTime(endDay.year, endDay.month, 1));
      expect(trend.first.key, DateTime(endDay.year, endDay.month - 11, 1));
      expect(trend.every((entry) => entry.value.isFinite), isTrue);
    });

    test('Given months without applicable days When loaded Then those months score zero', () async {
      final today = DateTime.now();
      final endDay = DateTime(today.year, today.month, today.day);
      final creationDay = endDay.subtract(const Duration(days: 9));

      final response = await getStatistics(badHabit(createdDate: creationDay), const []);

      final trend = response.statistics.monthlyScores;
      final monthsBeforeCreation =
          trend.where((entry) => entry.key.isBefore(DateTime(creationDay.year, creationDay.month, 1)));
      expect(monthsBeforeCreation, isNotEmpty);
      expect(monthsBeforeCreation.every((entry) => entry.value == 0.0), isTrue);
    });

    test('Given failures across two months When loaded Then each month keeps its own average', () async {
      final creationDay = DateTime(2026, 3, 1);
      final archiveDay = DateTime(2026, 4, 10);
      final records = [
        record('march-failure', DateTime(2026, 3, 5), HabitRecordStatus.notDone),
        record('april-failure', DateTime(2026, 4, 2), HabitRecordStatus.notDone),
        record('april-second-failure', DateTime(2026, 4, 3), HabitRecordStatus.notDone),
      ];

      final response = await getStatistics(badHabit(createdDate: creationDay, archivedDate: archiveDay), records);

      final trend = Map.fromEntries(response.statistics.monthlyScores);
      expect(trend[DateTime(2026, 3, 1)], closeTo(30 / 31, 0.0001));
      expect(trend[DateTime(2026, 4, 1)], closeTo(8 / 10, 0.0001));
      expect(trend[DateTime(2026, 2, 1)], 0.0);
    });

    test('Given creation after today When loaded Then the trend is empty', () async {
      final today = DateTime.now();
      final futureCreationDay = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));

      final response = await getStatistics(badHabit(createdDate: futureCreationDay), const []);

      expect(response.statistics.monthlyScores, isEmpty);
    });
  });
}
