import 'package:flutter/material.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/core/acore/time/week_days.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

/// A widget for selecting and configuring recurrence options for a task
class TaskRecurrenceSelector extends StatefulWidget {
  final RecurrenceType recurrenceType;
  final int? recurrenceInterval;
  final List<WeekDays>? recurrenceDays;
  final DateTime? recurrenceStartDate;
  final DateTime? recurrenceEndDate;
  final int? recurrenceCount;
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
  bool _isUsingEndDate = true;

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

    // Determine if we're using end date or count
    _isUsingEndDate = widget.recurrenceEndDate != null || widget.recurrenceCount == null;

    // If recurrence type is weekly and no days are selected, initialize _recurrenceDays locally.
    // The parent (TaskDetailsContent) is responsible for setting these defaults in the actual task data
    // when the recurrence type is first set or loaded.
    if (_selectedRecurrenceType == RecurrenceType.weekly && (_recurrenceDays == null || _recurrenceDays!.isEmpty)) {
      _recurrenceDays = [WeekDays.values[DateTime.now().weekday - 1]]; // WeekDay enum is 0-based, weekday is 1-based
      // DO NOT call widget.onRecurrenceDaysChanged here; parent handles defaults.
    }

    // Initialize controllers
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

      // Update isUsingEndDate based on incoming values
      _isUsingEndDate = widget.recurrenceEndDate != null || widget.recurrenceCount == null;

      _updateControllers();
    }
  }

  void _updateControllers() {
    // Format dates for controllers
    if (_recurrenceStartDate != null) {
      _startDateController.text = DateTimeHelper.formatDateTime(_recurrenceStartDate);
    } else {
      _startDateController.clear();
    }

    if (_recurrenceEndDate != null) {
      _endDateController.text = DateTimeHelper.formatDateTime(_recurrenceEndDate);
    } else {
      _endDateController.clear();
    }

    // Set interval and count controllers
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

  String _getRecurrenceTypeLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceNone);
      case RecurrenceType.daily:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceDaily);
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
        InputDecorator(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall, vertical: 0),
            isDense: true,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<RecurrenceType>(
              value: _selectedRecurrenceType,
              isExpanded: true,
              isDense: true,
              items: RecurrenceType.values.map((type) {
                return DropdownMenuItem<RecurrenceType>(
                  value: type,
                  child: Text(_getRecurrenceTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRecurrenceType = value;

                    if (value == RecurrenceType.none) {
                      _recurrenceInterval = null;
                      _recurrenceDays = null;
                      _recurrenceStartDate = null;
                      _recurrenceEndDate = null;
                      _recurrenceCount = null;
                      _isUsingEndDate = true; // Default to end date when recurrence is off
                    } else {
                      // Set default interval if changing to a type that uses it
                      _recurrenceInterval ??= 1;

                      // Set default start date if none exists
                      _recurrenceStartDate ??= DateTime.now();

                      // Set default weekly days if type is weekly and no days are selected
                      if (value == RecurrenceType.weekly) {
                        if (_recurrenceDays == null || _recurrenceDays!.isEmpty) {
                          _recurrenceDays = [WeekDays.values[DateTime.now().weekday - 1]];
                        }
                      } else {
                        _recurrenceDays = null; // Clear days if not weekly
                      }

                      // Default end condition: if both end date and count are null, default to using end date.
                      // If one is already set, respect that.
                      if (_recurrenceEndDate == null && _recurrenceCount == null) {
                        _isUsingEndDate = true;
                      } else if (_recurrenceEndDate != null) {
                        _isUsingEndDate = true;
                      } else {
                        // _recurrenceCount != null
                        _isUsingEndDate = false;
                      }
                    }
                    _updateControllers(); // Update text controllers based on new local state
                  });

                  // Notify parent of ONLY the type change.
                  // Parent (TaskDetailsContent) will handle saving all dependent defaults.
                  widget.onRecurrenceTypeChanged(value);
                }
              },
            ),
          ),
        ),

        // Only show configuration options if a recurrence type is selected
        if (_selectedRecurrenceType != RecurrenceType.none) ...[
          const SizedBox(height: AppTheme.sizeLarge),

          // Interval configuration (for daily, weekly, monthly, yearly, custom)
          if (_selectedRecurrenceType != RecurrenceType.none) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _intervalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.translationService.translate(TaskTranslationKeys.recurrenceIntervalLabel),
                      border: const OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: AppTheme.sizeSmall, horizontal: AppTheme.sizeSmall),
                    ),
                    onChanged: (value) {
                      final interval = int.tryParse(value);
                      if (interval != null && interval > 0) {
                        setState(() {
                          _recurrenceInterval = interval;
                        });
                        widget.onRecurrenceIntervalChanged(interval);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.sizeSmall),
                Text(_getIntervalSuffix()),
              ],
            ),
          ],

          // Specific weekdays selector (only for weekly recurrence)
          if (_selectedRecurrenceType == RecurrenceType.weekly) ...[
            const SizedBox(height: AppTheme.sizeLarge),
            Text(
              widget.translationService.translate(TaskTranslationKeys.recurrenceWeekDaysLabel),
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: WeekDays.values.map((day) {
                final isSelected = _recurrenceDays?.contains(day) ?? false;
                return FilterChip(
                  label: Text(_getWeekDayLabel(day)),
                  labelStyle: TextStyle(fontSize: 13),
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.sizeXSmall),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _recurrenceDays ??= [];

                      if (selected) {
                        _recurrenceDays!.add(day);
                      } else {
                        _recurrenceDays!.remove(day);
                      }

                      // If empty, select all days
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
          const SizedBox(height: AppTheme.sizeLarge),

          // Recurrence date range
          Text(
            widget.translationService.translate(TaskTranslationKeys.recurrenceRangeLabel),
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.sizeSmall),

          // Start date
          Row(
            children: [
              Text(
                "${widget.translationService.translate(TaskTranslationKeys.recurrenceStartLabel)}: ",
                style: AppTheme.bodyMedium,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _recurrenceStartDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );

                    if (pickedDate != null) {
                      setState(() {
                        _recurrenceStartDate = pickedDate;
                        _startDateController.text = DateTimeHelper.formatDateTime(_recurrenceStartDate);
                      });
                      widget.onRecurrenceStartDateChanged(pickedDate);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _startDateController,
                      decoration: InputDecoration(
                        hintText: widget.translationService.translate(TaskTranslationKeys.selectDateHint),
                        suffixIcon: Icon(SharedUiConstants.calendarIcon, size: AppTheme.iconSizeSmall),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: AppTheme.sizeSmall, horizontal: AppTheme.sizeSmall),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.sizeSmall),

          // End type selector (end date or count)
          Wrap(
            spacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<bool>(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    value: true,
                    groupValue: _isUsingEndDate,
                    onChanged: (value) {
                      setState(() {
                        _isUsingEndDate = value ?? true;

                        // Reset the other option
                        if (_isUsingEndDate) {
                          _recurrenceCount = null;
                          widget.onRecurrenceCountChanged(null);
                        } else {
                          _recurrenceEndDate = null;
                          widget.onRecurrenceEndDateChanged(null);
                        }
                      });
                    },
                  ),
                  Text(
                    widget.translationService.translate(TaskTranslationKeys.recurrenceEndDateLabel),
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(width: AppTheme.sizeSmall),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<bool>(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    value: false,
                    groupValue: _isUsingEndDate,
                    onChanged: (value) {
                      setState(() {
                        _isUsingEndDate = value ?? true;

                        // Reset the other option and set defaults
                        if (!_isUsingEndDate) {
                          _recurrenceEndDate = null;
                          _recurrenceCount = _recurrenceCount ?? 10;
                          _countController.text = _recurrenceCount.toString();
                          widget.onRecurrenceEndDateChanged(null);
                          widget.onRecurrenceCountChanged(_recurrenceCount);
                        } else {
                          _recurrenceCount = null;
                          widget.onRecurrenceCountChanged(null);
                        }
                      });
                    },
                  ),
                  Text(
                    widget.translationService.translate(TaskTranslationKeys.recurrenceCountLabel),
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppTheme.sizeSmall),

          // End date selector (if using end date)
          if (_isUsingEndDate) ...[
            Row(
              children: [
                Text(
                  "${widget.translationService.translate(TaskTranslationKeys.recurrenceEndDateLabel)}: ",
                  style: AppTheme.bodyMedium,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _recurrenceEndDate ??
                            (_recurrenceStartDate?.add(const Duration(days: 30)) ??
                                DateTimeHelper.toUtcDateTime(DateTime.now()).add(const Duration(days: 30))),
                        firstDate: _recurrenceStartDate ?? DateTimeHelper.toUtcDateTime(DateTime.now()),
                        lastDate: DateTime(2100),
                      );

                      if (pickedDate != null) {
                        setState(() {
                          _recurrenceEndDate = pickedDate;
                          _endDateController.text = DateTimeHelper.formatDateTime(_recurrenceEndDate);
                        });
                        widget.onRecurrenceEndDateChanged(pickedDate);
                      }
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _endDateController,
                        decoration: InputDecoration(
                          hintText: widget.translationService.translate(TaskTranslationKeys.selectDateHint),
                          suffixIcon: Icon(SharedUiConstants.calendarIcon, size: AppTheme.iconSizeSmall),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: AppTheme.sizeSmall, horizontal: AppTheme.sizeSmall),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Count selector (if using count)
          if (!_isUsingEndDate) ...[
            Row(
              children: [
                Text(
                  "${widget.translationService.translate(TaskTranslationKeys.recurrenceCountLabel)}: ",
                  style: AppTheme.bodyMedium,
                ),
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: widget.translationService.translate(TaskTranslationKeys.enterCountHint),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: AppTheme.sizeSmall, horizontal: AppTheme.sizeSmall),
                    ),
                    onChanged: (value) {
                      final count = int.tryParse(value);
                      if (count != null && count > 0) {
                        setState(() {
                          _recurrenceCount = count;
                        });
                        widget.onRecurrenceCountChanged(count);
                      }
                    },
                  ),
                ),
              ],
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
}
