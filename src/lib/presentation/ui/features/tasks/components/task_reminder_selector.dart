import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// A widget for selecting reminder options for a task
class TaskReminderSelector extends StatelessWidget {
  final ReminderTime value;
  final Function(ReminderTime) onChanged;
  final ITranslationService translationService;
  final String labelPrefix;

  const TaskReminderSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.translationService,
    required this.labelPrefix,
  });

  String _getReminderLabel(ReminderTime reminderTime) {
    switch (reminderTime) {
      case ReminderTime.none:
        return translationService.translate(TaskTranslationKeys.reminderNone);
      case ReminderTime.atTime:
        return translationService.translate(TaskTranslationKeys.reminderAtTime);
      case ReminderTime.fiveMinutesBefore:
        return translationService.translate(TaskTranslationKeys.reminderFiveMinutesBefore);
      case ReminderTime.fifteenMinutesBefore:
        return translationService.translate(TaskTranslationKeys.reminderFifteenMinutesBefore);
      case ReminderTime.oneHourBefore:
        return translationService.translate(TaskTranslationKeys.reminderOneHourBefore);
      case ReminderTime.oneDayBefore:
        return translationService.translate(TaskTranslationKeys.reminderOneDayBefore);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translationService.translate(labelPrefix == 'tasks.reminder.planned'
              ? TaskTranslationKeys.reminderPlannedLabel
              : TaskTranslationKeys.reminderDeadlineLabel),
          style: AppTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        DropdownButton<ReminderTime>(
          value: value,
          isExpanded: true,
          underline: Container(
            height: 1,
            color: AppTheme.dividerColor,
          ),
          items: ReminderTime.values.map((reminderTime) {
            return DropdownMenuItem<ReminderTime>(
              value: reminderTime,
              child: Text(_getReminderLabel(reminderTime)),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              // Force update with the new value
              onChanged(newValue);
            }
          },
        ),
      ],
    );
  }
}
