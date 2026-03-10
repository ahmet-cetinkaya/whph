import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/reminder_tooltip_helper.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_date_display_helper.dart';
import 'task_date_picker_dialog.dart';

/// A widget that provides task date selection using the new TaskDatePickerDialog
/// but maintains the same interface as TaskDateField for backward compatibility
class TaskDatePickerField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(DateTime?) onDateChanged;
  final Function(ReminderTime, int?) onReminderChanged;
  final DateTime? minDateTime;
  final DateTime? plannedDateTime; // For deadline date validation with time
  final ReminderTime reminderValue;
  final int? reminderCustomOffset;
  final ITranslationService translationService;
  final String reminderLabelPrefix;
  final IconData dateIcon;
  final FocusNode? focusNode;
  final BuildContext? context; // Add context for reminder dialog

  const TaskDatePickerField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onDateChanged,
    required this.onReminderChanged,
    required this.reminderValue,
    this.reminderCustomOffset,
    required this.translationService,
    required this.reminderLabelPrefix,
    this.minDateTime,
    this.plannedDateTime,
    this.dateIcon = Icons.calendar_today,
    this.focusNode,
    this.context, // Add context parameter
  });

  @override
  State<TaskDatePickerField> createState() => _TaskDatePickerFieldState();
}

class _TaskDatePickerFieldState extends State<TaskDatePickerField> {
  bool _isDatePickerOpen = false;
  String _currentTooltip = '';
  bool _tooltipInitialized = false;

  @override
  void initState() {
    super.initState();
    // Schedule tooltip update after the widget is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateTooltip();
      }
    });
  }

  @override
  void didUpdateWidget(TaskDatePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update tooltip when reminder value or custom offset changes (not date changes per user requirement)
    if (oldWidget.reminderValue != widget.reminderValue ||
        oldWidget.reminderCustomOffset != widget.reminderCustomOffset) {
      _updateTooltip();
    }
  }

  /// Updates the tooltip text based on current reminder state
  void _updateTooltip() {
    // Parse date from controller if available
    DateTime? parsedDate;
    if (widget.controller.text.isNotEmpty) {
      try {
        final locale = Localizations.localeOf(context);
        parsedDate = DateFormatService.parseFromInput(
          widget.controller.text,
          context,
          type: DateFormatType.dateTime,
        );

        // If parseFromInput fails, try alternative parsing
        parsedDate ??= DateFormatService.parseDateTime(
          widget.controller.text,
          assumeLocal: true,
          locale: locale,
        );
      } catch (e) {
        // If parsing fails, keep parsedDate as null
        debugPrint('TaskDatePickerField: Failed to parse date for tooltip: $e');
      }
    }

    setState(() {
      _currentTooltip = ReminderTooltipHelper.getReminderTooltip(
        translationService: widget.translationService,
        currentReminder: widget.reminderValue,
        date: parsedDate,
        customOffset: widget.reminderCustomOffset,
      );
      _tooltipInitialized = true;
    });
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
        debugPrint('TaskDatePickerField: Failed to parse date "${widget.controller.text}": $e');
      }

      // Ensure initialDate is within bounds
      if (initialDate != null) {
        if (widget.minDateTime != null && initialDate.isBefore(widget.minDateTime!)) {
          initialDate = widget.minDateTime!;
        }
      }

      // Determine title based on the reminder label prefix
      String titleText;
      if (widget.reminderLabelPrefix.contains('planned')) {
        titleText = widget.translationService.translate(TaskTranslationKeys.plannedDateLabel);
      } else if (widget.reminderLabelPrefix.contains('deadline')) {
        titleText = widget.translationService.translate(TaskTranslationKeys.deadlineDateLabel);
      } else {
        titleText = widget.hintText.isNotEmpty ? widget.hintText : 'Select Date';
      }

      debugPrint('TaskDatePickerField: Opening time picker for ${widget.reminderLabelPrefix}');
      debugPrint('TaskDatePickerField: minDateTime=${widget.minDateTime}, plannedDateTime=${widget.plannedDateTime}');

      final result = await TaskDatePickerDialog.showWithReminder(
        context: context,
        config: TaskDatePickerConfig(
          initialDate: initialDate,
          initialReminderTime: widget.reminderValue, // ReminderTime is not nullable
          initialReminderCustomOffset: widget.reminderCustomOffset,
          titleText: titleText,
          // Only use minDateTime for date validation, don't use plannedDateTime as minDate
          // as it can interfere with time picker display
          minDate: widget.minDateTime,
          maxDate: null,
          formatType: DateFormatType.dateTime,
          showTime: true,
          showQuickRanges: true,
          useResponsiveDesign: true,
          enableFooterActions: true,
          translationService: widget.translationService,
          dialogSize: DialogSize.xLarge,
          context: context,
        ),
      );

      if (result != null && !result.wasCancelled && mounted) {
        // Handle date selection
        if (result.selectedDate != null) {
          // Date was selected
          final selectedDateTime = result.selectedDate!;

          // Format the date for display using centralized service
          final String formattedDateTime = result.isAllDay
              ? TaskDateDisplayHelper.formatForInput(selectedDateTime, context)
              : DateFormatService.formatForInput(
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

        // Handle reminder changes
        if (result.reminderTime != null) {
          widget.onReminderChanged(result.reminderTime!, result.reminderCustomOffset);
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

  Future<void> _showReminderDialog() async {
    if (widget.context == null) return;

    final result = await TaskDatePickerDialog.showReminderSelectionDialog(
      widget.context!,
      widget.reminderValue,
      widget.translationService,
      widget.reminderCustomOffset,
    );

    if (result != null && mounted) {
      widget.onReminderChanged(result.reminderTime, result.customOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReminder = widget.reminderValue != ReminderTime.none;
    final hasDate = widget.controller.text.isNotEmpty;

    // Ensure tooltip is initialized on first build if not already done
    if (!_tooltipInitialized && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_tooltipInitialized) {
          _updateTooltip();
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.sizeSmall),
      child: Row(
        children: [
          // Date field
          Expanded(
            child: TextFormField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              readOnly: true,
              style: AppTheme.bodyMedium,
              maxLines: null,
              decoration: InputDecoration(
                hintText: widget.hintText,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
              onTap: _handleDateSelection,
            ),
          ),

          // Reminder icon/button - use IconButton with the new reminder dialog
          if (widget.controller.text.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.notifications,
                color: hasReminder
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: AppTheme.iconSizeMedium,
              ),
              tooltip: _currentTooltip,
              onPressed: hasDate ? _showReminderDialog : null, // Disable if no date selected
            ),
        ],
      ),
    );
  }
}
