import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/components/custom_reminder_dialog.dart';

/// A widget for selecting reminder options for a task
class TaskReminderSelector extends StatelessWidget {
  final ReminderTime value;
  final Function(ReminderTime, int?) onChanged;
  final ITranslationService translationService;
  final String labelPrefix;
  final int? customOffset;

  const TaskReminderSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.translationService,
    required this.labelPrefix,
    this.customOffset,
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
      case ReminderTime.custom:
        if (customOffset != null) {
          // Format custom offset for display
          if (customOffset! % (60 * 24 * 7) == 0) {
            final weeks = customOffset! ~/ (60 * 24 * 7);
            return '$weeks ${translationService.translate(TaskTranslationKeys.weeks)} ${translationService.translate(TaskTranslationKeys.reminderBeforeSuffix)}';
          } else if (customOffset! % (60 * 24) == 0) {
            final days = customOffset! ~/ (60 * 24);
            return '$days ${translationService.translate(TaskTranslationKeys.days)} ${translationService.translate(TaskTranslationKeys.reminderBeforeSuffix)}';
          } else if (customOffset! % 60 == 0) {
            final hours = customOffset! ~/ 60;
            return '$hours ${translationService.translate(TaskTranslationKeys.hours)} ${translationService.translate(TaskTranslationKeys.reminderBeforeSuffix)}';
          } else {
            return '$customOffset ${translationService.translate(TaskTranslationKeys.minutes)} ${translationService.translate(TaskTranslationKeys.reminderBeforeSuffix)}';
          }
        }
        return translationService.translate(TaskTranslationKeys.reminderCustom);
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
          onChanged: (newValue) async {
            if (newValue != null) {
              if (newValue == ReminderTime.custom) {
                final customMinutes = await CustomReminderDialog.show(
                  context,
                  translationService,
                  initialMinutes: customOffset,
                );

                if (customMinutes != null) {
                  onChanged(newValue, customMinutes);
                } else if (value != ReminderTime.custom) {
                  // If cancelled and wasn't already custom, don't change anything
                  // If it was already custom, keep it as is
                }
              } else {
                onChanged(newValue, null);
              }
            }
          },
        ),
      ],
    );
  }
}
