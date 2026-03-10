import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds the recurrence section for task details.
class TaskRecurrenceSection {
  final ITranslationService translationService;
  final RecurrenceType recurrenceType;
  final String summaryText;
  final VoidCallback onTap;

  const TaskRecurrenceSection({
    required this.translationService,
    required this.recurrenceType,
    required this.summaryText,
    required this.onTap,
  });

  DetailTableRowData build(BuildContext context) => DetailTableRowData(
        label: translationService.translate(TaskTranslationKeys.recurrenceLabel),
        icon: Icons.repeat,
        widget: Padding(
          padding: const EdgeInsets.only(top: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall, left: AppTheme.sizeSmall),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(left: AppTheme.sizeMedium),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        summaryText,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.normal,
                          color: recurrenceType == RecurrenceType.none
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
