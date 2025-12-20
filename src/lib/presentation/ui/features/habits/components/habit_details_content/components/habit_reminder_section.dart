import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds the reminder section for habit details.
class HabitReminderSection {
  static DetailTableRowData build({
    required BuildContext context,
    required bool hasReminder,
    required String reminderSummaryText,
    required ITranslationService translationService,
    required VoidCallback onTap,
  }) {
    return DetailTableRowData(
      label: translationService.translate(HabitTranslationKeys.reminderSettings),
      icon: Icons.notifications,
      widget: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.sizeSmall,
            top: AppTheme.size2XSmall,
            bottom: AppTheme.size2XSmall,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  reminderSummaryText,
                  style: AppTheme.bodyMedium.copyWith(
                    color: !hasReminder ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6) : null,
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
