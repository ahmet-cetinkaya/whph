import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart' hide Container;
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/domain/features/tasks/models/recurrence_configuration.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_recurrence_selector/recurrence_weekday_selector.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_recurrence_selector/recurrence_weekly_time_selector.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_recurrence_selector/recurrence_end_condition_selector.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_recurrence_selector/recurrence_monthly_pattern_selector.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/domain/shared/constants/domain_log_components.dart';

class RecurrenceSettingsDialog extends StatefulWidget {
  final RecurrenceType initialRecurrenceType;
  final int? initialRecurrenceInterval;
  final List<WeekDays>? initialRecurrenceDays;
  final DateTime? initialRecurrenceStartDate;
  final DateTime? initialRecurrenceEndDate;
  final int? initialRecurrenceCount;
  final DateTime? plannedDate;
  final RecurrenceConfiguration? initialConfiguration;

  const RecurrenceSettingsDialog({
    super.key,
    required this.initialRecurrenceType,
    this.initialRecurrenceInterval,
    this.initialRecurrenceDays,
    this.initialRecurrenceStartDate,
    this.initialRecurrenceEndDate,
    this.initialRecurrenceCount,
    this.plannedDate,
    this.initialConfiguration,
  });

  @override
  State<RecurrenceSettingsDialog> createState() => _RecurrenceSettingsDialogState();
}

class _RecurrenceSettingsDialogState extends State<RecurrenceSettingsDialog> {
  RecurrenceConfiguration? _configuration;
  DateTime? _startDate;
  bool _showSpecificTimes = false;

  final _translationService = container.resolve<ITranslationService>();
  final TextEditingController _intervalController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _countController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeConfiguration();
  }

  void _initializeConfiguration() {
    if (widget.initialConfiguration != null) {
      _configuration = widget.initialConfiguration;
    } else if (widget.initialRecurrenceType != RecurrenceType.none) {
      // Migrate legacy settings to RecurrenceConfiguration
      RecurrenceFrequency frequency;
      switch (widget.initialRecurrenceType) {
        case RecurrenceType.daily:
          frequency = RecurrenceFrequency.daily;
          break;
        case RecurrenceType.weekly:
        case RecurrenceType.daysOfWeek:
          frequency = RecurrenceFrequency.weekly;
          break;
        case RecurrenceType.monthly:
          frequency = RecurrenceFrequency.monthly;
          break;
        case RecurrenceType.yearly:
          frequency = RecurrenceFrequency.yearly;
          break;
        case RecurrenceType.hourly:
          frequency = RecurrenceFrequency.hourly;
          break;
        case RecurrenceType.minutely:
          frequency = RecurrenceFrequency.minutely;
          break;
        default:
          frequency = RecurrenceFrequency.daily;
      }

      RecurrenceEndCondition endCondition = RecurrenceEndCondition.never;
      if (widget.initialRecurrenceEndDate != null)
        endCondition = RecurrenceEndCondition.date;
      else if (widget.initialRecurrenceCount != null) endCondition = RecurrenceEndCondition.count;

      var config = RecurrenceConfiguration(
        frequency: frequency,
        interval: widget.initialRecurrenceInterval ?? 1,
        daysOfWeek: widget.initialRecurrenceDays?.map((d) => d.index + 1).toList(),
        endCondition: endCondition,
        endDate: widget.initialRecurrenceEndDate,
        occurrenceCount: widget.initialRecurrenceCount,
        fromPolicy: RecurrenceFromPolicy.plannedDate,
      );

      // Populate monthly fields from plannedDate if it's a monthly recurrence
      if (frequency == RecurrenceFrequency.monthly) {
        final date = widget.plannedDate ?? DateTime.now();
        config = config.copyWith(
          monthlyPatternType: MonthlyPatternType.specificDay,
          dayOfMonth: date.day,
          weekOfMonth: (date.day - 1) ~/ 7 + 1,
          dayOfWeek: date.weekday,
        );
      }
      _configuration = config;
    } else {
      _configuration = null;
    }
    
    _showSpecificTimes = _configuration?.weeklySchedule != null && _configuration!.weeklySchedule!.isNotEmpty;
    
    if (_showSpecificTimes && _configuration?.daysOfWeek != null) {
      _syncScheduleWithDays();
    }
  }

  void _syncScheduleWithDays() {
    if (_configuration?.daysOfWeek == null) return;

    final currentSchedule = List<WeeklySchedule>.from(_configuration!.weeklySchedule ?? []);
    final days = _configuration!.daysOfWeek!;

    // Remove days no longer selected
    currentSchedule.removeWhere((s) => !days.contains(s.dayOfWeek));

    // Add missing days with default time (9:00 AM)
    for (final day in days) {
      if (!currentSchedule.any((s) => s.dayOfWeek == day)) {
        currentSchedule.add(WeeklySchedule(
          dayOfWeek: day,
          hour: 9,
          minute: 0,
        ));
      }
    }
    
    currentSchedule.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    _configuration = _configuration!.copyWith(
      weeklySchedule: currentSchedule,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialRecurrenceStartDate != null) {
      _startDate = widget.initialRecurrenceStartDate;
    }
    _updateControllers();
  }

  void _updateControllers() {
    // Check if configuration is null (RecurrenceType.none)
    if (_configuration == null) {
      _intervalController.clear();
      _countController.clear();
      _startDateController.clear();
      _endDateController.clear();
      return;
    }

    _intervalController.text = _configuration!.interval.toString();
    _countController.text = _configuration!.occurrenceCount?.toString() ?? '';

    if (_startDate != null) {
      _startDateController.text =
          DateFormatService.formatForDisplay(_startDate!, context, type: DateFormatType.dateTime);
    } else {
      _startDateController.clear();
    }

    if (_configuration!.endDate != null) {
      _endDateController.text =
          DateFormatService.formatForDisplay(_configuration!.endDate!, context, type: DateFormatType.dateTime);
    } else {
      _endDateController.clear();
    }
  }

  void _handleSave() {
    Navigator.of(context).pop({
      'recurrenceConfiguration': _configuration,
      'recurrenceStartDate': _startDate,
    });
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _translationService.translate(TaskTranslationKeys.recurrenceLabel),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: _translationService.translate(SharedTranslationKeys.cancelButton),
        ),
        actions: [
          TextButton(
            onPressed: _handleSave,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(_translationService.translate(SharedTranslationKeys.doneButton)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection(
                label: _translationService.translate(TaskTranslationKeys.recurrenceLabel),
                icon: Icons.repeat,
                content: _buildFrequencyDropdown(),
              ),
              if (_configuration != null) ...[
                _buildSection(
                  label: _translationService.translate(TaskTranslationKeys.recurrenceIntervalLabel),
                  icon: Icons.timer,
                  content: NumericInput(
                    value: _configuration!.interval,
                    minValue: RecurrenceConfigurationValidation.minInterval,
                    maxValue: RecurrenceConfigurationValidation.maxInterval,
                    onValueChanged: (value) {
                      setState(() => _configuration = _configuration!.copyWith(interval: value));
                    },
                    style: NumericInputStyle.contained,
                  ),
                ),
                if (_configuration!.frequency == RecurrenceFrequency.weekly)
                  _buildSection(
                    label: _translationService.translate(TaskTranslationKeys.recurrenceWeekDaysLabel),
                    icon: Icons.calendar_view_week,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RecurrenceWeekdaySelector(
                          selectedDays: _configuration!.daysOfWeek?.map((d) => WeekDays.values[d - 1]).toList() ?? [],
                          onDaysChanged: (days) {
                            setState(() {
                              final newDays = days.map((d) => d.index + 1).toList();
                              _configuration = _configuration!.copyWith(
                                daysOfWeek: newDays,
                              );
                              if (_showSpecificTimes) {
                                _syncScheduleWithDays();
                              }
                            });
                          },
                          translationService: _translationService,
                        ),
                        const SizedBox(height: AppTheme.sizeMedium),
                        Row(
                          children: [
                            Switch(
                              value: _showSpecificTimes,
                              onChanged: (value) {
                                setState(() {
                                  _showSpecificTimes = value;
                                  if (!value) {
                                    _configuration = _configuration!.copyWith(weeklySchedule: []);
                                  } else {
                                    _syncScheduleWithDays();
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: AppTheme.sizeSmall),
                            Text(
                              'Different times per day',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        if (_showSpecificTimes) ...[
                          const SizedBox(height: AppTheme.sizeMedium),
                          RecurrenceWeeklyTimeSelector(
                            selectedDays: _configuration!.daysOfWeek?.map((d) => WeekDays.values[d - 1]).toList() ?? [],
                            schedule: _configuration!.weeklySchedule,
                            onScheduleChanged: (schedule) {
                              setState(() {
                                _configuration = _configuration!.copyWith(
                                  weeklySchedule: schedule,
                                );
                              });
                            },
                            translationService: _translationService,
                          ),
                        ],
                      ],
                    ),
                  ),
                if (_configuration!.frequency == RecurrenceFrequency.monthly)
                  _buildSection(
                    label: _translationService.translate(TaskTranslationKeys.recurrenceMonthlyPatternLabel),
                    icon: Icons.calendar_month,
                    content: RecurrenceMonthlyPatternSelector(
                      patternType: _configuration!.monthlyPatternType ?? MonthlyPatternType.specificDay,
                      dayOfMonth: _configuration!.dayOfMonth,
                      weekOfMonth: _configuration!.weekOfMonth,
                      dayOfWeek: _configuration!.dayOfWeek,
                      initialDate: widget.plannedDate ?? DateTime.now(),
                      translationService: _translationService,
                      onChanged: (patternType, dayOfMonth, weekOfMonth, dayOfWeek) {
                        setState(() {
                          _configuration = _configuration!.copyWith(
                            monthlyPatternType: patternType,
                            dayOfMonth: dayOfMonth,
                            weekOfMonth: weekOfMonth,
                            dayOfWeek: dayOfWeek,
                          );
                        });
                      },
                    ),
                  ),
                _buildSection(
                  label: _translationService.translate(TaskTranslationKeys.starts),
                  icon: Icons.calendar_today,
                  content: _buildStartDatePicker(),
                ),
                _buildSection(
                  label: _translationService.translate(TaskTranslationKeys.recurrenceEndsLabel),
                  icon: Icons.event_busy,
                  content: RecurrenceEndConditionSelector(
                    endDate: _configuration!.endDate,
                    count: _configuration!.occurrenceCount,
                    minimumEndDate: _getMinimumEndDate(),
                    onEndDateChanged: (date) {
                      setState(() {
                        _configuration = _configuration!.copyWith(
                          endDate: date,
                          occurrenceCount: null,
                          endCondition: date != null ? RecurrenceEndCondition.date : RecurrenceEndCondition.never,
                        );
                      });
                      _updateControllers();
                    },
                    onCountChanged: (count) {
                      setState(() {
                        _configuration = _configuration!.copyWith(
                          occurrenceCount: count,
                          endDate: null,
                          endCondition: count != null ? RecurrenceEndCondition.count : RecurrenceEndCondition.never,
                        );
                      });
                      _updateControllers();
                    },
                    translationService: _translationService,
                    endDateController: _endDateController,
                  ),
                ),
                _buildAdvancedSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyDropdown() {
    final currentFrequency = _configuration?.frequency;

    return IntrinsicWidth(
      child: DropdownButtonFormField<RecurrenceFrequency?>(
        value: currentFrequency,
        decoration: const InputDecoration(border: InputBorder.none),
        isExpanded: false,
        icon: const Icon(Icons.arrow_drop_down),
        alignment: AlignmentDirectional.centerStart,
        items: [
          DropdownMenuItem<RecurrenceFrequency?>(
            value: null,
            child: Text(_translationService.translate(TaskTranslationKeys.recurrenceNone)),
          ),
          ...RecurrenceFrequency.values.map((f) {
            return DropdownMenuItem<RecurrenceFrequency?>(
              value: f,
              child: Text(_getRecurrenceFrequencyLabel(f)),
            );
          }),
        ],
        onChanged: (value) {
          setState(() {
            if (value == null) {
              _configuration = null;
            } else {
              _configuration ??= RecurrenceConfiguration(
                frequency: value,
                interval: 1,
                fromPolicy: RecurrenceFromPolicy.plannedDate,
              );
              _configuration = _configuration!.copyWith(frequency: value);

              _applyDefaultsForFrequency(value);

              _startDate ??= widget.plannedDate ?? DateTime.now();
            }
            _updateControllers();
          });
        },
      ),
    );
  }

  Widget _buildSection({
    required String label,
    required IconData icon,
    required Widget content,
    String? description,
    bool isActive = true,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 500;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildLabelArea(icon, label, description, isActive),
                    ),
                    const SizedBox(width: AppTheme.sizeLarge),
                    Expanded(
                      flex: 7,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: content,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLabelArea(icon, label, description, isActive),
                    const SizedBox(height: AppTheme.sizeLarge),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: content,
                    ),
                  ],
                );
              }
            },
          ),
        ),
        const SizedBox(height: AppTheme.sizeLarge),
      ],
    );
  }

  Widget _buildLabelArea(IconData icon, String label, String? description, bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StyledIcon(icon, isActive: isActive),
        const SizedBox(width: AppTheme.sizeLarge),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.labelLarge),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.secondaryTextColor,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return _buildSection(
      label: _translationService.translate(TaskTranslationKeys.recurrenceRegenerateLabel),
      description: _translationService.translate(TaskTranslationKeys.recurrenceRegenerateDescription),
      icon: Icons.autorenew,
      content: Switch(
        value: _configuration!.fromPolicy == RecurrenceFromPolicy.completionDate,
        onChanged: (value) {
          setState(() {
            _configuration = _configuration!.copyWith(
              fromPolicy: value ? RecurrenceFromPolicy.completionDate : RecurrenceFromPolicy.plannedDate,
            );
          });
        },
      ),
    );
  }

  Widget _buildStartDatePicker() {
    return Semantics(
      label: _translationService.translate(TaskTranslationKeys.recurrenceStartLabel),
      button: true,
      child: InkWell(
        onTap: () async {
          if (!context.mounted) return;

          try {
            final config = DatePickerConfig(
              selectionMode: DateSelectionMode.single,
              initialDate: _startDate,
              minDate: DateTime(2000),
              maxDate: DateTime(2100),
              formatType: DateFormatType.date,
              showTime: false,
              enableManualInput: true,
              titleText: _translationService.translate(TaskTranslationKeys.recurrenceStartLabel),
              translations: {
                DateTimePickerTranslationKey.title:
                    _translationService.translate(TaskTranslationKeys.recurrenceStartLabel),
                DateTimePickerTranslationKey.confirm: _translationService.translate(SharedTranslationKeys.doneButton),
                DateTimePickerTranslationKey.cancel: _translationService.translate(SharedTranslationKeys.cancelButton),
              },
            );

            final result = await DatePickerDialog.show(context: context, config: config);

            if (!mounted) return;

            if (result != null && !result.wasCancelled && result.selectedDate != null) {
              final selectedDate = result.selectedDate!;
              setState(() {
                _startDate = selectedDate;
              });
              _updateControllers();
            }
          } catch (e, stackTrace) {
            Logger.error(
              'RecurrenceSettingsDialog: Error showing date picker [$TaskErrorIds.datePickerShowFailed]',
              error: e,
              stackTrace: stackTrace,
              component: DomainLogComponents.task,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_translationService.translate(SharedTranslationKeys.unexpectedError)),
                ),
              );
            }
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

  DateTime _getMinimumEndDate() {
    if (widget.plannedDate != null) return widget.plannedDate!;
    if (_startDate != null) return _startDate!;
    return DateTime.now().toUtc();
  }

  String _getRecurrenceFrequencyLabel(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return _translationService.translate(TaskTranslationKeys.recurrenceDaily);
      case RecurrenceFrequency.weekly:
        return _translationService.translate(TaskTranslationKeys.recurrenceWeekly);
      case RecurrenceFrequency.monthly:
        return _translationService.translate(TaskTranslationKeys.recurrenceMonthly);
      case RecurrenceFrequency.yearly:
        return _translationService.translate(TaskTranslationKeys.recurrenceYearly);
      case RecurrenceFrequency.hourly:
        return _translationService.translate(TaskTranslationKeys.recurrenceHourly);
      case RecurrenceFrequency.minutely:
        return _translationService.translate(TaskTranslationKeys.recurrenceMinutely);
    }
  }

  void _applyDefaultsForFrequency(RecurrenceFrequency frequency) {
    if (frequency == RecurrenceFrequency.weekly &&
        (_configuration!.daysOfWeek == null || _configuration!.daysOfWeek!.isEmpty)) {
      _configuration = _configuration!.copyWith(
        daysOfWeek: [DateTime.now().weekday],
      );
    } else if (frequency == RecurrenceFrequency.monthly) {
      final date = _startDate ?? widget.plannedDate ?? DateTime.now();
      _configuration = _configuration!.copyWith(
        monthlyPatternType: _configuration!.monthlyPatternType ?? MonthlyPatternType.specificDay,
        dayOfMonth: _configuration!.dayOfMonth ?? date.day,
        weekOfMonth: _configuration!.weekOfMonth ?? (date.day - 1) ~/ 7 + 1,
        dayOfWeek: _configuration!.dayOfWeek ?? date.weekday,
      );
    }
  }
}
