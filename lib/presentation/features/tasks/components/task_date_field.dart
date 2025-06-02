import 'package:flutter/material.dart';
import 'package:whph/core/acore/components/date_time_picker_field.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

/// A widget for displaying a date field with a reminder icon
class TaskDateField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(DateTime?) onDateChanged;
  final Function(ReminderTime) onReminderChanged;
  final DateTime? minDateTime;
  final ReminderTime reminderValue;
  final ITranslationService translationService;
  final String reminderLabelPrefix;
  final IconData dateIcon;

  const TaskDateField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onDateChanged,
    required this.onReminderChanged,
    required this.reminderValue,
    required this.translationService,
    required this.reminderLabelPrefix,
    this.minDateTime,
    this.dateIcon = Icons.calendar_today,
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
    final hasReminder = reminderValue != ReminderTime.none;
    final reminderText = hasReminder && reminderValue != ReminderTime.atTime ? _getReminderLabel(reminderValue) : '';

    return Row(
      children: [
        // Date field
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: DateTimePickerField(
                  controller: controller,
                  hintText: hintText,
                  minDateTime: minDateTime,
                  onConfirm: onDateChanged,
                  clearButtonTooltip: translationService.translate(TaskTranslationKeys.clearDateTooltip),
                ),
              ),
            ],
          ),
        ),

        // Reminder icon/button
        if (controller.text.isNotEmpty)
          PopupMenuButton<ReminderTime>(
            icon: Icon(
              Icons.notifications,
              color: hasReminder ? Theme.of(context).colorScheme.primary : Colors.grey,
              size: AppTheme.iconSizeSmall,
            ),
            tooltip: translationService.translate(TaskTranslationKeys.setReminderTooltip),
            onSelected: onReminderChanged,
            itemBuilder: (context) => ReminderTime.values.map((reminderTime) {
              return PopupMenuItem<ReminderTime>(
                value: reminderTime,
                child: Row(
                  children: [
                    if (reminderTime == reminderValue)
                      Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                        size: AppTheme.iconSizeSmall,
                      ),
                    if (reminderTime == reminderValue) const SizedBox(width: 8),
                    Text(_getReminderLabel(reminderTime)),
                  ],
                ),
              );
            }).toList(),
          ),

        // Show reminder text if there's a reminder
        if (hasReminder && controller.text.isNotEmpty && reminderText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: AppTheme.size2XSmall),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.size2XSmall * 1.5, vertical: AppTheme.size2XSmall / 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.size2XSmall),
              ),
              child: Text(
                reminderText,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}
