// ignore_for_file: unused_local_variable

import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/habits/services/habit_time_record_service.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:acore/acore.dart';

import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';

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
  final ISettingRepository _settingsRepository;

  ToggleHabitCompletionCommandHandler({
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTimeRecordRepository habitTimeRecordRepository,
    required ISettingRepository settingsRepository,
  })  : _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _habitTimeRecordRepository = habitTimeRecordRepository,
        _settingsRepository = settingsRepository;

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
    HabitRecordStatus nextStatus = HabitRecordStatus.complete;
    bool isMultiOccurrence = hasCustomGoals && dailyTarget > 1;

    final setting = await _settingsRepository.getByKey(SettingKeys.habitThreeStateEnabled);
    // Fix: Check for null and cast strictly to bool if value exists, otherwise default to false
    final isThreeStateEnabled = setting != null && setting.getValue<bool>() == true;

    if (isMultiOccurrence) {
      // Check if explicitly marked as Not Done
      // Check if explicitly marked as Not Done for this specific day
      final isCurrentlyNotDone = habitRecords.items.any((r) =>
          r.status == HabitRecordStatus.notDone &&
          DateTimeHelper.isSameDay(
              DateTimeHelper.toLocalDateTime(r.occurredAt), DateTimeHelper.toLocalDateTime(request.date)));

      if (isCurrentlyNotDone) {
        // If currently Not Done, toggle to Unknown (Reset)
        nextStatus = HabitRecordStatus.unknown;
      } else if (dailyCompletionCount < dailyTarget) {
        // If target not reached, Increment (Add Complete)
        nextStatus = HabitRecordStatus.complete;
      } else {
        // Target met/exceeded. Next step depends on setting.
        // If 3-state enabled: Go to Not Done.
        // Else: Go to Unknown (Reset).
        // Note: We already checked isCurrentlyNotDone above, so we know we are NOT currently NotDone.
        nextStatus = isThreeStateEnabled ? HabitRecordStatus.notDone : HabitRecordStatus.unknown;
      }
    } else {
      // Single occurrence habit: 3-state cycle (if enabled)
      // Find the existing record for today (if any)
      final existingRecord = habitRecords.items
          .where((record) => DateTimeHelper.isSameDay(
              DateTimeHelper.toLocalDateTime(record.occurredAt), DateTimeHelper.toLocalDateTime(request.date)))
          .firstOrNull;

      final currentStatus = existingRecord?.status ?? HabitRecordStatus.unknown;

      switch (currentStatus) {
        case HabitRecordStatus.unknown:
          nextStatus = HabitRecordStatus.complete;
          break;
        case HabitRecordStatus.complete:
          nextStatus = isThreeStateEnabled ? HabitRecordStatus.notDone : HabitRecordStatus.unknown;
          break;
        case HabitRecordStatus.notDone:
          nextStatus = HabitRecordStatus.unknown;
          break;
      }
    }

    // Prepare common variables
    final now = DateTime.now().toUtc();
    final occurredAt = DateTimeHelper.toUtcDateTime(request.date);

    // clear existing records and time records first (clean slate approach)
    if (!isMultiOccurrence) {
      // Only clear for single occurrence habits where we are replacing the state
      // For multi-occurrence, we might be adding a NEW record, not replacing.
      // WAIT. The original logic for multi-occurrence was:
      // if shouldComplete -> Add record.
      // else -> DELETE ALL records.

      // This implies "reset" behavior when "unchecking" via toggle?
      // Original code:
      // else { // Remove all habit records and time records for the day }

      // If dailyTarget is 5, and I have 4. Tapping again makes it 5.
      // Tapping again (if logic falls to else?)
      // "shouldComplete = dailyCompletionCount < dailyTarget"
      // If count is 5, shouldComplete is false. -> DELETE ALL 5 records.

      // So "reset" behavior is standard for the "Calendar behavior" logic?
      // "Checkbox behavior: increment until target, then reset" -> Yes.

      // Always clear existing records for single-occurrence logic to ensure strict 1-to-1 state mapping
      for (final habitRecord in habitRecords.items.toList()) {
        await _habitRecordRepository.delete(habitRecord);
      }

      final timeRecords = await _habitTimeRecordRepository.getByHabitIdAndDateRange(
        request.habitId,
        startOfDay,
        endOfDay,
      );
      for (final timeRecord in timeRecords) {
        await _habitTimeRecordRepository.delete(timeRecord);
      }

      if (nextStatus != HabitRecordStatus.unknown) {
        // Add new record
        final habitRecord = HabitRecord(
          id: KeyHelper.generateStringId(),
          createdDate: now,
          habitId: request.habitId,
          occurredAt: occurredAt,
          status: nextStatus,
        );
        await _habitRecordRepository.add(habitRecord);

        // Add time record ONLY if complete
        if (nextStatus == HabitRecordStatus.complete && habit.estimatedTime != null && habit.estimatedTime! > 0) {
          await HabitTimeRecordService.addEstimatedDurationToHabitTimeRecord(
            repository: _habitTimeRecordRepository,
            habitId: request.habitId,
            targetDate: occurredAt,
            estimatedDuration: (habit.estimatedTime! * 60).toInt(),
          );
        }
      }
    } else {
      // Multi-occurrence logic (legacy behavior preserved but adapted structure)
      if (nextStatus == HabitRecordStatus.complete) {
        // Add ONE record
        final habitRecord = HabitRecord(
          id: KeyHelper.generateStringId(),
          createdDate: now,
          habitId: request.habitId,
          occurredAt: occurredAt,
          status: HabitRecordStatus.complete,
        );
        await _habitRecordRepository.add(habitRecord);

        if (habit.estimatedTime != null && habit.estimatedTime! > 0) {
          await HabitTimeRecordService.addEstimatedDurationToHabitTimeRecord(
            repository: _habitTimeRecordRepository,
            habitId: request.habitId,
            targetDate: occurredAt,
            estimatedDuration: (habit.estimatedTime! * 60).toInt(),
          );
        }
      } else if (nextStatus == HabitRecordStatus.notDone) {
        // Switch to Not Done - Clear all existing attempts first
        for (final habitRecord in habitRecords.items.toList()) {
          await _habitRecordRepository.delete(habitRecord);
        }
        final timeRecords = await _habitTimeRecordRepository.getByHabitIdAndDateRange(
          request.habitId,
          startOfDay,
          endOfDay,
        );
        for (final timeRecord in timeRecords) {
          await _habitTimeRecordRepository.delete(timeRecord);
        }

        // Add ONE Not Done record
        final habitRecord = HabitRecord(
          id: KeyHelper.generateStringId(),
          createdDate: now,
          habitId: request.habitId,
          occurredAt: occurredAt,
          status: HabitRecordStatus.notDone,
        );
        await _habitRecordRepository.add(habitRecord);
      } else {
        // Reset (Unknown) - Clear all
        for (final habitRecord in habitRecords.items.toList()) {
          await _habitRecordRepository.delete(habitRecord);
        }
        final timeRecords = await _habitTimeRecordRepository.getByHabitIdAndDateRange(
          request.habitId,
          startOfDay,
          endOfDay,
        );
        for (final timeRecord in timeRecords) {
          await _habitTimeRecordRepository.delete(timeRecord);
        }
      }
    }

    return ToggleHabitCompletionCommandResponse();
  }
}
