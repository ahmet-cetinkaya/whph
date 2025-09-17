// ignore_for_file: unused_local_variable

import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/habits/services/habit_time_record_service.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:acore/acore.dart';

class ToggleHabitCompletionCommand implements IRequest<ToggleHabitCompletionCommandResponse> {
  final String habitId;
  final DateTime date;
  final bool useIncrementalBehavior;

  ToggleHabitCompletionCommand({
    required this.habitId,
    required this.date,
    this.useIncrementalBehavior = false,
  });
}

class ToggleHabitCompletionCommandResponse {}

class ToggleHabitCompletionCommandHandler
    implements IRequestHandler<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse> {
  final IHabitRepository _habitRepository;
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitTimeRecordRepository _habitTimeRecordRepository;

  ToggleHabitCompletionCommandHandler({
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTimeRecordRepository habitTimeRecordRepository,
  })  : _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _habitTimeRecordRepository = habitTimeRecordRepository;

  @override
  Future<ToggleHabitCompletionCommandResponse> call(ToggleHabitCompletionCommand request) async {
    // Validate that the habit exists and fetch its details
    final habit = await _habitRepository.getById(request.habitId);
    if (habit == null) {
      throw BusinessException('Habit not found', HabitTranslationKeys.habitNotFoundError);
    }

    // Normalize the date to start of day for consistent comparison
    final targetDate = DateTimeHelper.toLocalDateTime(request.date);
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day).toUtc();
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

    // Fetch existing habit records for the date
    final habitRecords = await _habitRecordRepository.getListByHabitIdAndRangeDate(
      request.habitId,
      startOfDay,
      endOfDay,
      0,
      1000, // Sufficient for a single day
    );

    // Count records for the specific date
    final dailyCompletionCount = habitRecords.items
        .where((record) => DateTimeHelper.isSameDay(
            DateTimeHelper.toLocalDateTime(record.occurredAt), DateTimeHelper.toLocalDateTime(request.date)))
        .length;

    final hasCustomGoals = habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (habit.dailyTarget ?? 1) : 1;

    // Determine action based on current completion status
    bool shouldComplete = false;
    if (hasCustomGoals && dailyTarget > 1) {
      // Multi-occurrence habit logic
      if (request.useIncrementalBehavior) {
        // Checkbox behavior: increment until target, then reset
        shouldComplete = dailyCompletionCount < dailyTarget;
      } else {
        // Calendar behavior: toggle between complete/incomplete
        shouldComplete = dailyCompletionCount < dailyTarget;
      }
    } else {
      // Traditional habit: simple toggle
      shouldComplete = dailyCompletionCount == 0;
    }

    if (shouldComplete) {
      // Add habit record
      final now = DateTime.now().toUtc();
      final occurredAt = DateTimeHelper.toUtcDateTime(request.date);

      final habitRecord = HabitRecord(
        id: KeyHelper.generateStringId(),
        createdDate: now,
        habitId: request.habitId,
        occurredAt: occurredAt,
      );
      await _habitRecordRepository.add(habitRecord);

      // Add estimated time if habit has it
      if (habit.estimatedTime != null && habit.estimatedTime! > 0) {
        await HabitTimeRecordService.addEstimatedDurationToHabitTimeRecord(
          repository: _habitTimeRecordRepository,
          habitId: request.habitId,
          targetDate: occurredAt,
          estimatedDuration: (habit.estimatedTime! * 60).toInt(),
        );
      }
    } else {
      // Remove all habit records and time records for the day
      for (final habitRecord in habitRecords.items) {
        await _habitRecordRepository.delete(habitRecord);
      }

      // Remove all time records for the day
      final timeRecords = await _habitTimeRecordRepository.getByHabitIdAndDateRange(
        request.habitId,
        startOfDay,
        endOfDay,
      );

      for (final timeRecord in timeRecords) {
        await _habitTimeRecordRepository.delete(timeRecord);
      }
    }

    return ToggleHabitCompletionCommandResponse();
  }
}
