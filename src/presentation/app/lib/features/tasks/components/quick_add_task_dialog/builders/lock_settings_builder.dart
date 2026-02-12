import 'package:flutter/material.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/main.dart';

/// Builds lock option checkbox tiles for quick task dialog
class LockSettingsBuilder {
  static Widget buildLockOptionCheckboxTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required BuildContext context,
  }) {
    return CheckboxListTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
      ),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  /// Builds all lock option settings for quick task dialog
  static Widget buildLockSettings({
    required BuildContext context,
    required bool lockTags,
    required bool lockPriority,
    required bool lockEstimatedTime,
    required bool lockPlannedDate,
    required bool lockDeadlineDate,
    required ValueChanged<bool?> onLockTagsChanged,
    required ValueChanged<bool?> onLockPriorityChanged,
    required ValueChanged<bool?> onLockEstimatedTimeChanged,
    required ValueChanged<bool?> onLockPlannedDateChanged,
    required ValueChanged<bool?> onLockDeadlineDateChanged,
  }) {
    final translationService = container.resolve<ITranslationService>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildLockOptionCheckboxTile(
          title: translationService.translate(TaskTranslationKeys.quickTaskLockDescription),
          subtitle: translationService.translate(TaskTranslationKeys.tagsLabel),
          value: lockTags,
          onChanged: onLockTagsChanged,
          context: context,
        ),
        buildLockOptionCheckboxTile(
          title: translationService.translate(TaskTranslationKeys.quickTaskLockDescription),
          subtitle: translationService.translate(TaskTranslationKeys.priorityLabel),
          value: lockPriority,
          onChanged: onLockPriorityChanged,
          context: context,
        ),
        buildLockOptionCheckboxTile(
          title: translationService.translate(TaskTranslationKeys.quickTaskLockDescription),
          subtitle: translationService.translate(TaskTranslationKeys.quickTaskEstimatedTime),
          value: lockEstimatedTime,
          onChanged: onLockEstimatedTimeChanged,
          context: context,
        ),
        buildLockOptionCheckboxTile(
          title: translationService.translate(TaskTranslationKeys.quickTaskLockDescription),
          subtitle: translationService.translate(TaskTranslationKeys.quickTaskPlannedDate),
          value: lockPlannedDate,
          onChanged: onLockPlannedDateChanged,
          context: context,
        ),
        buildLockOptionCheckboxTile(
          title: translationService.translate(TaskTranslationKeys.quickTaskLockDescription),
          subtitle: translationService.translate(TaskTranslationKeys.quickTaskDeadlineDate),
          value: lockDeadlineDate,
          onChanged: onLockDeadlineDateChanged,
          context: context,
        ),
      ],
    );
  }

  /// Builds a single lock indicator widget
  static Widget buildLockIndicator({
    required BuildContext context,
    required bool isLocked,
    double size = AppTheme.iconSizeXSmall,
  }) {
    if (!isLocked) return SizedBox.shrink();

    return Icon(
      Icons.lock,
      size: size,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  /// Builds a lock status chip
  static Widget buildLockStatusChip({
    required BuildContext context,
    required bool isLocked,
    String? label,
  }) {
    if (!isLocked && (label == null || label.isEmpty)) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLocked
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: isLocked ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLocked) ...[
            Icon(
              Icons.lock,
              size: AppTheme.iconSize2XSmall,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 4),
          ],
          if (label != null && label.isNotEmpty)
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLocked
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
            ),
        ],
      ),
    );
  }
}
