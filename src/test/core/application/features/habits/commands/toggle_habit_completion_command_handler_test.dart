import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/services/habit_record_operations_service.dart';
import 'package:whph/core/application/features/habits/services/habit_day_state_resolver.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

// Fakes
class FakeHabitRepository extends Fake implements IHabitRepository {
  Habit? _habit;
  void setHabit(Habit h) => _habit = h;

  @override
  Future<Habit?> getById(String id, {bool includeDeleted = false}) async => _habit;
}

class FakeHabitRecordRepository extends Fake implements IHabitRecordRepository {
  List<HabitRecord> records = [];
  bool deleteCalled = false;
  HabitRecord? lastDeletedRecord;
  HabitRecord? lastAddedRecord;

  @override
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
      String habitId, DateTime startDate, DateTime endDate, int pageIndex, int pageSize) async {
    final matchingRecords = records
        .where((record) =>
            record.habitId == habitId && !record.occurredAt.isBefore(startDate) && !record.occurredAt.isAfter(endDate))
        .toList();
    return PaginatedList(
      items: matchingRecords,
      totalItemCount: matchingRecords.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<void> delete(HabitRecord record) async {
    deleteCalled = true;
    lastDeletedRecord = record;
    records.remove(record);
  }

  @override
  Future<void> add(HabitRecord record) async {
    lastAddedRecord = record;
    records.add(record);
  }
}

class FakeHabitTimeRecordRepository extends Fake implements IHabitTimeRecordRepository {
  final List<HabitTimeRecord> records = [];

  @override
  Future<List<HabitTimeRecord>> getByHabitIdAndDateRange(String habitId, DateTime start, DateTime end) async {
    return records.where((record) => record.habitId == habitId).toList();
  }

  @override
  Future<void> delete(HabitTimeRecord record) async {
    records.remove(record);
  }

  @override
  Future<void> add(HabitTimeRecord record) async {
    records.add(record);
  }
}

class FakeSettingRepository extends Fake implements ISettingRepository {
  bool threeStateEnabled = false;

  @override
  Future<Setting?> getByKey(String key) async {
    if (key == SettingKeys.habitThreeStateEnabled) {
      return Setting(
        id: 'setting-1',
        createdDate: DateTime.now(),
        key: SettingKeys.habitThreeStateEnabled,
        value: threeStateEnabled.toString(),
        valueType: SettingValueType.bool,
      );
    }
    return null;
  }
}

void main() {
  tz_data.initializeTimeZones();

  late ToggleHabitCompletionCommandHandler handler;
  late FakeHabitRepository fakeHabitRepository;
  late FakeHabitRecordRepository fakeHabitRecordRepository;
  late FakeHabitTimeRecordRepository fakeHabitTimeRecordRepository;
  late FakeSettingRepository fakeSettingRepository;
  late ({DateTime start, DateTime end}) Function(DateTime) dayRangeResolver;

  setUp(() {
    // Setup in-memory database for transaction support
    AppDatabase.resetInstance();
    AppDatabase.setInstanceForTesting(AppDatabase.forTesting());

    fakeHabitRepository = FakeHabitRepository();
    fakeHabitRecordRepository = FakeHabitRecordRepository();
    fakeHabitTimeRecordRepository = FakeHabitTimeRecordRepository();
    fakeSettingRepository = FakeSettingRepository();
    dayRangeResolver = HabitDayStateResolver.utcRangeFor;

    final operationsService = HabitRecordOperationsService(
      habitRecordRepository: fakeHabitRecordRepository,
      habitTimeRecordRepository: fakeHabitTimeRecordRepository,
    );

    handler = ToggleHabitCompletionCommandHandler(
      habitRepository: fakeHabitRepository,
      habitRecordRepository: fakeHabitRecordRepository,
      settingsRepository: fakeSettingRepository,
      operationsService: operationsService,
      dayRangeResolver: (date) => dayRangeResolver(date),
    );
  });

  tearDown(() async {
    await AppDatabase.instance().close();
    AppDatabase.resetInstance();
  });

  group('Bad Habit', () {
    const habitId = 'habit-bad';
    final date = DateTime(2026, 1, 11, 9);

    setUp(() {
      fakeHabitRepository.setHabit(Habit(
        id: habitId,
        createdDate: DateTime(2026, 1, 1),
        type: HabitType.bad,
        name: 'Avoid habit',
        description: 'Test',
        estimatedTime: 15,
      ));
    });

    test('no marker -> notDone marker -> no marker while preserving complete history', () async {
      // Given
      final preservedComplete = HabitRecord(
        id: 'historical-complete',
        habitId: habitId,
        occurredAt: date.toUtc(),
        createdDate: date.toUtc(),
        status: HabitRecordStatus.complete,
      );
      fakeHabitRecordRepository.records.add(preservedComplete);

      // When
      await handler.call(ToggleHabitCompletionCommand(habitId: habitId, date: date));

      // Then
      expect(fakeHabitRecordRepository.records.where((record) => record.status == HabitRecordStatus.notDone),
          hasLength(1));
      expect(fakeHabitRecordRepository.records, contains(preservedComplete));
      expect(fakeHabitTimeRecordRepository.records, isEmpty);

      // When
      await handler.call(ToggleHabitCompletionCommand(habitId: habitId, date: date));

      // Then
      expect(fakeHabitRecordRepository.records.where((record) => record.status == HabitRecordStatus.notDone), isEmpty);
      expect(fakeHabitRecordRepository.records, contains(preservedComplete));
      expect(fakeHabitTimeRecordRepository.records, isEmpty);
    });

    test('adds the intended marker without deleting the adjacent marker on a 23-hour local day', () async {
      // Given
      final location = tz.getLocation('America/New_York');
      final targetDate = tz.TZDateTime(location, 2026, 3, 8, 12);
      dayRangeResolver = (date) => HabitDayStateResolver.utcRangeFor(
            date,
            localDateTime: (year, month, day) => tz.TZDateTime(location, year, month, day),
          );
      final dayRange = dayRangeResolver(targetDate);
      final adjacentMarker = HabitRecord(
        id: 'next-day-marker',
        habitId: habitId,
        occurredAt: tz.TZDateTime(location, 2026, 3, 9, 0, 30).toUtc(),
        createdDate: targetDate.toUtc(),
        status: HabitRecordStatus.notDone,
      );
      fakeHabitRecordRepository.records.add(adjacentMarker);

      // When
      await handler.call(ToggleHabitCompletionCommand(habitId: habitId, date: targetDate));

      // Then
      expect(dayRange.end.difference(dayRange.start) + const Duration(microseconds: 1), const Duration(hours: 23));
      final markers = fakeHabitRecordRepository.records.where(
        (record) => record.status == HabitRecordStatus.notDone,
      );
      expect(markers, hasLength(2));
      expect(markers, contains(adjacentMarker));
      expect(markers.where((record) => tz.TZDateTime.from(record.occurredAt, location).day == 8), hasLength(1));
    });
  });

  group('Single Occurrence Habit', () {
    final habitId = 'habit-single';
    final date = DateTime(2026, 1, 11);

    final singleHabit = Habit(
      id: habitId,
      createdDate: DateTime.now(),
      name: 'Single Habit',
      description: 'Test',
      hasGoal: false,
    );

    test('Skipped -> Complete', () async {
      fakeHabitRepository.setHabit(singleHabit);
      // No records initially

      final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
      await handler.call(command);

      expect(fakeHabitRecordRepository.lastAddedRecord?.status, HabitRecordStatus.complete);
      expect(fakeHabitRecordRepository.records.length, 1);
    });

    test('Complete -> NotDone (3-state enabled)', () async {
      fakeSettingRepository.threeStateEnabled = true;
      fakeHabitRepository.setHabit(singleHabit);
      fakeHabitRecordRepository.records.add(HabitRecord(
          id: 'r1',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.complete,
          createdDate: DateTime.now()));

      final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
      await handler.call(command);

      // Should delete old and add new NotDone
      expect(fakeHabitRecordRepository.deleteCalled, true);
      expect(fakeHabitRecordRepository.lastAddedRecord?.status, HabitRecordStatus.notDone);
      expect(fakeHabitRecordRepository.records.length, 1);
      expect(fakeHabitRecordRepository.records.first.status, HabitRecordStatus.notDone);
    });

    test('Complete -> Skipped (3-state disabled)', () async {
      fakeSettingRepository.threeStateEnabled = false;
      fakeHabitRepository.setHabit(singleHabit);
      fakeHabitRecordRepository.records.add(HabitRecord(
          id: 'r1',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.complete,
          createdDate: DateTime.now()));

      final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
      await handler.call(command);

      // Should delete old and add nothing (return to Unknown)
      expect(fakeHabitRecordRepository.deleteCalled, true);
      expect(fakeHabitRecordRepository.records.isEmpty, true);
    });

    test('NotDone -> Skipped', () async {
      fakeHabitRepository.setHabit(singleHabit);
      fakeHabitRecordRepository.records.add(HabitRecord(
          id: 'r1',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.notDone,
          createdDate: DateTime.now()));

      final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
      await handler.call(command);

      // Should delete old and add nothing
      expect(fakeHabitRecordRepository.deleteCalled, true);
      expect(fakeHabitRecordRepository.records.isEmpty, true);
    });
  });

  group('Multi Occurrence Habit (Custom Goal)', () {
    final habitId = 'habit-multi';
    final date = DateTime(2026, 1, 11);

    final multiHabit = Habit(
      id: habitId,
      createdDate: DateTime.now(),
      name: 'Multi Habit',
      description: 'Test',
      hasGoal: true,
      dailyTarget: 2, // Target is 2
      periodDays: 1,
      targetFrequency: 1,
    );

    test('Increment: 0 -> 1 (Complete)', () async {
      fakeHabitRepository.setHabit(multiHabit);
      // No records

      final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
      await handler.call(command);

      expect(fakeHabitRecordRepository.records.length, 1);
      expect(fakeHabitRecordRepository.lastAddedRecord?.status, HabitRecordStatus.complete);
    });

    test('Increment: 1 -> 2 (Complete)', () async {
      fakeHabitRepository.setHabit(multiHabit);
      fakeHabitRecordRepository.records.add(HabitRecord(
          id: 'r1',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.complete,
          createdDate: DateTime.now()));

      final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
      await handler.call(command);

      expect(fakeHabitRecordRepository.records.length, 2);
      expect(fakeHabitRecordRepository.lastAddedRecord?.status, HabitRecordStatus.complete);
    });

    test('Target Met (2) -> NotDone (3-state enabled)', () async {
      fakeSettingRepository.threeStateEnabled = true;
      fakeHabitRepository.setHabit(multiHabit);
      // Add 2 records
      fakeHabitRecordRepository.records.add(HabitRecord(
          id: 'r1',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.complete,
          createdDate: DateTime.now()));
      fakeHabitRecordRepository.records.add(HabitRecord(
          id: 'r2',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.complete,
          createdDate: DateTime.now()));

      final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
      await handler.call(command);

      // Should clear existing 2 records and add 1 NotDone record
      expect(fakeHabitRecordRepository.deleteCalled, true);
      expect(fakeHabitRecordRepository.records.length, 1);
      expect(fakeHabitRecordRepository.records.first.status, HabitRecordStatus.notDone);
    });

    test('Target Met (2) -> Skipped/Reset (3-state disabled)', () async {
      fakeSettingRepository.threeStateEnabled = false;
      fakeHabitRepository.setHabit(multiHabit);
      // Add 2 records
      fakeHabitRecordRepository.records.add(HabitRecord(
          id: 'r1',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.complete,
          createdDate: DateTime.now()));
      fakeHabitRecordRepository.records.add(HabitRecord(
          id: 'r2',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.complete,
          createdDate: DateTime.now()));

      final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
      await handler.call(command);

      // Should clear all records
      expect(fakeHabitRecordRepository.deleteCalled, true);
      expect(fakeHabitRecordRepository.records.isEmpty, true);
    });

    test('Currently NotDone -> Skipped/Reset', () async {
      fakeHabitRepository.setHabit(multiHabit);
      fakeHabitRecordRepository.records.add(HabitRecord(
          id: 'r1',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.notDone,
          createdDate: DateTime.now()));

      final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
      await handler.call(command);

      // Should clear records
      expect(fakeHabitRecordRepository.deleteCalled, true);
      expect(fakeHabitRecordRepository.records.isEmpty, true);
    });
  });
}
