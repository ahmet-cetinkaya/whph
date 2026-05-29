// ignore_for_file: unused_local_variable

import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/habit_record_operations_service.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:acore/acore.dart';

import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

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
  final ISettingRepository _settingsRepository;
  final HabitRecordOperationsService _operationsService;

  ToggleHabitCompletionCommandHandler({
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required ISettingRepository settingsRepository,
    required HabitRecordOperationsService operationsService,
  })  : _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _settingsRepository = settingsRepository,
        _operationsService = operationsService;

  @override
  Future<ToggleHabitCompletionCommandResponse> call(ToggleHabitCompletionCommand request) async {
    final habit = await _habitRepository.getById(request.habitId);
    if (habit == null) {
      throw BusinessException(
        'Habit not found',
        HabitTranslationKeys.habitNotFoundError,
        args: {'habitId': request.habitId},
      );
    }

    final targetDate = DateTimeHelper.toLocalDateTime(request.date);
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day).toUtc();
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

    final habitRecords = await _habitRecordRepository.getListByHabitIdAndRangeDate(
      request.habitId,
      startOfDay,
      endOfDay,
      0,
      1000,
    );

    final dailyCompletionCount = habitRecords.items
        .where((record) => DateTimeHelper.isSameDay(
            DateTimeHelper.toLocalDateTime(record.occurredAt), DateTimeHelper.toLocalDateTime(request.date)))
        .length;

    final hasCustomGoals = habit.hasGoal;
    final dailyTarget = hasCustomGoals ? (habit.dailyTarget ?? 1) : 1;

    HabitRecordStatus nextStatus = HabitRecordStatus.complete;
    bool isMultiOccurrence = hasCustomGoals && dailyTarget > 1;

    final setting = await _settingsRepository.getByKey(SettingKeys.habitThreeStateEnabled);
    final isThreeStateEnabled = setting != null && setting.getValue<bool>() == true;

    if (isMultiOccurrence) {
      // Check if explicitly marked as Not Done for this specific day
      final isCurrentlyNotDone = habitRecords.items.any((r) =>
          r.status == HabitRecordStatus.notDone &&
          DateTimeHelper.isSameDay(
              DateTimeHelper.toLocalDateTime(r.occurredAt), DateTimeHelper.toLocalDateTime(request.date)));

      if (isCurrentlyNotDone) {
        nextStatus = HabitRecordStatus.skipped;
      } else if (dailyCompletionCount < dailyTarget) {
        nextStatus = HabitRecordStatus.complete;
      } else {
        // Target met. If 3-state enabled: Not Done, otherwise: Reset (Skipped)
        nextStatus = isThreeStateEnabled ? HabitRecordStatus.notDone : HabitRecordStatus.skipped;
      }
    } else {
      // Single occurrence: 3-state cycle when enabled
      final existingRecord = habitRecords.items
          .where((record) => DateTimeHelper.isSameDay(
              DateTimeHelper.toLocalDateTime(record.occurredAt), DateTimeHelper.toLocalDateTime(request.date)))
          .firstOrNull;

      final currentStatus = existingRecord?.status ?? HabitRecordStatus.skipped;

      switch (currentStatus) {
        case HabitRecordStatus.skipped:
          nextStatus = HabitRecordStatus.complete;
          break;
        case HabitRecordStatus.complete:
          nextStatus = isThreeStateEnabled ? HabitRecordStatus.notDone : HabitRecordStatus.skipped;
          break;
        case HabitRecordStatus.notDone:
          nextStatus = HabitRecordStatus.skipped;
          break;
      }
    }

    final now = DateTime.now().toUtc();
    final occurredAt = DateTimeHelper.toUtcDateTime(request.date);

    await AppDatabase.instance().transaction(() async {
      if (!isMultiOccurrence) {
        // Clear existing records to ensure strict 1-to-1 state mapping
        await _operationsService.clearAllRecordsForDay(
            request.habitId, startOfDay, endOfDay, habitRecords.items.toList());

        if (nextStatus != HabitRecordStatus.skipped) {
          await _operationsService.addHabitRecord(
            request.habitId,
            occurredAt,
            nextStatus,
            now,
          );

          await _operationsService.addTimeRecordIfComplete(
            habit,
            request.habitId,
            occurredAt,
            nextStatus,
          );
        }
      } else {
        if (nextStatus == HabitRecordStatus.complete) {
          await _operationsService.addHabitRecord(
            request.habitId,
            occurredAt,
            HabitRecordStatus.complete,
            now,
          );

          await _operationsService.addTimeRecordIfComplete(
            habit,
            request.habitId,
            occurredAt,
            HabitRecordStatus.complete,
          );
        } else if (nextStatus == HabitRecordStatus.notDone) {
          await _operationsService.clearAllRecordsForDay(
              request.habitId, startOfDay, endOfDay, habitRecords.items.toList());

          await _operationsService.addHabitRecord(
            request.habitId,
            occurredAt,
            HabitRecordStatus.notDone,
            now,
          );
        } else {
          await _operationsService.clearAllRecordsForDay(
              request.habitId, startOfDay, endOfDay, habitRecords.items.toList());
        }
      }
    });

    return ToggleHabitCompletionCommandResponse();
  }
}
