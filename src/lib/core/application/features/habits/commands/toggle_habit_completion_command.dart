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
    // Validate that the habit exists and fetch its details
    final habit = await _habitRepository.getById(request.habitId);
    if (habit == null) {
      throw BusinessException(
        'Habit not found',
        HabitTranslationKeys.habitNotFoundError,
        args: {'habitId': request.habitId},
      );
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
    HabitRecordStatus nextStatus = HabitRecordStatus.complete;
    bool isMultiOccurrence = hasCustomGoals && dailyTarget > 1;

    final setting = await _settingsRepository.getByKey(SettingKeys.habitThreeStateEnabled);
    final isThreeStateEnabled = setting != null && setting.getValue<bool>() == true;

    if (isMultiOccurrence) {
      // Check if explicitly marked as Not Done
      // Check if explicitly marked as Not Done for this specific day
      final isCurrentlyNotDone = habitRecords.items.any((r) =>
          r.status == HabitRecordStatus.notDone &&
          DateTimeHelper.isSameDay(
              DateTimeHelper.toLocalDateTime(r.occurredAt), DateTimeHelper.toLocalDateTime(request.date)));

      if (isCurrentlyNotDone) {
        // If currently Not Done, toggle to Skipped (Reset)
        nextStatus = HabitRecordStatus.skipped;
      } else if (dailyCompletionCount < dailyTarget) {
        // If target not reached, Increment (Add Complete)
        nextStatus = HabitRecordStatus.complete;
      } else {
        // Target met/exceeded. Next step depends on setting.
        // If 3-state enabled: Go to Not Done.
        // Else: Go to Skipped (Reset).
        nextStatus = isThreeStateEnabled ? HabitRecordStatus.notDone : HabitRecordStatus.skipped;
      }
    } else {
      // Single occurrence habit: 3-state cycle (if enabled)
      // Find the existing record for today (if any)
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

    // Prepare common variables
    final now = DateTime.now().toUtc();
    final occurredAt = DateTimeHelper.toUtcDateTime(request.date);

    // clear existing records and time records first (clean slate approach)
    await AppDatabase.instance().transaction(() async {
      if (!isMultiOccurrence) {
        // Only clear for single occurrence habits where we are replacing the state
        // Always clear existing records for single-occurrence logic to ensure strict 1-to-1 state mapping
        await _operationsService.clearAllRecordsForDay(
            request.habitId, startOfDay, endOfDay, habitRecords.items.toList());

        if (nextStatus != HabitRecordStatus.skipped) {
          // Add new record
          await _operationsService.addHabitRecord(
            request.habitId,
            occurredAt,
            nextStatus,
            now,
          );

          // Add time record ONLY if complete
          await _operationsService.addTimeRecordIfComplete(
            habit,
            request.habitId,
            occurredAt,
            nextStatus,
          );
        }
      } else {
        if (nextStatus == HabitRecordStatus.complete) {
          // Add ONE record
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
          // Switch to Not Done - Clear all existing attempts first
          await _operationsService.clearAllRecordsForDay(
              request.habitId, startOfDay, endOfDay, habitRecords.items.toList());

          // Add ONE Not Done record
          await _operationsService.addHabitRecord(
            request.habitId,
            occurredAt,
            HabitRecordStatus.notDone,
            now,
          );
        } else {
          // Reset (Skipped) - Clear all
          await _operationsService.clearAllRecordsForDay(
              request.habitId, startOfDay, endOfDay, habitRecords.items.toList());
        }
      }
    });

    return ToggleHabitCompletionCommandResponse();
  }
}
