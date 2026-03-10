import 'package:flutter_test/flutter_test.dart';
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
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
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
    return PaginatedList(items: List.from(records), totalItemCount: records.length, pageIndex: 0, pageSize: 10);
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
  @override
  Future<List<HabitTimeRecord>> getByHabitIdAndDateRange(String habitId, DateTime start, DateTime end) async {
    return [];
  }

  @override
  Future<void> delete(HabitTimeRecord record) async {}

  @override
  Future<void> add(HabitTimeRecord record) async {}
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
  late ToggleHabitCompletionCommandHandler handler;
  late FakeHabitRepository fakeHabitRepository;
  late FakeHabitRecordRepository fakeHabitRecordRepository;
  late FakeHabitTimeRecordRepository fakeHabitTimeRecordRepository;
  late FakeSettingRepository fakeSettingRepository;

  setUp(() {
    // Setup in-memory database for transaction support
    AppDatabase.resetInstance();
    AppDatabase.setInstanceForTesting(AppDatabase.forTesting());

    fakeHabitRepository = FakeHabitRepository();
    fakeHabitRecordRepository = FakeHabitRecordRepository();
    fakeHabitTimeRecordRepository = FakeHabitTimeRecordRepository();
    fakeSettingRepository = FakeSettingRepository();

    handler = ToggleHabitCompletionCommandHandler(
      habitRepository: fakeHabitRepository,
      habitRecordRepository: fakeHabitRecordRepository,
      habitTimeRecordRepository: fakeHabitTimeRecordRepository,
      settingsRepository: fakeSettingRepository,
    );
  });

  tearDown(() async {
    await AppDatabase.instance().close();
    AppDatabase.resetInstance();
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
