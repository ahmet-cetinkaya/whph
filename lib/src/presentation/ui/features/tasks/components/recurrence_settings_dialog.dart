import 'package:flutter/material.dart';
import 'package:whph/corePackages/acore/time/week_days.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/task_recurrence_selector.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_translation_keys.dart';

class RecurrenceSettingsDialog extends StatefulWidget {
  final RecurrenceType initialRecurrenceType;
  final int? initialRecurrenceInterval;
  final List<WeekDays>? initialRecurrenceDays;
  final DateTime? initialRecurrenceStartDate;
  final DateTime? initialRecurrenceEndDate;
  final int? initialRecurrenceCount;

  const RecurrenceSettingsDialog({
    super.key,
    required this.initialRecurrenceType,
    this.initialRecurrenceInterval,
    this.initialRecurrenceDays,
    this.initialRecurrenceStartDate,
    this.initialRecurrenceEndDate,
    this.initialRecurrenceCount,
  });

  @override
  State<RecurrenceSettingsDialog> createState() => _RecurrenceSettingsDialogState();
}

class _RecurrenceSettingsDialogState extends State<RecurrenceSettingsDialog> {
  late RecurrenceType _recurrenceType;
  int? _recurrenceInterval;
  List<WeekDays>? _recurrenceDays;
  DateTime? _recurrenceStartDate;
  DateTime? _recurrenceEndDate;
  int? _recurrenceCount;

  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _recurrenceType = widget.initialRecurrenceType;
    _recurrenceInterval = widget.initialRecurrenceInterval;
    _recurrenceDays = widget.initialRecurrenceDays;
    _recurrenceStartDate = widget.initialRecurrenceStartDate;
    _recurrenceEndDate = widget.initialRecurrenceEndDate;
    _recurrenceCount = widget.initialRecurrenceCount;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_translationService.translate(TaskTranslationKeys.recurrenceLabel)),
      content: SingleChildScrollView(
        child: TaskRecurrenceSelector(
          recurrenceType: _recurrenceType,
          recurrenceInterval: _recurrenceInterval,
          recurrenceDays: _recurrenceDays,
          recurrenceStartDate: _recurrenceStartDate,
          recurrenceEndDate: _recurrenceEndDate,
          recurrenceCount: _recurrenceCount,
          onRecurrenceTypeChanged: (type) {
            setState(() {
              _recurrenceType = type;
              if (type == RecurrenceType.none) {
                _recurrenceInterval = null;
                _recurrenceDays = null;
                _recurrenceStartDate = null;
                _recurrenceEndDate = null;
                _recurrenceCount = null;
              } else {
                _recurrenceInterval ??= 1;
                if (type == RecurrenceType.weekly && (_recurrenceDays == null || _recurrenceDays!.isEmpty)) {
                  _recurrenceDays = [WeekDays.values[DateTime.now().weekday - 1]];
                }
                _recurrenceStartDate ??= DateTime.now();
              }
            });
          },
          onRecurrenceIntervalChanged: (interval) {
            setState(() {
              _recurrenceInterval = interval;
            });
          },
          onRecurrenceDaysChanged: (days) {
            setState(() {
              _recurrenceDays = days;
            });
          },
          onRecurrenceStartDateChanged: (date) {
            setState(() {
              _recurrenceStartDate = date;
            });
          },
          onRecurrenceEndDateChanged: (date) {
            setState(() {
              _recurrenceEndDate = date;
              if (date != null) {
                _recurrenceCount = null; // Clear count if end date is set
              }
            });
          },
          onRecurrenceCountChanged: (count) {
            setState(() {
              _recurrenceCount = count;
              if (count != null) {
                _recurrenceEndDate = null; // Clear end date if count is set
              }
            });
          },
          translationService: _translationService,
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog without returning data
          },
        ),
        TextButton(
          child: Text(_translationService.translate(SharedTranslationKeys.saveButton)),
          onPressed: () {
            // Return the selected settings
            Navigator.of(context).pop({
              'recurrenceType': _recurrenceType,
              'recurrenceInterval': _recurrenceInterval,
              'recurrenceDays': _recurrenceDays,
              'recurrenceStartDate': _recurrenceStartDate,
              'recurrenceEndDate': _recurrenceEndDate,
              'recurrenceCount': _recurrenceCount,
            });
          },
        ),
      ],
    );
  }
}
