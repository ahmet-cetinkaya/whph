import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show DateFormatService, DateFormatType;
import 'package:whph/core/domain/features/tasks/task.dart';

import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart' as application;

import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

/// Builds quick action buttons for task dialog
class QuickActionsBuilder {
  /// Builds a simple action button with icon and label
  static Widget buildActionButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Widget? customWidget,
    bool isLocked = false,
    bool isEmpty = true,
  }) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isEmpty
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)
            : isLocked
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (customWidget != null)
                  customWidget
                else if (icon != null)
                  Icon(
                    icon,
                    size: 16,
                    color: isEmpty
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                        : isLocked
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primary,
                  ),
                if (icon != null || customWidget != null) SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isEmpty
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)
                              : isLocked
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLocked) ...[
                  SizedBox(width: 4),
                  Icon(
                    Icons.lock,
                    size: AppTheme.iconSize2XSmall,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a priority icon widget
  static Widget buildPriorityIcon({
    required BuildContext context,
    EisenhowerPriority? priority,
    double size = 16,
  }) {
    if (priority == null) {
      return Icon(
        TaskUiConstants.priorityOutlinedIcon,
        size: size,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      );
    }

    return Icon(
      TaskUiConstants.priorityIcon,
      size: size,
      color: TaskUiConstants.getPriorityColor(priority),
    );
  }

  /// Builds date display text
  static String buildDateDisplayText({
    required DateTime? date,
    required BuildContext context,
    required String fallbackText,
  }) {
    if (date == null) return fallbackText;

    return DateFormatService.formatForInput(
      date,
      context,
      type: DateFormatType.date,
    );
  }

  /// Gets priority display name
  static String getPriorityDisplayName(
    EisenhowerPriority? priority,
    ITranslationService translationService,
  ) {
    if (priority == null) {
      return translationService.translate(application.TaskTranslationKeys.priorityNone);
    }

    switch (priority) {
      case EisenhowerPriority.urgentImportant:
        return translationService.translate(application.TaskTranslationKeys.priorityUrgentImportant);
      case EisenhowerPriority.urgentNotImportant:
        return translationService.translate(application.TaskTranslationKeys.priorityUrgentNotImportant);
      case EisenhowerPriority.notUrgentImportant:
        return translationService.translate(application.TaskTranslationKeys.priorityNotUrgentImportant);
      case EisenhowerPriority.notUrgentNotImportant:
        return translationService.translate(application.TaskTranslationKeys.priorityNotUrgentNotImportant);
    }
  }

  /// Gets priority tooltip text
  static String getPriorityTooltip(
    EisenhowerPriority? priority,
    ITranslationService translationService,
  ) {
    return TaskUiConstants.getPriorityTooltip(priority, translationService);
  }
}
