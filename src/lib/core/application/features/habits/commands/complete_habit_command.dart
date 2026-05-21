import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/core/application/features/habits/services/habit_record_operations_service.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

class CompleteHabitCommand implements IRequest<CompleteHabitCommandResponse> {
  final String habitId;
  final DateTime date;

  CompleteHabitCommand({
    required this.habitId,
    required this.date,
  });
}

class CompleteHabitCommandResponse {}

class CompleteHabitCommandHandler implements IRequestHandler<CompleteHabitCommand, CompleteHabitCommandResponse> {
  final IHabitRepository _habitRepository;
  final IHabitRecordRepository _habitRecordRepository;
  final HabitRecordOperationsService _operationsService;

  CompleteHabitCommandHandler({
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required HabitRecordOperationsService operationsService,
  })  : _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _operationsService = operationsService;

  @override
  Future<CompleteHabitCommandResponse> call(CompleteHabitCommand request) async {
    final targetDate = DateTimeHelper.toLocalDateTime(request.date);
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day).toUtc();
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

    await AppDatabase.instance().transaction(() async {
      final habit = await _habitRepository.getById(request.habitId);
      if (habit == null) {
        throw BusinessException(
          'Habit not found',
          HabitTranslationKeys.habitNotFoundError,
          args: {'habitId': request.habitId},
        );
      }

      final habitRecords = await _habitRecordRepository.getListByHabitIdAndRangeDate(
        request.habitId,
        startOfDay,
        endOfDay,
        0,
        1000,
      );

      final dayRecords = habitRecords.items;
      final completeRecords = dayRecords.where((record) => record.status == HabitRecordStatus.complete).toList();
      final dailyTarget = habit.getDailyTarget();
      final isMultiOccurrence = habit.hasGoal && dailyTarget > 1;

      if (isMultiOccurrence) {
        await _clearNonCompleteRecords(request.habitId, startOfDay, endOfDay, dayRecords);

        if (completeRecords.length < dailyTarget) {
          await _addCompleteRecord(habit, request.habitId, request.date);
        }
        return;
      }

      if (completeRecords.isNotEmpty) {
        await _keepOnlyFirstCompleteRecord(request.habitId, startOfDay, endOfDay, dayRecords, completeRecords.first);
        return;
      }

      await _clearRecords(request.habitId, startOfDay, endOfDay, dayRecords);
      await _addCompleteRecord(habit, request.habitId, request.date);
    });

    return CompleteHabitCommandResponse();
  }

  Future<void> _addCompleteRecord(Habit habit, String habitId, DateTime date) async {
    final occurredAt = DateTimeHelper.toUtcDateTime(date);
    final now = DateTime.now().toUtc();

    await _operationsService.addHabitRecord(
      habitId,
      occurredAt,
      HabitRecordStatus.complete,
      now,
    );

    await _operationsService.addTimeRecordIfComplete(
      habit,
      habitId,
      occurredAt,
      HabitRecordStatus.complete,
    );
  }

  Future<void> _clearNonCompleteRecords(
      String habitId, DateTime startOfDay, DateTime endOfDay, List<HabitRecord> records) async {
    final nonCompleteRecords = records.where((record) => record.status != HabitRecordStatus.complete).toList();
    if (nonCompleteRecords.isNotEmpty) {
      await _operationsService.clearAllRecordsForDay(habitId, startOfDay, endOfDay, nonCompleteRecords);
    }
  }

  Future<void> _keepOnlyFirstCompleteRecord(String habitId, DateTime startOfDay, DateTime endOfDay,
      List<HabitRecord> records, HabitRecord completeRecordToKeep) async {
    final recordsToDelete = records.where((record) => record.id != completeRecordToKeep.id).toList();
    if (recordsToDelete.isNotEmpty) {
      await _operationsService.clearAllRecordsForDay(habitId, startOfDay, endOfDay, recordsToDelete);
    }
  }

  Future<void> _clearRecords(String habitId, DateTime startOfDay, DateTime endOfDay, List<HabitRecord> records) async {
    if (records.isNotEmpty) {
      await _operationsService.clearAllRecordsForDay(habitId, startOfDay, endOfDay, records);
    }
  }
}
