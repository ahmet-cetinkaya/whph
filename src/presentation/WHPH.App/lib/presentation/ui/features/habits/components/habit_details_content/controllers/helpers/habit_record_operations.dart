import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_time_record_command.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_time_record_command.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';

/// Handles record operations for habit details.
class HabitRecordOperations {
  final Mediator _mediator;
  final ITranslationService _translationService;
  final ISoundManagerService _soundManagerService;
  final HabitsService _habitsService;

  HabitRecordOperations({
    required Mediator mediator,
    required ITranslationService translationService,
    required ISoundManagerService soundManagerService,
    required HabitsService habitsService,
  })  : _mediator = mediator,
        _translationService = translationService,
        _soundManagerService = soundManagerService,
        _habitsService = habitsService;

  /// Toggles habit record status for a specific date.
  Future<void> toggleHabitRecord({
    required String habitId,
    required DateTime date,
    required BuildContext context,
    VoidCallback? onSuccess,
  }) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.updateHabitError),
      operation: () async {
        final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
        await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(command);
      },
      onSuccess: () {
        _soundManagerService.playHabitCompletion();
        // Notify both added/removed as status might change
        _habitsService.notifyHabitRecordAdded(habitId);
        onSuccess?.call();
      },
    );
  }

  /// Creates a habit record for a specific date.
  Future<void> createHabitRecord({
    required String habitId,
    required DateTime date,
    required BuildContext context,
    VoidCallback? onSuccess,
  }) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.creatingRecordError),
      operation: () async {
        final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
        await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(command);
      },
      onSuccess: () {
        _soundManagerService.playHabitCompletion();
        _habitsService.notifyHabitRecordAdded(habitId);
        onSuccess?.call();
      },
    );
  }

  /// Deletes all habit records for a specific day.
  Future<void> deleteAllHabitRecordsForDay({
    required DateTime date,
    required String habitId,
    required BuildContext context,
    VoidCallback? onSuccess,
  }) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.deletingRecordError),
      operation: () async {
        final command = ToggleHabitCompletionCommand(habitId: habitId, date: date, useIncrementalBehavior: false);
        await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(command);
      },
      onSuccess: () {
        _habitsService.notifyHabitRecordRemoved(habitId);
        onSuccess?.call();
      },
    );
  }

  /// Handles timer stop event.
  void onTimerStop(Duration totalElapsed, String habitId) {
    if (totalElapsed.inSeconds > 0) {
      final command = AddHabitTimeRecordCommand(
        habitId: habitId,
        duration: totalElapsed.inSeconds,
        customDateTime: DateTime.now(),
      );
      _mediator.send(command);
    }
  }

  /// Logs time for a habit.
  Future<void> logTime({
    required BuildContext context,
    required String habitId,
    required bool isSetTotalMode,
    required int durationInSeconds,
    required DateTime date,
  }) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      operation: () async {
        if (isSetTotalMode) {
          await _mediator.send(SaveHabitTimeRecordCommand(
            habitId: habitId,
            totalDuration: durationInSeconds,
            targetDate: date,
          ));
        } else {
          await _mediator.send(AddHabitTimeRecordCommand(
            habitId: habitId,
            duration: durationInSeconds,
            customDateTime: date,
          ));
        }
      },
      onSuccess: () {
        _habitsService.notifyHabitUpdated(habitId);
      },
    );
  }
}
