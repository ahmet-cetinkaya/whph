import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/core/application/features/habits/services/habit_time_record_service.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
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
  final IHabitTimeRecordRepository _habitTimeRecordRepository;

  CompleteHabitCommandHandler({
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTimeRecordRepository habitTimeRecordRepository,
  })  : _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _habitTimeRecordRepository = habitTimeRecordRepository;

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
        await _clearNonCompleteRecords(dayRecords);

        if (completeRecords.length < dailyTarget) {
          await _addCompleteRecord(habit, request.habitId, request.date);
        }
        return;
      }

      if (completeRecords.isNotEmpty) {
        await _keepOnlyFirstCompleteRecord(dayRecords, completeRecords.first);
        return;
      }

      await _clearRecords(dayRecords);
      await _addCompleteRecord(habit, request.habitId, request.date);
    });

    return CompleteHabitCommandResponse();
  }

  Future<void> _addCompleteRecord(Habit habit, String habitId, DateTime date) async {
    final occurredAt = DateTimeHelper.toUtcDateTime(date);
    await _habitRecordRepository.add(HabitRecord(
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now().toUtc(),
      habitId: habitId,
      occurredAt: occurredAt,
      status: HabitRecordStatus.complete,
    ));

    if (habit.estimatedTime != null && habit.estimatedTime! > 0) {
      await HabitTimeRecordService.addEstimatedDurationToHabitTimeRecord(
        repository: _habitTimeRecordRepository,
        habitId: habitId,
        targetDate: occurredAt,
        estimatedDuration: (habit.estimatedTime! * 60).toInt(),
      );
    }
  }

  Future<void> _clearNonCompleteRecords(List<HabitRecord> records) async {
    for (final record in records.where((record) => record.status != HabitRecordStatus.complete)) {
      await _habitRecordRepository.delete(record);
    }
  }

  Future<void> _keepOnlyFirstCompleteRecord(List<HabitRecord> records, HabitRecord completeRecordToKeep) async {
    for (final record in records) {
      if (record.id != completeRecordToKeep.id) {
        await _habitRecordRepository.delete(record);
      }
    }
  }

  Future<void> _clearRecords(List<HabitRecord> records) async {
    for (final record in records) {
      await _habitRecordRepository.delete(record);
    }
  }
}
