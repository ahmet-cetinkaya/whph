import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// A widget for displaying a date field with a reminder icon
class TaskDateField extends StatefulWidget {
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

  @override
  State<TaskDateField> createState() => _TaskDateFieldState();
}

class _TaskDateFieldState extends State<TaskDateField> {
  bool _isDatePickerOpen = false;

  String _getReminderLabel(ReminderTime reminderTime) {
    switch (reminderTime) {
      case ReminderTime.none:
        return widget.translationService.translate(TaskTranslationKeys.reminderNone);
      case ReminderTime.atTime:
        return widget.translationService.translate(TaskTranslationKeys.reminderAtTime);
      case ReminderTime.fiveMinutesBefore:
        return widget.translationService.translate(TaskTranslationKeys.reminderFiveMinutesBefore);
      case ReminderTime.fifteenMinutesBefore:
        return widget.translationService.translate(TaskTranslationKeys.reminderFifteenMinutesBefore);
      case ReminderTime.oneHourBefore:
        return widget.translationService.translate(TaskTranslationKeys.reminderOneHourBefore);
      case ReminderTime.oneDayBefore:
        return widget.translationService.translate(TaskTranslationKeys.reminderOneDayBefore);
    }
  }

  Future<void> _handleDateSelection() async {
    if (_isDatePickerOpen) return; // Prevent multiple opens

    setState(() {
      _isDatePickerOpen = true;
    });

    try {
      // Parse the current date from the controller or use now
      DateTime? initialDate;

      try {
        if (widget.controller.text.isNotEmpty) {
          initialDate = DateFormatService.parseFromInput(
            widget.controller.text,
            context,
            type: DateFormatType.dateTime,
          );

          // If parseFromInput fails, try alternative parsing methods
          initialDate ??= DateFormatService.parseDateTime(
            widget.controller.text,
            assumeLocal: true,
            locale: Localizations.localeOf(context),
          );
        }
      } catch (e) {
        // If all parsing methods fail, use null
        debugPrint('TaskDateField: Failed to parse date "${widget.controller.text}": $e');
      }

      // Ensure initialDate is within bounds
      if (initialDate != null) {
        if (widget.minDateTime != null && initialDate.isBefore(widget.minDateTime!)) {
          initialDate = widget.minDateTime!;
        }
      }

      final config = DatePickerConfig(
        selectionMode: DateSelectionMode.single,
        initialDate: initialDate,
        minDate: widget.minDateTime,
        maxDate: null,
        formatType: DateFormatType.dateTime,
        showTime: true,
        enableManualInput: true,
        titleText: 'Select Date & Time',
        confirmButtonText: 'Confirm',
        cancelButtonText: 'Cancel',
        allowNullConfirm: true,
      );

      final result = await DatePickerDialog.show(
        context: context,
        config: config,
      );

      if (result != null && result.isConfirmed && mounted) {
        if (result.selectedDate != null) {
          // Date was selected
          final selectedDateTime = result.selectedDate!;

          // Validate the selected date is within bounds (must be >= minDateTime)
          if (widget.minDateTime != null && selectedDateTime.isBefore(widget.minDateTime!)) {
            return;
          }

          // Format the date for display using centralized service
          final String formattedDateTime = DateFormatService.formatForInput(
            selectedDateTime,
            context,
            type: DateFormatType.dateTime,
          );

          // Update controller text first
          widget.controller.text = formattedDateTime;

          // Call the callback with the selected date in local timezone
          widget.onDateChanged(selectedDateTime);
        } else {
          // Date was cleared using Clear button in date picker
          widget.controller.clear();
          widget.onDateChanged(null);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDatePickerOpen = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReminder = widget.reminderValue != ReminderTime.none;

    return Row(
      children: [
        // Date field
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            readOnly: true,
            decoration: InputDecoration(
              hintText: widget.hintText,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.only(left: 8.0),
            ),
            onTap: _handleDateSelection,
          ),
        ),

        // Reminder icon/button
        if (widget.controller.text.isNotEmpty)
          PopupMenuButton<ReminderTime>(
            icon: Icon(
              Icons.notifications,
              color: hasReminder ? Theme.of(context).colorScheme.primary : AppTheme.secondaryTextColor,
              size: AppTheme.iconSizeSmall,
            ),
            tooltip: widget.translationService.translate(TaskTranslationKeys.setReminderTooltip),
            onSelected: widget.onReminderChanged,
            itemBuilder: (context) => ReminderTime.values.map((reminderTime) {
              return PopupMenuItem<ReminderTime>(
                value: reminderTime,
                child: Row(
                  spacing: 8,
                  children: [
                    if (reminderTime == widget.reminderValue)
                      Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                        size: AppTheme.iconSizeSmall,
                      ),
                    Text(_getReminderLabel(reminderTime)),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
