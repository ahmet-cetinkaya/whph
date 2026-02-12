import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:acore/components/numeric_input/numeric_input.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/shared/components/styled_icon.dart';
import 'package:whph/shared/components/detail_table.dart';

enum CustomReminderUnit {
  minutes,
  hours,
  days,
  weeks,
}

class CustomReminderDialog extends StatefulWidget {
  final ITranslationService translationService;
  final int? initialMinutes;

  const CustomReminderDialog({
    super.key,
    required this.translationService,
    this.initialMinutes,
  });

  static Future<int?> show(BuildContext context, ITranslationService translationService, {int? initialMinutes}) {
    return ResponsiveDialogHelper.showResponsiveDialog<int>(
      context: context,
      size: DialogSize.large,
      child: CustomReminderDialog(
        translationService: translationService,
        initialMinutes: initialMinutes,
      ),
    );
  }

  @override
  State<CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<CustomReminderDialog> {
  late int _value;
  late CustomReminderUnit _unit;
  final bool _useManualInput = false;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeValueAndUnit();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _initializeValueAndUnit() {
    if (widget.initialMinutes == null) {
      _value = 10;
      _unit = CustomReminderUnit.minutes;
      _textController.text = '10';
      return;
    }

    final minutes = widget.initialMinutes!;
    if (minutes % (60 * 24 * 7) == 0) {
      _value = minutes ~/ (60 * 24 * 7);
      _unit = CustomReminderUnit.weeks;
    } else if (minutes % (60 * 24) == 0) {
      _value = minutes ~/ (60 * 24);
      _unit = CustomReminderUnit.days;
    } else if (minutes % 60 == 0) {
      _value = minutes ~/ 60;
      _unit = CustomReminderUnit.hours;
    } else {
      _value = minutes;
      _unit = CustomReminderUnit.minutes;
    }
    _textController.text = _value.toString();
  }

  int _calculateTotalMinutes() {
    final value = _useManualInput ? _parseManualInput() : _value;
    switch (_unit) {
      case CustomReminderUnit.minutes:
        return value;
      case CustomReminderUnit.hours:
        return value * 60;
      case CustomReminderUnit.days:
        return value * 60 * 24;
      case CustomReminderUnit.weeks:
        return value * 60 * 24 * 7;
    }
  }

  int _parseManualInput() {
    try {
      final text = _textController.text.trim();
      if (text.isEmpty) return _value;

      // Handle simple math expressions like "2*60" for 2 hours
      if (text.contains('*')) {
        final parts = text.split('*');
        if (parts.length == 2) {
          final left = double.tryParse(parts[0].trim()) ?? 1.0;
          final right = double.tryParse(parts[1].trim()) ?? 1.0;
          return (left * right).round();
        }
      }

      // Handle decimal input
      if (text.contains('.')) {
        return (double.tryParse(text) ?? _value.toDouble()).round();
      }

      return int.tryParse(text) ?? _value;
    } catch (e) {
      return _value;
    }
  }

  String _getUnitLabel(CustomReminderUnit unit) {
    switch (unit) {
      case CustomReminderUnit.minutes:
        return widget.translationService.translate(SharedTranslationKeys.timeMinutes);
      case CustomReminderUnit.hours:
        return widget.translationService.translate(SharedTranslationKeys.timeHours);
      case CustomReminderUnit.days:
        return widget.translationService.translate(SharedTranslationKeys.timeDays);
      case CustomReminderUnit.weeks:
        return widget.translationService.translate(SharedTranslationKeys.timeWeeks);
    }
  }

  double _getMaxValueForUnit(CustomReminderUnit unit) {
    switch (unit) {
      case CustomReminderUnit.minutes:
        return 60;
      case CustomReminderUnit.hours:
        return 24;
      case CustomReminderUnit.days:
        return 30;
      case CustomReminderUnit.weeks:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.translationService.translate(TaskTranslationKeys.customReminderTitle),
          style: AppTheme.headlineSmall,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: widget.translationService.translate(SharedTranslationKeys.cancelButton),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_calculateTotalMinutes());
            },
            child: Text(
              widget.translationService.translate(SharedTranslationKeys.doneButton),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settings Table
              DetailTable(
                rowData: [
                  DetailTableRowData(
                    icon: Icons.category,
                    label: widget.translationService.translate(TaskTranslationKeys.reminderUnit),
                    widget: SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<CustomReminderUnit>(
                        value: _unit,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.sizeMedium,
                            vertical: AppTheme.sizeSmall,
                          ),
                          filled: true,
                          fillColor: AppTheme.surface2,
                        ),
                        dropdownColor: AppTheme.surface1,
                        items: CustomReminderUnit.values.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(
                              _getUnitLabel(unit),
                              style: AppTheme.bodyLarge,
                            ),
                          );
                        }).toList(),
                        onChanged: (newUnit) {
                          if (newUnit != null) {
                            setState(() {
                              _unit = newUnit;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.sizeMedium),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sizeSmall,
                  vertical: AppTheme.sizeLarge,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface1,
                  borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StyledIcon(
                          Icons.timer,
                          isActive: true,
                          size: AppTheme.iconSizeSmall,
                        ),
                        const SizedBox(width: AppTheme.sizeSmall),
                        Text(
                          widget.translationService.translate(TaskTranslationKeys.reminderTime),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.normal,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.sizeMedium),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NumericInput(
                          value: _value,
                          minValue: 1,
                          onValueChanged: (val) {
                            setState(() {
                              _value = val;
                            });
                          },
                          style: NumericInputStyle.minimal,
                        ),
                        Slider(
                          value: _value.toDouble().clamp(1.0, _getMaxValueForUnit(_unit)),
                          min: 1,
                          max: _getMaxValueForUnit(_unit),
                          divisions: _getMaxValueForUnit(_unit).toInt() - 1,
                          onChanged: (val) {
                            setState(() {
                              _value = val.round();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
