import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/commands/complete_habit_command.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

class FakeHabitRepository extends Fake implements IHabitRepository {
  Habit? _habit;

  void setHabit(Habit habit) => _habit = habit;

  @override
  Future<Habit?> getById(String id, {bool includeDeleted = false}) async => _habit;
}

class FakeHabitRecordRepository extends Fake implements IHabitRecordRepository {
  final List<HabitRecord> records = [];
  int addCount = 0;
  int deleteCount = 0;

  @override
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
    String habitId,
    DateTime startDate,
    DateTime endDate,
    int pageIndex,
    int pageSize,
  ) async {
    final matchingRecords = records
        .where((record) =>
            record.habitId == habitId &&
            !record.occurredAt.isBefore(startDate) &&
            !record.occurredAt.isAfter(endDate))
        .toList();
    return PaginatedList(
      items: matchingRecords,
      totalItemCount: matchingRecords.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<void> add(HabitRecord record) async {
    addCount++;
    records.add(record);
  }

  @override
  Future<void> delete(HabitRecord record) async {
    deleteCount++;
    records.removeWhere((existingRecord) => existingRecord.id == record.id);
  }
}

class FakeHabitTimeRecordRepository extends Fake implements IHabitTimeRecordRepository {
  final List<HabitTimeRecord> records = [];
  int addCount = 0;
  int updateCount = 0;

  @override
  Future<HabitTimeRecord?> getFirst(CustomWhereFilter filter, {bool includeDeleted = false}) async {
    return records.firstOrNull;
  }

  @override
  Future<void> add(HabitTimeRecord record) async {
    addCount++;
    records.add(record);
  }

  @override
  Future<void> update(HabitTimeRecord record) async {
    updateCount++;
    final index = records.indexWhere((existingRecord) => existingRecord.id == record.id);
    if (index >= 0) {
      records[index] = record;
    }
  }

  @override
  Future<List<HabitTimeRecord>> getByHabitIdAndDateRange(String habitId, DateTime start, DateTime end) async {
    return records.where((record) => record.habitId == habitId).toList();
  }
}

void main() {
  late CompleteHabitCommandHandler handler;
  late FakeHabitRepository habitRepository;
  late FakeHabitRecordRepository habitRecordRepository;
  late FakeHabitTimeRecordRepository habitTimeRecordRepository;

  setUp(() {
    AppDatabase.resetInstance();
    AppDatabase.setInstanceForTesting(AppDatabase.forTesting());

    habitRepository = FakeHabitRepository();
    habitRecordRepository = FakeHabitRecordRepository();
    habitTimeRecordRepository = FakeHabitTimeRecordRepository();

    handler = CompleteHabitCommandHandler(
      habitRepository: habitRepository,
      habitRecordRepository: habitRecordRepository,
      habitTimeRecordRepository: habitTimeRecordRepository,
    );
  });

  tearDown(() async {
    await AppDatabase.instance().close();
    AppDatabase.resetInstance();
  });

  group('single occurrence habit', () {
    const habitId = 'habit-single';
    final date = DateTime(2026, 1, 11, 9);

    setUp(() {
      habitRepository.setHabit(Habit(
        id: habitId,
        createdDate: DateTime.now(),
        name: 'Single Habit',
        description: 'Test',
        hasGoal: false,
      ));
    });

    test('adds a complete record when there is no record for the day', () async {
      await handler.call(CompleteHabitCommand(habitId: habitId, date: date));

      expect(habitRecordRepository.records.length, 1);
      expect(habitRecordRepository.records.first.status, HabitRecordStatus.complete);
      expect(habitRecordRepository.addCount, 1);
    });

    test('keeps an existing complete record unchanged', () async {
      final existingRecord = HabitRecord(
        id: 'record-1',
        habitId: habitId,
        occurredAt: date.toUtc(),
        status: HabitRecordStatus.complete,
        createdDate: DateTime.now(),
      );
      habitRecordRepository.records.add(existingRecord);

      await handler.call(CompleteHabitCommand(habitId: habitId, date: date));

      expect(habitRecordRepository.records, [existingRecord]);
      expect(habitRecordRepository.addCount, 0);
      expect(habitRecordRepository.deleteCount, 0);
    });

    test('replaces not done with complete', () async {
      habitRecordRepository.records.add(HabitRecord(
        id: 'record-1',
        habitId: habitId,
        occurredAt: date.toUtc(),
        status: HabitRecordStatus.notDone,
        createdDate: DateTime.now(),
      ));

      await handler.call(CompleteHabitCommand(habitId: habitId, date: date));

      expect(habitRecordRepository.records.length, 1);
      expect(habitRecordRepository.records.first.status, HabitRecordStatus.complete);
      expect(habitRecordRepository.addCount, 1);
      expect(habitRecordRepository.deleteCount, 1);
    });
  });

  group('multi occurrence habit', () {
    const habitId = 'habit-multi';
    final date = DateTime(2026, 1, 11, 9);

    setUp(() {
      habitRepository.setHabit(Habit(
        id: habitId,
        createdDate: DateTime.now(),
        name: 'Multi Habit',
        description: 'Test',
        hasGoal: true,
        dailyTarget: 2,
        periodDays: 1,
        targetFrequency: 1,
      ));
    });

    test('adds one complete record when target is not met', () async {
      habitRecordRepository.records.add(HabitRecord(
        id: 'record-1',
        habitId: habitId,
        occurredAt: date.toUtc(),
        status: HabitRecordStatus.complete,
        createdDate: DateTime.now(),
      ));

      await handler.call(CompleteHabitCommand(habitId: habitId, date: date));

      expect(habitRecordRepository.records.length, 2);
      expect(habitRecordRepository.records.every((record) => record.status == HabitRecordStatus.complete), true);
      expect(habitRecordRepository.addCount, 1);
    });

    test('does not add another record when target is already met', () async {
      habitRecordRepository.records.addAll([
        HabitRecord(
          id: 'record-1',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.complete,
          createdDate: DateTime.now(),
        ),
        HabitRecord(
          id: 'record-2',
          habitId: habitId,
          occurredAt: date.toUtc(),
          status: HabitRecordStatus.complete,
          createdDate: DateTime.now(),
        ),
      ]);

      await handler.call(CompleteHabitCommand(habitId: habitId, date: date));

      expect(habitRecordRepository.records.length, 2);
      expect(habitRecordRepository.addCount, 0);
      expect(habitRecordRepository.deleteCount, 0);
    });

    test('clears not done and adds complete when target is not met', () async {
      habitRecordRepository.records.add(HabitRecord(
        id: 'record-1',
        habitId: habitId,
        occurredAt: date.toUtc(),
        status: HabitRecordStatus.notDone,
        createdDate: DateTime.now(),
      ));

      await handler.call(CompleteHabitCommand(habitId: habitId, date: date));

      expect(habitRecordRepository.records.length, 1);
      expect(habitRecordRepository.records.first.status, HabitRecordStatus.complete);
      expect(habitRecordRepository.addCount, 1);
      expect(habitRecordRepository.deleteCount, 1);
    });
  });

  test('adds estimated time only when a new complete record is added', () async {
    const habitId = 'habit-estimated';
    final date = DateTime(2026, 1, 11, 9);
    habitRepository.setHabit(Habit(
      id: habitId,
      createdDate: DateTime.now(),
      name: 'Estimated Habit',
      description: 'Test',
      estimatedTime: 15,
      hasGoal: false,
    ));

    await handler.call(CompleteHabitCommand(habitId: habitId, date: date));
    await handler.call(CompleteHabitCommand(habitId: habitId, date: date));

    expect(habitRecordRepository.records.length, 1);
    expect(habitTimeRecordRepository.records.length, 1);
    expect(habitTimeRecordRepository.records.first.duration, 15 * 60);
  });
}
