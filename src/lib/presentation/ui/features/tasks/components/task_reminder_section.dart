import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_reminder_selector.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// A dedicated section for managing task reminders independently of date fields
class TaskReminderSection extends StatelessWidget {
  final ReminderTime plannedDateReminderValue;
  final ReminderTime deadlineDateReminderValue;
  final Function(ReminderTime, int?) onPlannedReminderChanged;
  final Function(ReminderTime, int?) onDeadlineReminderChanged;
  final ITranslationService translationService;
  final DateTime? plannedDate;
  final DateTime? deadlineDate;
  final bool showPlannedReminder;
  final bool showDeadlineReminder;
  final int? plannedDateReminderCustomOffset;
  final int? deadlineDateReminderCustomOffset;

  const TaskReminderSection({
    super.key,
    required this.plannedDateReminderValue,
    required this.deadlineDateReminderValue,
    required this.onPlannedReminderChanged,
    required this.onDeadlineReminderChanged,
    required this.translationService,
    this.plannedDate,
    this.deadlineDate,
    this.showPlannedReminder = true,
    this.showDeadlineReminder = true,
    this.plannedDateReminderCustomOffset,
    this.deadlineDateReminderCustomOffset,
  });

  Widget _buildReminderInfoBox(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sizeSmall),
      margin: const EdgeInsets.only(bottom: AppTheme.sizeMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
            size: AppTheme.iconSizeSmall,
          ),
          const SizedBox(width: AppTheme.sizeSmall),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required ReminderTime value,
    required Function(ReminderTime, int?) onChanged,
    required DateTime? date,
    required String labelPrefix,
    int? customOffset,
  }) {
    final hasDate = date != null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
        side: BorderSide(
          color: hasDate
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: hasDate
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: AppTheme.iconSizeMedium,
                ),
                const SizedBox(width: AppTheme.sizeSmall),
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasDate
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                if (!hasDate) ...[
                  const Spacer(),
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    size: AppTheme.iconSizeSmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            if (!hasDate)
              Text(
                translationService.translate(TaskTranslationKeys.reminderDateRequiredTooltip),
                style: AppTheme.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              )
            else ...[
              TaskReminderSelector(
                value: value,
                onChanged: onChanged,
                translationService: translationService,
                labelPrefix: labelPrefix,
                customOffset: customOffset,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: Theme.of(context).colorScheme.primary,
              size: AppTheme.iconSizeLarge,
            ),
            const SizedBox(width: AppTheme.sizeSmall),
            Text(
              translationService.translate(TaskTranslationKeys.reminderSectionTitle),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sizeMedium),

        // Help text
        _buildReminderInfoBox(
          context,
          translationService.translate(TaskTranslationKeys.reminderHelpText),
        ),

        // Planned date reminder
        if (showPlannedReminder)
          _buildReminderSection(
            context: context,
            title: translationService.translate(TaskTranslationKeys.reminderPlannedLabel),
            icon: Icons.event,
            value: plannedDateReminderValue,
            onChanged: onPlannedReminderChanged,
            date: plannedDate,
            labelPrefix: 'tasks.reminder.planned',
            customOffset: plannedDateReminderCustomOffset,
          ),

        // Deadline date reminder
        if (showDeadlineReminder)
          _buildReminderSection(
            context: context,
            title: translationService.translate(TaskTranslationKeys.reminderDeadlineLabel),
            icon: Icons.alarm,
            value: deadlineDateReminderValue,
            onChanged: onDeadlineReminderChanged,
            date: deadlineDate,
            labelPrefix: 'tasks.reminder.deadline',
            customOffset: deadlineDateReminderCustomOffset,
          ),
      ],
    );
  }
}
