import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart' hide Container;
import 'package:acore/components/date_time_picker/date_picker_dialog.dart' as picker;
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// A widget for selecting and configuring recurrence options for a task
class TaskRecurrenceSelector extends StatefulWidget {
  final RecurrenceType recurrenceType;
  final int? recurrenceInterval;
  final List<WeekDays>? recurrenceDays;
  final DateTime? recurrenceStartDate;
  final DateTime? recurrenceEndDate;
  final int? recurrenceCount;
  final DateTime? plannedDate;
  final Function(RecurrenceType) onRecurrenceTypeChanged;
  final Function(int?) onRecurrenceIntervalChanged;
  final Function(List<WeekDays>?) onRecurrenceDaysChanged;
  final Function(DateTime?) onRecurrenceStartDateChanged;
  final Function(DateTime?) onRecurrenceEndDateChanged;
  final Function(int?) onRecurrenceCountChanged;
  final ITranslationService translationService;

  const TaskRecurrenceSelector({
    super.key,
    required this.recurrenceType,
    this.recurrenceInterval,
    this.recurrenceDays,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
    this.recurrenceCount,
    this.plannedDate,
    required this.onRecurrenceTypeChanged,
    required this.onRecurrenceIntervalChanged,
    required this.onRecurrenceDaysChanged,
    required this.onRecurrenceStartDateChanged,
    required this.onRecurrenceEndDateChanged,
    required this.onRecurrenceCountChanged,
    required this.translationService,
  });

  @override
  State<TaskRecurrenceSelector> createState() => _TaskRecurrenceSelectorState();
}

class _TaskRecurrenceSelectorState extends State<TaskRecurrenceSelector> {
  late RecurrenceType _selectedRecurrenceType;
  int? _recurrenceInterval;
  List<WeekDays>? _recurrenceDays;
  DateTime? _recurrenceStartDate;
  DateTime? _recurrenceEndDate;
  int? _recurrenceCount;

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController();
  final TextEditingController _countController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRecurrenceType = widget.recurrenceType;
    _recurrenceInterval = widget.recurrenceInterval ?? 1;
    _recurrenceDays = widget.recurrenceDays;
    _recurrenceStartDate = widget.recurrenceStartDate;
    _recurrenceEndDate = widget.recurrenceEndDate;
    _recurrenceCount = widget.recurrenceCount;

    // If recurrence type is daysOfWeek and no days are selected, initialize _recurrenceDays locally.
    // The parent (TaskDetailsContent) is responsible for setting these defaults in the actual task data
    // when the recurrence type is first set or loaded.
    if (_selectedRecurrenceType == RecurrenceType.daysOfWeek && (_recurrenceDays == null || _recurrenceDays!.isEmpty)) {
      _recurrenceDays = [WeekDays.values[DateTime.now().weekday - 1]]; // WeekDay enum is 0-based, weekday is 1-based
      // DO NOT call widget.onRecurrenceDaysChanged here; parent handles defaults.
    }

    // Initialize non-formatted controller values
    _intervalController.text = _recurrenceInterval.toString();
    _countController.text = _recurrenceCount?.toString() ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize controllers that need context after dependencies are available
    _updateControllers();
  }

  @override
  void didUpdateWidget(TaskRecurrenceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.recurrenceType != widget.recurrenceType ||
        oldWidget.recurrenceInterval != widget.recurrenceInterval ||
        oldWidget.recurrenceDays != widget.recurrenceDays ||
        oldWidget.recurrenceStartDate != widget.recurrenceStartDate ||
        oldWidget.recurrenceEndDate != widget.recurrenceEndDate ||
        oldWidget.recurrenceCount != widget.recurrenceCount) {
      _selectedRecurrenceType = widget.recurrenceType;
      _recurrenceInterval = widget.recurrenceInterval ?? 1;
      _recurrenceDays = widget.recurrenceDays;
      _recurrenceStartDate = widget.recurrenceStartDate;
      _recurrenceEndDate = widget.recurrenceEndDate;
      _recurrenceCount = widget.recurrenceCount;

      _updateControllers();
    }
  }

  void _updateControllers() {
    // Format dates for controllers (requires context, so called from didChangeDependencies)
    if (_recurrenceStartDate != null) {
      _startDateController.text =
          DateFormatService.formatForDisplay(_recurrenceStartDate!, context, type: DateFormatType.dateTime);
    } else {
      _startDateController.clear();
    }

    if (_recurrenceEndDate != null) {
      _endDateController.text =
          DateFormatService.formatForDisplay(_recurrenceEndDate!, context, type: DateFormatType.dateTime);
    } else {
      _endDateController.clear();
    }

    // Update interval and count controllers
    _intervalController.text = (_recurrenceInterval ?? 1).toString();
    _countController.text = (_recurrenceCount ?? 0).toString();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _intervalController.dispose();
    _countController.dispose();
    super.dispose();
  }

  /// Get the minimum allowed end date based on planned date, recurrence start date, or current date
  DateTime _getMinimumEndDate() {
    // Priority order: plannedDate > recurrenceStartDate > current date
    if (widget.plannedDate != null) {
      return widget.plannedDate!;
    }
    if (_recurrenceStartDate != null) {
      return _recurrenceStartDate!;
    }
    return DateTime.now().toUtc();
  }

  String _getRecurrenceTypeLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceNone);
      case RecurrenceType.daily:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceDaily);
      case RecurrenceType.daysOfWeek:
        // For daysOfWeek recurrence, check if all weekdays are selected
        if (_recurrenceDays?.length == WeekDays.values.length) {
          return widget.translationService.translate(TaskTranslationKeys.everyDay);
        }
        return widget.translationService.translate(TaskTranslationKeys.recurrenceDaysOfWeek);
      case RecurrenceType.weekly:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceWeekly);
      case RecurrenceType.monthly:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceMonthly);
      case RecurrenceType.yearly:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceYearly);
    }
  }

  String _getWeekDayLabel(WeekDays day) {
    switch (day) {
      case WeekDays.monday:
        return widget.translationService.translate(SharedTranslationKeys.monday);
      case WeekDays.tuesday:
        return widget.translationService.translate(SharedTranslationKeys.tuesday);
      case WeekDays.wednesday:
        return widget.translationService.translate(SharedTranslationKeys.wednesday);
      case WeekDays.thursday:
        return widget.translationService.translate(SharedTranslationKeys.thursday);
      case WeekDays.friday:
        return widget.translationService.translate(SharedTranslationKeys.friday);
      case WeekDays.saturday:
        return widget.translationService.translate(SharedTranslationKeys.saturday);
      case WeekDays.sunday:
        return widget.translationService.translate(SharedTranslationKeys.sunday);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<RecurrenceType>(
          value: _selectedRecurrenceType,
          decoration: InputDecoration(
            labelText: widget.translationService.translate(TaskTranslationKeys.recurrenceLabel),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: RecurrenceType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(_getRecurrenceTypeLabel(type)),
            );
          }).toList(),
          onChanged: (RecurrenceType? newValue) {
            if (newValue != null && newValue != _selectedRecurrenceType) {
              setState(() {
                _selectedRecurrenceType = newValue;

                if (newValue == RecurrenceType.none) {
                  _recurrenceInterval = null;
                  _recurrenceDays = null;
                  _recurrenceStartDate = null;
                  _recurrenceEndDate = null;
                  _recurrenceCount = null;
                } else {
                  if (newValue == RecurrenceType.daysOfWeek) {
                    _recurrenceInterval = 1;
                  } else {
                    _recurrenceInterval ??= 1;
                  }

                  _recurrenceStartDate ??= DateTime.now();

                  if (newValue == RecurrenceType.daysOfWeek) {
                    if (_recurrenceDays == null || _recurrenceDays!.isEmpty) {
                      _recurrenceDays = [WeekDays.values[DateTime.now().weekday - 1]];
                    }
                  } else if (newValue != RecurrenceType.daysOfWeek) {
                    _recurrenceDays = null;
                  }
                }
                _updateControllers();
              });

              widget.onRecurrenceTypeChanged(newValue);
            }
          },
        ),

        // Only show configuration options if a recurrence type is selected
        if (_selectedRecurrenceType != RecurrenceType.none) ...[
          const SizedBox(height: AppTheme.sizeLarge),

          // Interval configuration (for all recurrence types except none)
          if (_selectedRecurrenceType != RecurrenceType.none) ...[
            const SizedBox(height: 24),
            Text(
              widget.translationService.translate(TaskTranslationKeys.recurrenceIntervalLabel),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            NumericInput(
              value: _recurrenceInterval ?? 1,
              minValue: 1,
              maxValue: 999,
              onValueChanged: (value) {
                setState(() {
                  _recurrenceInterval = value;
                  _intervalController.text = value.toString();
                });
                widget.onRecurrenceIntervalChanged(value);
              },
              valueSuffix: _getIntervalSuffix(),
              style: NumericInputStyle.contained,
            ),
          ],

          // Specific weekdays selector (only for daysOfWeek recurrence)
          if (_selectedRecurrenceType == RecurrenceType.daysOfWeek) ...[
            const SizedBox(height: 24),
            Text(
              widget.translationService.translate(TaskTranslationKeys.recurrenceWeekDaysLabel),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WeekDays.values.map((day) {
                final isSelected = _recurrenceDays?.contains(day) ?? false;
                return FilterChip(
                  label: Text(_getWeekDayLabel(day)),
                  selected: isSelected,
                  showCheckmark: false,
                  avatar: isSelected
                      ? CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          radius: 8,
                          child: Icon(Icons.check, size: 12, color: Theme.of(context).colorScheme.primaryContainer),
                        )
                      : null,
                  onSelected: (selected) {
                    setState(() {
                      _recurrenceDays ??= [];
                      if (selected) {
                        _recurrenceDays!.add(day);
                      } else {
                        _recurrenceDays!.remove(day);
                      }
                      if (_recurrenceDays!.isEmpty) {
                        _recurrenceDays = null;
                      }
                    });
                    widget.onRecurrenceDaysChanged(_recurrenceDays);
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),

          // Recurrence date range
          Text(
            widget.translationService.translate(TaskTranslationKeys.recurrenceRangeLabel),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Start date
          Text(
            widget.translationService.translate(TaskTranslationKeys.starts),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          _datePickerField(
            controller: _startDateController,
            initialDate: _recurrenceStartDate,
            minDate: DateTime(2000),
            maxDate: DateTime(2100),
            hintText: widget.translationService.translate(TaskTranslationKeys.selectDateHint),
            icon: Icons.calendar_today,
            onDateSelected: (date) {
              if (date != null) {
                setState(() {
                  _recurrenceStartDate = date;
                  _startDateController.text =
                      DateFormatService.formatForDisplay(date, context, type: DateFormatType.dateTime);
                });
                widget.onRecurrenceStartDateChanged(date);
              }
            },
          ),

          const SizedBox(height: 16),

          // End Condition Selection
          Text(
            widget.translationService.translate(TaskTranslationKeys.recurrenceEndsLabel),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 16) / 3;
              return ToggleButtons(
                isSelected: [
                  _recurrenceEndDate == null && _recurrenceCount == null, // Forever
                  _recurrenceEndDate != null, // Until Date
                  _recurrenceCount != null, // Count
                ],
                onPressed: (index) {
                  setState(() {
                    if (index == 0) {
                      // Forever
                      _recurrenceEndDate = null;
                      _recurrenceCount = null;
                      _endDateController.clear();
                      _countController.clear();
                      widget.onRecurrenceEndDateChanged(null);
                      widget.onRecurrenceCountChanged(null);
                    } else if (index == 1) {
                      // Until Date
                      _recurrenceCount = null;
                      _recurrenceEndDate ??= _getMinimumEndDate().add(const Duration(days: 30));
                      _updateControllers();
                      widget.onRecurrenceCountChanged(null);
                      widget.onRecurrenceEndDateChanged(_recurrenceEndDate);
                    } else if (index == 2) {
                      // Count
                      _recurrenceEndDate = null;
                      _recurrenceCount ??= 5;
                      _updateControllers();
                      widget.onRecurrenceEndDateChanged(null);
                      widget.onRecurrenceCountChanged(_recurrenceCount);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                constraints: BoxConstraints(minWidth: width, minHeight: 40),
                children: [
                  Text(widget.translationService.translate(TaskTranslationKeys.recurrenceEndsNever)),
                  Text(widget.translationService.translate(TaskTranslationKeys.recurrenceEndsOnDate)),
                  Text(widget.translationService.translate(TaskTranslationKeys.recurrenceEndsAfter)),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // End date selector (if using end date)
          if (_recurrenceEndDate != null) ...[
            _datePickerField(
              controller: _endDateController,
              initialDate: _recurrenceEndDate ??
                  (_recurrenceStartDate?.add(const Duration(days: 30)) ??
                      DateTime.now().toUtc().add(const Duration(days: 30))),
              minDate: _getMinimumEndDate(),
              maxDate: DateTime(2100),
              hintText: widget.translationService.translate(TaskTranslationKeys.selectDateHint),
              icon: Icons.event_busy,
              onDateSelected: (date) {
                if (date != null) {
                  setState(() {
                    _recurrenceEndDate = date;
                    _endDateController.text =
                        DateFormatService.formatForDisplay(date, context, type: DateFormatType.dateTime);
                  });
                  widget.onRecurrenceEndDateChanged(date);
                }
              },
            ),
          ],

          // Count selector (if using count)
          if (_recurrenceCount != null) ...[
            NumericInput(
              value: _recurrenceCount ?? 1,
              minValue: 1,
              maxValue: 999,
              onValueChanged: (value) {
                setState(() {
                  _recurrenceCount = value;
                  _countController.text = value.toString();
                });
                widget.onRecurrenceCountChanged(value);
              },
              valueSuffix: widget.translationService.translate(TaskTranslationKeys.occurrences),
              style: NumericInputStyle.contained,
            ),
          ],
        ],
      ],
    );
  }

  String _getIntervalSuffix() {
    switch (_selectedRecurrenceType) {
      case RecurrenceType.daily:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceDaySuffix);
      case RecurrenceType.daysOfWeek:
      case RecurrenceType.weekly:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceWeekSuffix);
      case RecurrenceType.monthly:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceMonthSuffix);
      case RecurrenceType.yearly:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceYearSuffix);
      default:
        return '';
    }
  }

  Widget _datePickerField({
    required TextEditingController controller,
    DateTime? initialDate,
    DateTime? minDate,
    DateTime? maxDate,
    required String hintText,
    String? label,
    IconData? icon,
    required Function(DateTime?) onDateSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        if (!context.mounted) return;

        final config = DatePickerConfig(
          selectionMode: DateSelectionMode.single,
          initialDate: initialDate,
          minDate: minDate,
          maxDate: maxDate,
          formatType: DateFormatType.date,
          showTime: false,
          enableManualInput: true,
          titleText: label ?? widget.translationService.translate(TaskTranslationKeys.recurrenceStartLabel),
          translations: {
            DateTimePickerTranslationKey.title:
                label ?? widget.translationService.translate(TaskTranslationKeys.recurrenceStartLabel),
            DateTimePickerTranslationKey.confirm: widget.translationService.translate(SharedTranslationKeys.doneButton),
            DateTimePickerTranslationKey.cancel:
                widget.translationService.translate(SharedTranslationKeys.cancelButton),
          },
        );

        final result = await picker.DatePickerDialog.show(
          context: context,
          config: config,
        );

        if (result != null && !result.wasCancelled && result.selectedDate != null && mounted) {
          final selectedDate = result.selectedDate!;
          controller.text = DateFormatService.formatForDisplay(selectedDate, context, type: DateFormatType.date);
          onDateSelected(selectedDate);
        }
      },
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            suffixIcon: Icon(SharedUiConstants.calendarIcon, size: AppTheme.iconSizeSmall),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}
