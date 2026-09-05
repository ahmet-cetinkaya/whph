import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/commands/complete_habit_command.dart';
import 'package:whph/core/application/features/habits/services/habit_record_operations_service.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';

class NotificationHabitRepository extends Fake implements IHabitRepository {
  final Map<String, Habit> _habits = {};

  void addHabit(Habit habit) => _habits[habit.id] = habit;

  @override
  Future<Habit?> getById(String id, {bool includeDeleted = false}) async => _habits[id];
}

class NotificationHabitRecordRepository extends Fake implements IHabitRecordRepository {
  final List<HabitRecord> records = [];

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
  Future<void> add(HabitRecord record) async => records.add(record);

  @override
  Future<void> delete(HabitRecord record) async {
    records.removeWhere((existingRecord) => existingRecord.id == record.id);
  }
}

class NotificationHabitTimeRecordRepository extends Fake implements IHabitTimeRecordRepository {
  @override
  Future<List<HabitTimeRecord>> getByHabitIdAndDateRange(
    String habitId,
    DateTime start,
    DateTime end,
  ) async =>
      [];
}

class NotificationHabitMediator extends Mediator {
  final CompleteHabitCommandHandler _handler;

  NotificationHabitMediator({
    required NotificationHabitRepository habitRepository,
    required NotificationHabitRecordRepository habitRecordRepository,
  })  : _handler = CompleteHabitCommandHandler(
          habitRepository: habitRepository,
          habitRecordRepository: habitRecordRepository,
          operationsService: HabitRecordOperationsService(
            habitRecordRepository: habitRecordRepository,
            habitTimeRecordRepository: NotificationHabitTimeRecordRepository(),
          ),
        ),
        super(Pipeline());

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    if (T == CompleteHabitCommand) {
      final command = (request as Object) as CompleteHabitCommand;
      return await _handler(command) as R;
    }
    throw UnsupportedError('Unsupported notification test command: ${request.runtimeType}');
  }
}
