import 'package:flutter/material.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:domain/features/tasks/models/recurrence_configuration.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

class RecurrenceMonthlyPatternSelector extends StatefulWidget {
  final MonthlyPatternType patternType;
  final int? dayOfMonth;
  final int? weekOfMonth;
  final int? dayOfWeek;
  final DateTime initialDate;
  final Function(MonthlyPatternType, int?, int?, int?) onChanged;
  final ITranslationService translationService;

  const RecurrenceMonthlyPatternSelector({
    super.key,
    required this.patternType,
    this.dayOfMonth,
    this.weekOfMonth,
    this.dayOfWeek,
    required this.initialDate,
    required this.onChanged,
    required this.translationService,
  });

  @override
  State<RecurrenceMonthlyPatternSelector> createState() => _RecurrenceMonthlyPatternSelectorState();
}

class _RecurrenceMonthlyPatternSelectorState extends State<RecurrenceMonthlyPatternSelector> {
  late MonthlyPatternType _patternType;
  late int _dayOfMonth;
  late int _weekOfMonth;
  late int _dayOfWeek;

  @override
  void initState() {
    super.initState();
    _patternType = widget.patternType;
    _dayOfMonth = widget.dayOfMonth ?? widget.initialDate.day;
    _weekOfMonth = widget.weekOfMonth ?? 1; // Default to 1st
    _dayOfWeek = widget.dayOfWeek ?? widget.initialDate.weekday;
  }

  @override
  void didUpdateWidget(RecurrenceMonthlyPatternSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.patternType != oldWidget.patternType) {
      _patternType = widget.patternType;
    }
    if (widget.dayOfMonth != oldWidget.dayOfMonth) {
      _dayOfMonth = widget.dayOfMonth ?? widget.initialDate.day;
    }
    if (widget.weekOfMonth != oldWidget.weekOfMonth) {
      _weekOfMonth = widget.weekOfMonth ?? 1;
    }
    if (widget.dayOfWeek != oldWidget.dayOfWeek) {
      _dayOfWeek = widget.dayOfWeek ?? widget.initialDate.weekday;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTypeSelector(),
        const SizedBox(height: AppTheme.sizeMedium),
        if (_patternType == MonthlyPatternType.specificDay)
          _buildSpecificDaySelector()
        else
          _buildRelativeDaySelector(),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<MonthlyPatternType>(
      segments: [
        ButtonSegment<MonthlyPatternType>(
          value: MonthlyPatternType.specificDay,
          label: Text(widget.translationService.translate(TaskTranslationKeys.recurrenceOnSpecificDay)),
        ),
        ButtonSegment<MonthlyPatternType>(
          value: MonthlyPatternType.relativeDay,
          label: Text(widget.translationService.translate(TaskTranslationKeys.recurrenceOnRelativeDay)),
        ),
      ],
      selected: {_patternType},
      onSelectionChanged: (Set<MonthlyPatternType> newSelection) {
        setState(() {
          _patternType = newSelection.first;
        });
        _notifyChanged();
      },
      showSelectedIcon: false,
    );
  }

  Widget _buildSpecificDaySelector() {
    return Row(
      children: [
        Text(widget.translationService.translate(TaskTranslationKeys.recurrenceOnThe)),
        const SizedBox(width: AppTheme.sizeMedium),
        SizedBox(
          width: 80,
          child: DropdownButtonFormField<int>(
            value: _dayOfMonth,
            items: List.generate(31, (index) {
              final day = index + 1;
              return DropdownMenuItem(
                value: day,
                child: Text('$day'),
              );
            }),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _dayOfMonth = value;
                });
                _notifyChanged();
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelativeDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.translationService.translate(TaskTranslationKeys.recurrenceOnThe)),
        const SizedBox(height: AppTheme.sizeSmall),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _weekOfMonth,
                items: [
                  DropdownMenuItem(
                      value: 1,
                      child:
                          Text(widget.translationService.translate(TaskTranslationKeys.recurrenceWeekModifierFirst))),
                  DropdownMenuItem(
                      value: 2,
                      child:
                          Text(widget.translationService.translate(TaskTranslationKeys.recurrenceWeekModifierSecond))),
                  DropdownMenuItem(
                      value: 3,
                      child:
                          Text(widget.translationService.translate(TaskTranslationKeys.recurrenceWeekModifierThird))),
                  DropdownMenuItem(
                      value: 4,
                      child:
                          Text(widget.translationService.translate(TaskTranslationKeys.recurrenceWeekModifierFourth))),
                  DropdownMenuItem(
                      value: 5,
                      child: Text(widget.translationService.translate(TaskTranslationKeys.recurrenceWeekModifierLast))),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _weekOfMonth = value;
                    });
                    _notifyChanged();
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.sizeMedium),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _dayOfWeek,
                items: WeekDays.values.map((wd) {
                  return DropdownMenuItem(
                    value: wd.index + 1, // 1-7
                    child: Text(widget.translationService
                        .translate(SharedTranslationKeys.getWeekDayTranslationKey(wd.index + 1, short: true))),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _dayOfWeek = value;
                    });
                    _notifyChanged();
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _notifyChanged() {
    widget.onChanged(
      _patternType,
      _patternType == MonthlyPatternType.specificDay ? _dayOfMonth : null,
      _patternType == MonthlyPatternType.relativeDay ? _weekOfMonth : null,
      _patternType == MonthlyPatternType.relativeDay ? _dayOfWeek : null,
    );
  }
}
