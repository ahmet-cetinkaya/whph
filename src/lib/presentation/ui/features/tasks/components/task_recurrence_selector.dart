import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart' hide Container;

import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

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

    // If recurrence type is daysOfWeek and no days are selected, initialize _recurrenceDays locally.
    // The parent (TaskDetailsContent) is responsible for setting these defaults in the actual task data
    // when the recurrence type is first set or loaded.
    if (_recurrenceType == RecurrenceType.daysOfWeek && (_recurrenceDays == null || _recurrenceDays!.isEmpty)) {
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

  String _getRecurrenceTypeLabel(RecurrenceType type, {bool plural = false}) {
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
                        Expanded(
                          child: Text(
                            label,
                            style: AppTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.sizeLarge),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: content,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  StyledIcon(icon, isActive: isActive),
                  const SizedBox(width: AppTheme.sizeLarge),
                  Text(
                    label,
                    style: AppTheme.labelLarge,
                  ),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recurrence Type
        _buildSection(
          label: widget.translationService.translate(TaskTranslationKeys.recurrenceLabel),
          icon: Icons.repeat,
          content: IntrinsicWidth(
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
                    // Reset fields when type changes
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
          ),
        ),

        // Only show configuration options if a recurrence type is selected
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
                      setState(() {
                        _recurrenceInterval = value;
                      });
                      widget.onRecurrenceIntervalChanged(value);
                    },
                  ),
                ),

              // Specific weekdays selector (only for daysOfWeek recurrence)
              if (_recurrenceType == RecurrenceType.weekly || _recurrenceType == RecurrenceType.daysOfWeek)
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.sizeLarge),
                      decoration: BoxDecoration(
                        color: AppTheme.surface1,
                        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const StyledIcon(Icons.calendar_view_week, isActive: true),
                              const SizedBox(width: AppTheme.sizeLarge),
                              Expanded(
                                child: Text(
                                  widget.translationService.translate(TaskTranslationKeys.recurrenceWeekDaysLabel),
                                  style: AppTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.sizeLarge),
                          Wrap(
                            spacing: AppTheme.sizeSmall,
                            runSpacing: AppTheme.sizeSmall,
                            alignment: WrapAlignment.center,
                            children: WeekDays.values.map((day) {
                              final isSelected = _recurrenceDays?.contains(day) ?? false;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    final currentDays = List<WeekDays>.from(_recurrenceDays ?? []);
                                    if (isSelected) {
                                      if (currentDays.length > 1) {
                                        currentDays.remove(day);
                                      }
                                    } else {
                                      currentDays.add(day);
                                    }
                                    _recurrenceDays = currentDays;
                                  });
                                  widget.onRecurrenceDaysChanged(_recurrenceDays);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? theme.colorScheme.primary : AppTheme.borderColor,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _getWeekDayLabel(day).substring(0, 1),
                                    style: TextStyle(
                                      color: isSelected ? theme.colorScheme.onPrimary : AppTheme.textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.sizeLarge),
                  ],
                ),

              // Start date
              _buildSection(
                label: widget.translationService.translate(TaskTranslationKeys.starts),
                icon: Icons.calendar_today,
                content: Semantics(
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

                      final result = await DatePickerDialog.show(
                        context: context,
                        config: config,
                      );

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
                          Text(
                            _startDateController.text,
                            style: AppTheme.bodyMedium,
                          ),
                          const SizedBox(width: AppTheme.sizeSmall),
                          const Icon(Icons.calendar_today, size: AppTheme.iconSizeSmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // End Condition Selection
              _buildSection(
                label: widget.translationService.translate(TaskTranslationKeys.recurrenceEndsLabel),
                icon: Icons.event_busy,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ToggleButtons(
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
                      renderBorder: false,
                      borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: 44,
                      ),
                      color: AppTheme.textColor,
                      selectedColor: theme.colorScheme.onPrimary,
                      fillColor: theme.colorScheme.primary,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
                          child: Text(widget.translationService.translate(TaskTranslationKeys.recurrenceEndsNever)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
                          child: Text(widget.translationService.translate(TaskTranslationKeys.recurrenceEndsOnDate)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
                          child: Text(widget.translationService.translate(TaskTranslationKeys.recurrenceEndsAfter)),
                        ),
                      ],
                    ),
                    if (_recurrenceEndDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.sizeMedium),
                        child: Semantics(
                          label: widget.translationService.translate(TaskTranslationKeys.recurrenceEndsOnDate),
                          button: true,
                          child: InkWell(
                            onTap: () async {
                              if (!context.mounted) return;

                              final config = DatePickerConfig(
                                selectionMode: DateSelectionMode.single,
                                initialDate: _recurrenceEndDate,
                                minDate: _getMinimumEndDate(),
                                maxDate: DateTime(2100),
                                formatType: DateFormatType.date,
                                showTime: false,
                                enableManualInput: true,
                                titleText: widget.translationService.translate(TaskTranslationKeys.recurrenceEndsLabel),
                                translations: {
                                  DateTimePickerTranslationKey.title:
                                      widget.translationService.translate(TaskTranslationKeys.recurrenceEndsLabel),
                                  DateTimePickerTranslationKey.confirm:
                                      widget.translationService.translate(SharedTranslationKeys.doneButton),
                                  DateTimePickerTranslationKey.cancel:
                                      widget.translationService.translate(SharedTranslationKeys.cancelButton),
                                },
                              );

                              final result = await DatePickerDialog.show(
                                context: context,
                                config: config,
                              );

                              if (result != null && !result.wasCancelled && result.selectedDate != null && mounted) {
                                final selectedDate = result.selectedDate!;
                                setState(() {
                                  _recurrenceEndDate = selectedDate;
                                  _endDateController.text = DateFormatService.formatForDisplay(selectedDate, context,
                                      type: DateFormatType.date);
                                });
                                widget.onRecurrenceEndDateChanged(selectedDate);
                              }
                            },
                            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _endDateController.text,
                                    style: AppTheme.bodyMedium,
                                  ),
                                  const SizedBox(width: AppTheme.sizeSmall),
                                  const Icon(Icons.calendar_today, size: AppTheme.iconSizeSmall),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_recurrenceCount != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.sizeMedium),
                        child: NumericInput(
                          value: _recurrenceCount ?? 1,
                          minValue: 1,
                          maxValue: 999,
                          onValueChanged: (value) {
                            setState(() {
                              _recurrenceCount = value;
                            });
                            widget.onRecurrenceCountChanged(value);
                          },
                          style: NumericInputStyle.contained,
                        ),
                      ),
                  ],
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
}
