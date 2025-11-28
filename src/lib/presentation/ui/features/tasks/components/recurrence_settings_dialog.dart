import 'package:flutter/material.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_recurrence_selector.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';

class RecurrenceSettingsDialog extends StatefulWidget {
  final RecurrenceType initialRecurrenceType;
  final int? initialRecurrenceInterval;
  final List<WeekDays>? initialRecurrenceDays;
  final DateTime? initialRecurrenceStartDate;
  final DateTime? initialRecurrenceEndDate;
  final int? initialRecurrenceCount;
  final DateTime? plannedDate;

  const RecurrenceSettingsDialog({
    super.key,
    required this.initialRecurrenceType,
    this.initialRecurrenceInterval,
    this.initialRecurrenceDays,
    this.initialRecurrenceStartDate,
    this.initialRecurrenceEndDate,
    this.initialRecurrenceCount,
    this.plannedDate,
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

  void _handleSave() {
    Navigator.of(context).pop({
      'recurrenceType': _recurrenceType,
      'recurrenceInterval': _recurrenceInterval,
      'recurrenceDays': _recurrenceDays,
      'recurrenceStartDate': _recurrenceStartDate,
      'recurrenceEndDate': _recurrenceEndDate,
      'recurrenceCount': _recurrenceCount,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _translationService.translate(TaskTranslationKeys.recurrenceLabel),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        backgroundColor: theme.colorScheme.surface,
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
          child: TaskRecurrenceSelector(
            recurrenceType: _recurrenceType,
            recurrenceInterval: _recurrenceInterval,
            recurrenceDays: _recurrenceDays,
            recurrenceStartDate: _recurrenceStartDate,
            recurrenceEndDate: _recurrenceEndDate,
            recurrenceCount: _recurrenceCount,
            plannedDate: widget.plannedDate,
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
                  if (type == RecurrenceType.daysOfWeek) {
                    _recurrenceInterval = 1;
                  } else {
                    _recurrenceInterval ??= 1;
                  }
                  if (type == RecurrenceType.daysOfWeek && (_recurrenceDays == null || _recurrenceDays!.isEmpty)) {
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
                  _recurrenceCount = null;
                }
              });
            },
            onRecurrenceCountChanged: (count) {
              setState(() {
                _recurrenceCount = count;
                if (count != null) {
                  _recurrenceEndDate = null;
                }
              });
            },
            translationService: _translationService,
          ),
        ),
      ),
    );
  }
}
