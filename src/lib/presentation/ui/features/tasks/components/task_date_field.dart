import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// A widget for displaying a date field with a reminder icon
class TaskDateField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(DateTime?) onDateChanged;
  final Function(ReminderTime) onReminderChanged;
  final DateTime? minDateTime;
  final DateTime? plannedDateTime; // For deadline date validation with time
  final ReminderTime reminderValue;
  final ITranslationService translationService;
  final String reminderLabelPrefix;
  final IconData dateIcon;
  final FocusNode? focusNode;

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
    this.plannedDateTime,
    this.dateIcon = Icons.calendar_today,
    this.focusNode,
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
          final locale = Localizations.localeOf(context);

          initialDate = DateFormatService.parseFromInput(
            widget.controller.text,
            context,
            type: DateFormatType.dateTime,
          );

          // If parseFromInput fails, try alternative parsing methods
          initialDate ??= DateFormatService.parseDateTime(
            widget.controller.text,
            assumeLocal: true,
            locale: locale,
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
        minDate: widget.plannedDateTime ?? widget.minDateTime, // Use planned date as minDate for deadline validation
        maxDate: null,
        formatType: DateFormatType.dateTime,
        showTime: true,
        enableManualInput: true,
        titleText: widget.translationService.translate(TaskTranslationKeys.selectPlannedDateTitle),
        confirmButtonText: widget.translationService.translate(SharedTranslationKeys.confirmButton),
        cancelButtonText: widget.translationService.translate(SharedTranslationKeys.cancelButton),
        allowNullConfirm: true,
        dateTimeValidator: null, // Use built-in minDate validation instead
        validationErrorMessage: null, // Use built-in validation messages
        translations: {
          DateTimePickerTranslationKey.setTime: widget.translationService.translate(SharedTranslationKeys.change),
          DateTimePickerTranslationKey.noDateSelected:
              widget.translationService.translate(SharedTranslationKeys.notSetTime),
          DateTimePickerTranslationKey.clear: widget.translationService.translate(SharedTranslationKeys.clearButton),
          // Built-in validation messages - use task-specific message for deadline validation
          DateTimePickerTranslationKey.selectedDateMustBeAtOrAfter:
              widget.translationService.translate(TaskTranslationKeys.deadlineTimeInvalid),
          // General date picker validations - use shared translations
          DateTimePickerTranslationKey.selectedDateMustBeAtOrBefore:
              widget.translationService.translate(SharedTranslationKeys.selectedDateMustBeAtOrBefore),
          DateTimePickerTranslationKey.startDateCannotBeAfterEndDate:
              widget.translationService.translate(SharedTranslationKeys.startDateCannotBeAfterEndDate),
          DateTimePickerTranslationKey.startDateMustBeAtOrAfter:
              widget.translationService.translate(SharedTranslationKeys.startDateMustBeAtOrAfter),
          DateTimePickerTranslationKey.endDateMustBeAtOrBefore:
              widget.translationService.translate(SharedTranslationKeys.endDateMustBeAtOrBefore),
          DateTimePickerTranslationKey.cannotSelectDateBeforeMinDate:
              widget.translationService.translate(SharedTranslationKeys.cannotSelectDateBeforeMinDate),
          DateTimePickerTranslationKey.cannotSelectDateAfterMaxDate:
              widget.translationService.translate(SharedTranslationKeys.cannotSelectDateAfterMaxDate),
          DateTimePickerTranslationKey.startDateCannotBeBeforeMinDate:
              widget.translationService.translate(SharedTranslationKeys.startDateCannotBeBeforeMinDate),
          DateTimePickerTranslationKey.endDateCannotBeAfterMaxDate:
              widget.translationService.translate(SharedTranslationKeys.endDateCannotBeAfterMaxDate),
          DateTimePickerTranslationKey.cannotSelectTimeBeforeMinDate:
              widget.translationService.translate(SharedTranslationKeys.cannotSelectTimeBeforeMinDate),
          DateTimePickerTranslationKey.cannotSelectTimeAfterMaxDate:
              widget.translationService.translate(SharedTranslationKeys.cannotSelectTimeAfterMaxDate),
          DateTimePickerTranslationKey.timeMustBeAtOrAfter:
              widget.translationService.translate(SharedTranslationKeys.timeMustBeAtOrAfter),
          DateTimePickerTranslationKey.timeMustBeAtOrBefore:
              widget.translationService.translate(SharedTranslationKeys.timeMustBeAtOrBefore),
          DateTimePickerTranslationKey.selectedDateTimeMustBeAfter:
              widget.translationService.translate(SharedTranslationKeys.selectedDateTimeMustBeAfter),
          DateTimePickerTranslationKey.selectDateTimeTitle:
              widget.translationService.translate(SharedTranslationKeys.selectDateTimeTitle),
          DateTimePickerTranslationKey.selectDateRangeTitle:
              widget.translationService.translate(SharedTranslationKeys.selectDateRangeTitle),
        },
      );

      final result = await DatePickerDialog.show(
        context: context,
        config: config,
      );

      if (result != null && result.isConfirmed && mounted) {
        if (result.selectedDate != null) {
          // Date was selected
          final selectedDateTime = result.selectedDate!;

          // Validation is now handled by the date picker's custom validator
          // No need for additional validation here

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
            focusNode: widget.focusNode,
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
