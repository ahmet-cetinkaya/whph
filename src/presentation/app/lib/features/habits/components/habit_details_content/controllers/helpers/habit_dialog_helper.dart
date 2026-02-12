import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show DateTimeHelper, ResponsiveDialogHelper, DialogSize;
import 'package:application/features/habits/queries/get_habit_query.dart';
import 'package:whph/features/habits/components/habit_goal_dialog.dart';
import 'package:whph/features/habits/components/habit_reminder_settings_dialog.dart';
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';

class ReminderDialogResult {
  final bool hasReminder;
  final TimeOfDay? reminderTime;
  final List<int> reminderDays;

  ReminderDialogResult({
    required this.hasReminder,
    this.reminderTime,
    required this.reminderDays,
  });
}

class GoalDialogResult {
  final bool hasGoal;
  final int? targetFrequency;
  final int? periodDays;
  final int? dailyTarget;

  GoalDialogResult({
    required this.hasGoal,
    this.targetFrequency,
    this.periodDays,
    this.dailyTarget,
  });
}

class HabitDialogHelper {
  final ITranslationService _translationService;

  HabitDialogHelper({required ITranslationService translationService}) : _translationService = translationService;

  String getReminderSummaryText(GetHabitQueryResponse? habit) {
    if (habit == null || !habit.hasReminder) {
      return _translationService.translate(HabitTranslationKeys.noReminder);
    }

    String summary = "";

    if (habit.reminderTime != null) {
      final timeOfDay = habit.getReminderTimeOfDay();
      if (timeOfDay != null) {
        summary += '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';
      }
    }

    final reminderDays = habit.getReminderDaysAsList();
    if (reminderDays.isNotEmpty && reminderDays.length < 7) {
      final dayNames = reminderDays.map((dayNum) {
        return _translationService.translate(SharedTranslationKeys.getWeekDayTranslationKey(dayNum, short: true));
      }).join(', ');
      summary += ', $dayNames';
    } else if (reminderDays.length == 7) {
      summary += ', ${_translationService.translate(HabitTranslationKeys.everyDay)}';
    }

    return summary;
  }

  Future<ReminderDialogResult?> openReminderDialog(BuildContext context, GetHabitQueryResponse habit) async {
    final now = DateTime.now();
    final bool isArchived =
        habit.archivedDate != null && DateTimeHelper.toLocalDateTime(habit.archivedDate!).isBefore(now);

    if (isArchived) return null;

    final result = await ResponsiveDialogHelper.showResponsiveDialog<HabitReminderSettingsResult>(
      context: context,
      size: DialogSize.large,
      child: HabitReminderSettingsDialog(
        hasReminder: habit.hasReminder,
        reminderTime: habit.getReminderTimeOfDay(),
        reminderDays: habit.getReminderDaysAsList(),
        translationService: _translationService,
      ),
    );

    if (result != null) {
      return ReminderDialogResult(
        hasReminder: result.hasReminder,
        reminderTime: result.reminderTime,
        reminderDays: result.reminderDays,
      );
    }
    return null;
  }

  Future<GoalDialogResult?> openGoalDialog(BuildContext context, GetHabitQueryResponse habit) async {
    final now = DateTime.now();
    final bool isArchived =
        habit.archivedDate != null && DateTimeHelper.toLocalDateTime(habit.archivedDate!).isBefore(now);

    if (isArchived) return null;

    final result = await ResponsiveDialogHelper.showResponsiveDialog<HabitGoalResult>(
      context: context,
      size: DialogSize.xLarge,
      child: HabitGoalDialog(
        hasGoal: habit.hasGoal,
        targetFrequency: habit.targetFrequency,
        periodDays: habit.hasGoal ? habit.periodDays : 1,
        dailyTarget: habit.dailyTarget ?? 1,
        translationService: _translationService,
      ),
    );

    if (result != null) {
      return GoalDialogResult(
        hasGoal: result.hasGoal,
        targetFrequency: result.targetFrequency,
        periodDays: result.periodDays,
        dailyTarget: result.dailyTarget,
      );
    }
    return null;
  }
}
