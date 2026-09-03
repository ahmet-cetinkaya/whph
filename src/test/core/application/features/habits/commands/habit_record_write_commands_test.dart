import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/core/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/core/application/features/habits/services/habit_record_operations_service.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';

class FakeHabitRepository extends Fake implements IHabitRepository {
  FakeHabitRepository(this.habit);

  final Habit habit;

  @override
  Future<Habit?> getById(String id, {bool includeDeleted = false}) async => habit;
}

class FakeHabitRecordRepository extends Fake implements IHabitRecordRepository {
  final List<HabitRecord> records = [];

  @override
  Future<void> add(HabitRecord record) async => records.add(record);

  @override
  Future<void> delete(HabitRecord record) async => records.remove(record);

  @override
  Future<HabitRecord?> getById(String id, {bool includeDeleted = false}) async =>
      records.where((record) => record.id == id).firstOrNull;

  @override
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
    String habitId,
    DateTime startDate,
    DateTime endDate,
    int pageIndex,
    int pageSize,
  ) async {
    final matching = records.where((record) => record.habitId == habitId).toList();
    return PaginatedList(items: matching, totalItemCount: matching.length, pageIndex: pageIndex, pageSize: pageSize);
  }
}

class FakeHabitTimeRecordRepository extends Fake implements IHabitTimeRecordRepository {
  final List<HabitTimeRecord> records = [];

  @override
  Future<void> add(HabitTimeRecord record) async => records.add(record);

  @override
  Future<void> delete(HabitTimeRecord record) async => records.remove(record);

  @override
  Future<List<HabitTimeRecord>> getByHabitIdAndDateRange(String habitId, DateTime start, DateTime end) async => records;
}

void main() {
  final date = DateTime(2026, 1, 11, 9);

  test('add command creates one notDone marker without time for a bad habit', () async {
    // Given
    final habit = Habit(
      id: 'bad',
      createdDate: DateTime(2026, 1, 1),
      type: HabitType.bad,
      name: 'Avoid habit',
      description: 'Test',
      estimatedTime: 15,
    );
    final records = FakeHabitRecordRepository();
    final times = FakeHabitTimeRecordRepository();
    final handler = AddHabitRecordCommandHandler(
      habitRecordRepository: records,
      habitRepository: FakeHabitRepository(habit),
      operationsService: HabitRecordOperationsService(
        habitRecordRepository: records,
        habitTimeRecordRepository: times,
      ),
    );

    // When
    await handler.call(AddHabitRecordCommand(habitId: habit.id, occurredAt: date));
    await handler.call(AddHabitRecordCommand(habitId: habit.id, occurredAt: date));

    // Then
    expect(records.records.where((record) => record.status == HabitRecordStatus.notDone), hasLength(1));
    expect(times.records, isEmpty);
  });

  test('delete command removes only a bad notDone marker and preserves complete history', () async {
    // Given
    final habit = Habit(
      id: 'bad',
      createdDate: DateTime(2026, 1, 1),
      type: HabitType.bad,
      name: 'Avoid habit',
      description: 'Test',
    );
    final complete = HabitRecord(
      id: 'complete',
      habitId: habit.id,
      createdDate: date.toUtc(),
      occurredAt: date.toUtc(),
      status: HabitRecordStatus.complete,
    );
    final marker = HabitRecord(
      id: 'marker',
      habitId: habit.id,
      createdDate: date.toUtc(),
      occurredAt: date.toUtc(),
      status: HabitRecordStatus.notDone,
    );
    final records = FakeHabitRecordRepository()..records.addAll([complete, marker]);
    final handler = DeleteHabitRecordCommandHandler(
      habitRecordRepository: records,
      habitTimeRecordRepository: FakeHabitTimeRecordRepository(),
      habitRepository: FakeHabitRepository(habit),
    );

    // When
    await handler.call(DeleteHabitRecordCommand(id: marker.id));

    // Then
    expect(records.records, [complete]);
  });
}
