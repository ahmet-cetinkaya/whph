import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds the goal section for habit details.
class HabitGoalSection {
  static DetailTableRowData build({
    required BuildContext context,
    required bool hasGoal,
    required int targetFrequency,
    required int periodDays,
    required int dailyTarget,
    required bool isArchived,
    required ITranslationService translationService,
    required VoidCallback onTap,
  }) {
    return DetailTableRowData(
      label: translationService.translate(HabitTranslationKeys.goalSettings),
      icon: Icons.track_changes,
      widget: Container(
        padding: const EdgeInsets.only(
          left: AppTheme.sizeSmall,
          top: AppTheme.size2XSmall,
          bottom: AppTheme.size2XSmall,
        ),
        child: GestureDetector(
          onTap: isArchived ? null : onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: hasGoal
                            ? '$dailyTarget ${translationService.translate(HabitTranslationKeys.dailyTargetHint)}, ${translationService.translate(HabitTranslationKeys.goalFormat, namedArgs: {
                                    'count': targetFrequency.toString(),
                                    'dayCount': periodDays.toString()
                                  })}'
                            : translationService.translate(SharedTranslationKeys.notSetTime),
                        style: AppTheme.bodyMedium.copyWith(
                          color: isArchived
                              ? Theme.of(context).disabledColor
                              : !hasGoal
                                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                                  : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
