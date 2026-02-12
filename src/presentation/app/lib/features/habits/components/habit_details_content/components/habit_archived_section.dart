import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show DateTimeHelper;
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/shared/components/detail_table.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';

/// Builds the archived date section for habit details.
class HabitArchivedSection {
  static DetailTableRowData build({
    required BuildContext context,
    required DateTime archivedDate,
    required ITranslationService translationService,
  }) {
    return DetailTableRowData(
      label: translationService.translate(HabitTranslationKeys.archivedStatus),
      icon: Icons.archive_outlined,
      widget: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: AppTheme.iconSizeSmall,
              color: AppTheme.textColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              DateTimeHelper.formatDate(archivedDate),
              style: AppTheme.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
