import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';

/// Builds the records header and daily record button for habit details.
class HabitRecordsSection {
  static Widget buildDailyRecordButton({
    required BuildContext context,
    required int dailyCompletionCount,
    required bool hasCustomGoals,
    required int dailyTarget,
    required bool isArchived,
    required ITranslationService translationService,
    required IThemeService themeService,
    required VoidCallback? onCreateRecord,
    required VoidCallback? onRemoveRecords,
  }) {
    final bool isDailyGoalMet = dailyCompletionCount >= dailyTarget;
    final bool hasRecords = dailyCompletionCount > 0;

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
    } else if (hasCustomGoals && dailyTarget > 1 && hasRecords) {
      icon = Icons.add;
      iconColor = Colors.blue;
    } else if (hasRecords) {
      icon = Icons.link;
      iconColor = hasCustomGoals ? Colors.orange : Colors.green;
    } else {
      icon = Icons.close;
      iconColor = Colors.red;
    }

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
                    if (hasCustomGoals && isDailyGoalMet) {
                      onRemoveRecords?.call();
                    } else if (!hasCustomGoals && hasRecords) {
                      onRemoveRecords?.call();
                    } else {
                      onCreateRecord?.call();
                    }
                  },
            tooltip: tooltipText,
          ),
        ),
        if (hasCustomGoals && dailyTarget > 1 && !isArchived && dailyCompletionCount > 0)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: isDailyGoalMet
                    ? Colors.green
                    : hasRecords
                        ? Colors.orange
                        : Colors.red.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$dailyCompletionCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
