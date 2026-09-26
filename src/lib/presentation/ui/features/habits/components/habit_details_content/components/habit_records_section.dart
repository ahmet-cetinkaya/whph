import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/presentation/ui/features/habits/utils/habit_day_presenter.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';

/// Builds the records header and daily record button for habit details.
class HabitRecordsSection {
  static Widget buildDailyRecordButton({
    required BuildContext context,
    required int dailyCompletionCount,
    required HabitRecordStatus todayStatus,
    required bool hasCustomGoals,
    required int dailyTarget,
    required bool isArchived,
    required ITranslationService translationService,
    required IThemeService themeService,
    required VoidCallback? onToggle,
    required HabitType habitType,
    required String habitId,
    DateTime? createdDate,
    DateTime? archivedDate,
    List<HabitRecordListItem>? records,
    bool isThreeStateEnabled = false,
  }) {
    // Bad habits are binary (avoided vs. performed) and never produce a
    // "complete" record, so they need their own icon/tooltip mapping -
    // reusing the same presenter the habit list's checkbox already relies on
    // keeps both surfaces consistent instead of falling through to the
    // good-habit switch below (which would show a red X for both states).
    if (habitType == HabitType.bad) {
      return _buildBadHabitButton(
        habitId: habitId,
        createdDate: createdDate,
        archivedDate: archivedDate,
        records: records,
        isArchived: isArchived,
        translationService: translationService,
        themeService: themeService,
        onToggle: onToggle,
      );
    }

    final bool isDailyGoalMet =
        hasCustomGoals ? (dailyCompletionCount >= dailyTarget) : (todayStatus == HabitRecordStatus.complete);
    final bool hasRecords = dailyCompletionCount > 0 || todayStatus != HabitRecordStatus.skipped;

    final tooltipText = isArchived
        ? translationService.translate(HabitTranslationKeys.archivedStatus)
        : (hasCustomGoals && isDailyGoalMet)
            ? translationService.translate(HabitTranslationKeys.removeRecordTooltip)
            : translationService.translate(HabitTranslationKeys.createRecordTooltip);

    IconData icon;
    Color iconColor;

    if (isArchived) {
      icon = Icons.close;
      iconColor = Colors.grey;
    } else if (hasCustomGoals && isDailyGoalMet) {
      icon = Icons.link;
      iconColor = Colors.green;
    } else if (hasCustomGoals && dailyTarget > 1 && dailyCompletionCount > 0) {
      icon = Icons.add;
      iconColor = Colors.blue;
    } else {
      // Simple habit or goal not started/met
      switch (todayStatus) {
        case HabitRecordStatus.complete:
          icon = Icons.link;
          iconColor = Colors.green;
          break;
        case HabitRecordStatus.notDone:
          icon = Icons.close;
          iconColor = Colors.red;
          break;
        case HabitRecordStatus.skipped:
          // Standardize on using Question Mark for skipped/start state
          if (isThreeStateEnabled) {
            icon = Icons.question_mark;
            iconColor = themeService.textColor.withValues(alpha: 0.5);
          } else {
            icon = Icons.close;
            iconColor = Colors.red.withValues(alpha: 0.7);
          }
          break;
      }
    }

    // Override for old behavior compatibility if needed?
    // If hasCustomGoals and no records, it fell through to Red Close.
    // Now falls to switch. skipped -> fiber_manual_record_outlined.

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: themeService.primaryColor.withValues(alpha: isArchived ? 0.05 : 0.1),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              size: AppTheme.fontSizeLarge,
              color: iconColor,
            ),
            onPressed: isArchived
                ? null
                : () {
                    onToggle?.call();
                  },
            tooltip: tooltipText,
          ),
        ),
        if (hasCustomGoals && dailyTarget > 1 && !isArchived && dailyCompletionCount > 0)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isDailyGoalMet
                    ? Colors.green
                    : hasRecords
                        ? Colors.orange
                        : Colors.red.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '$dailyCompletionCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Bad habits are avoided-by-default: no record today means success, and a
  /// recorded slip is the failure - the reverse of a good habit's "complete"
  /// state. [HabitDayPresenter] already encodes this (and is what the habit
  /// list's checkbox uses), so this reuses it instead of duplicating it.
  static Widget _buildBadHabitButton({
    required String habitId,
    required DateTime? createdDate,
    required DateTime? archivedDate,
    required List<HabitRecordListItem>? records,
    required bool isArchived,
    required ITranslationService translationService,
    required IThemeService themeService,
    required VoidCallback? onToggle,
  }) {
    final now = DateTime.now();
    final visual = HabitDayPresenter(
      habitId: habitId,
      habitType: HabitType.bad,
      createdDate: createdDate,
      archivedDate: archivedDate,
      records: records,
      now: now,
    ).visualFor(now);

    final icon = isArchived ? Icons.close : visual.icon;
    final iconColor = isArchived ? Colors.grey : visual.color;
    final isInteractive = !isArchived && visual.isInteractive;
    final tooltipText = isArchived
        ? translationService.translate(HabitTranslationKeys.archivedStatus)
        : translationService.translate(visual.actionKey);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: themeService.primaryColor.withValues(alpha: isArchived ? 0.05 : 0.1),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: AppTheme.fontSizeLarge,
          color: iconColor,
        ),
        onPressed: isInteractive ? () => onToggle?.call() : null,
        tooltip: tooltipText,
      ),
    );
  }
}
