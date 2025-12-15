import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart' hide Container;

import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_recurrence_selector/recurrence_weekday_selector.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_recurrence_selector/recurrence_end_condition_selector.dart';

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
  late RecurrenceType _recurrenceType;
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
    _recurrenceType = widget.recurrenceType;
    _recurrenceInterval = widget.recurrenceInterval ?? 1;
    _recurrenceDays = widget.recurrenceDays;
    _recurrenceStartDate = widget.recurrenceStartDate;
    _recurrenceEndDate = widget.recurrenceEndDate;
    _recurrenceCount = widget.recurrenceCount;

    if (_recurrenceType == RecurrenceType.daysOfWeek && (_recurrenceDays == null || _recurrenceDays!.isEmpty)) {
      _recurrenceDays = [WeekDays.values[DateTime.now().weekday - 1]];
    }

    _intervalController.text = _recurrenceInterval.toString();
    _countController.text = _recurrenceCount?.toString() ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      _recurrenceType = widget.recurrenceType;
      _recurrenceInterval = widget.recurrenceInterval ?? 1;
      _recurrenceDays = widget.recurrenceDays;
      _recurrenceStartDate = widget.recurrenceStartDate;
      _recurrenceEndDate = widget.recurrenceEndDate;
      _recurrenceCount = widget.recurrenceCount;

      _updateControllers();
    }
  }

  void _updateControllers() {
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

  DateTime _getMinimumEndDate() {
    if (widget.plannedDate != null) return widget.plannedDate!;
    if (_recurrenceStartDate != null) return _recurrenceStartDate!;
    return DateTime.now().toUtc();
  }

  String _getRecurrenceTypeLabel(RecurrenceType type, {bool plural = false}) {
    switch (type) {
      case RecurrenceType.none:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceNone);
      case RecurrenceType.daily:
        return widget.translationService.translate(TaskTranslationKeys.recurrenceDaily);
      case RecurrenceType.daysOfWeek:
        if (_recurrenceDays?.length == WeekDays.values.length) {
          return widget.translationService.translate(TaskTranslationKeys.everyDay);
        }
        return widget.translationService.translate(TaskTranslationKeys.recurrenceDaysOfWeek);
      case RecurrenceType.weekly:
        return plural
            ? widget.translationService.translate(TaskTranslationKeys.recurrenceWeeksPlural)
            : widget.translationService.translate(TaskTranslationKeys.recurrenceWeekly);
      case RecurrenceType.monthly:
        return plural
            ? widget.translationService.translate(TaskTranslationKeys.recurrenceMonthsPlural)
            : widget.translationService.translate(TaskTranslationKeys.recurrenceMonthly);
      case RecurrenceType.yearly:
        return plural
            ? widget.translationService.translate(TaskTranslationKeys.recurrenceYearsPlural)
            : widget.translationService.translate(TaskTranslationKeys.recurrenceYearly);
    }
  }

  Widget _buildSection({
    required String label,
    required IconData icon,
    required Widget content,
    bool isActive = true,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 350;

              if (isSmallScreen) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        StyledIcon(icon, isActive: isActive),
                        const SizedBox(width: AppTheme.sizeLarge),
                        Expanded(child: Text(label, style: AppTheme.labelLarge)),
                      ],
                    ),
                    const SizedBox(height: AppTheme.sizeLarge),
                    Align(alignment: Alignment.centerLeft, child: content),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  StyledIcon(icon, isActive: isActive),
                  const SizedBox(width: AppTheme.sizeLarge),
                  Text(label, style: AppTheme.labelLarge),
                  const Spacer(),
                  content,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppTheme.sizeLarge),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recurrence Type
        _buildSection(
          label: widget.translationService.translate(TaskTranslationKeys.recurrenceLabel),
          icon: Icons.repeat,
          content: _buildRecurrenceTypeDropdown(),
        ),

        // Configuration options
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interval
              if (_recurrenceType != RecurrenceType.none && _recurrenceType != RecurrenceType.daysOfWeek)
                _buildSection(
                  label: widget.translationService.translate(TaskTranslationKeys.recurrenceIntervalLabel),
                  icon: Icons.timer,
                  content: NumericInput(
                    value: _recurrenceInterval ?? 1,
                    minValue: 1,
                    maxValue: 999,
                    onValueChanged: (value) {
                      setState(() => _recurrenceInterval = value);
                      widget.onRecurrenceIntervalChanged(value);
                    },
                  ),
                ),

              // Weekday selector
              if (_recurrenceType == RecurrenceType.weekly || _recurrenceType == RecurrenceType.daysOfWeek)
                RecurrenceWeekdaySelector(
                  selectedDays: _recurrenceDays,
                  onDaysChanged: (days) {
                    setState(() => _recurrenceDays = days);
                    widget.onRecurrenceDaysChanged(days);
                  },
                  translationService: widget.translationService,
                ),

              // Start date
              _buildSection(
                label: widget.translationService.translate(TaskTranslationKeys.starts),
                icon: Icons.calendar_today,
                content: _buildStartDatePicker(),
              ),

              // End Condition
              _buildSection(
                label: widget.translationService.translate(TaskTranslationKeys.recurrenceEndsLabel),
                icon: Icons.event_busy,
                content: RecurrenceEndConditionSelector(
                  endDate: _recurrenceEndDate,
                  count: _recurrenceCount,
                  minimumEndDate: _getMinimumEndDate(),
                  onEndDateChanged: (date) {
                    setState(() {
                      _recurrenceEndDate = date;
                      if (date != null) {
                        _endDateController.text =
                            DateFormatService.formatForDisplay(date, context, type: DateFormatType.date);
                      } else {
                        _endDateController.clear();
                      }
                      _recurrenceCount = null;
                    });
                    widget.onRecurrenceEndDateChanged(date);
                    if (date != null) widget.onRecurrenceCountChanged(null);
                  },
                  onCountChanged: (count) {
                    setState(() {
                      _recurrenceCount = count;
                      _recurrenceEndDate = null;
                      _endDateController.clear();
                    });
                    widget.onRecurrenceCountChanged(count);
                    if (count != null) widget.onRecurrenceEndDateChanged(null);
                  },
                  translationService: widget.translationService,
                  endDateController: _endDateController,
                ),
              ),
            ],
          ),
          crossFadeState: _recurrenceType == RecurrenceType.none ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  Widget _buildRecurrenceTypeDropdown() {
    return IntrinsicWidth(
      child: DropdownButtonFormField<RecurrenceType>(
        value: _recurrenceType,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        isExpanded: false,
        icon: const Icon(Icons.arrow_drop_down),
        alignment: AlignmentDirectional.centerEnd,
        items: RecurrenceType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(
              _getRecurrenceTypeLabel(type),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _recurrenceType = value;
              if (_recurrenceType == RecurrenceType.none) {
                _recurrenceInterval = null;
                _recurrenceDays = null;
                _recurrenceStartDate = null;
                _recurrenceEndDate = null;
                _recurrenceCount = null;
              } else {
                _recurrenceInterval ??= 1;
                _recurrenceStartDate ??= widget.plannedDate ?? DateTime.now();
                if (_recurrenceType == RecurrenceType.weekly || _recurrenceType == RecurrenceType.daysOfWeek) {
                  _recurrenceDays ??= [WeekDays.values[DateTime.now().weekday - 1]];
                } else {
                  _recurrenceDays = null;
                }
              }
              _updateControllers();
            });
            widget.onRecurrenceTypeChanged(value);
            widget.onRecurrenceIntervalChanged(_recurrenceInterval);
            widget.onRecurrenceDaysChanged(_recurrenceDays);
            widget.onRecurrenceStartDateChanged(_recurrenceStartDate);
            widget.onRecurrenceEndDateChanged(_recurrenceEndDate);
            widget.onRecurrenceCountChanged(_recurrenceCount);
          }
        },
      ),
    );
  }

  Widget _buildStartDatePicker() {
    return Semantics(
      label: widget.translationService.translate(TaskTranslationKeys.recurrenceStartLabel),
      button: true,
      child: InkWell(
        onTap: () async {
          if (!context.mounted) return;

          final config = DatePickerConfig(
            selectionMode: DateSelectionMode.single,
            initialDate: _recurrenceStartDate,
            minDate: DateTime(2000),
            maxDate: DateTime(2100),
            formatType: DateFormatType.date,
            showTime: false,
            enableManualInput: true,
            titleText: widget.translationService.translate(TaskTranslationKeys.recurrenceStartLabel),
            translations: {
              DateTimePickerTranslationKey.title:
                  widget.translationService.translate(TaskTranslationKeys.recurrenceStartLabel),
              DateTimePickerTranslationKey.confirm:
                  widget.translationService.translate(SharedTranslationKeys.doneButton),
              DateTimePickerTranslationKey.cancel:
                  widget.translationService.translate(SharedTranslationKeys.cancelButton),
            },
          );

          final result = await DatePickerDialog.show(context: context, config: config);

          if (result != null && !result.wasCancelled && result.selectedDate != null && mounted) {
            final selectedDate = result.selectedDate!;
            setState(() {
              _recurrenceStartDate = selectedDate;
              _startDateController.text =
                  DateFormatService.formatForDisplay(selectedDate, context, type: DateFormatType.date);
            });
            widget.onRecurrenceStartDateChanged(selectedDate);
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_startDateController.text, style: AppTheme.bodyMedium),
              const SizedBox(width: AppTheme.sizeSmall),
              const Icon(Icons.calendar_today, size: AppTheme.iconSizeSmall),
            ],
          ),
        ),
      ),
    );
  }
}
