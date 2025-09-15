import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:mediatr/mediatr.dart';
import 'package:intl/intl.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_time_record_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_total_duration_by_task_id_query.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_time_record_command.dart';
import 'package:whph/core/application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

enum EntityType { task, habit }

enum LoggingMode { addTime, setTotalForDay }

class TimeLoggingDialog extends StatefulWidget {
  final String entityId;
  final String entityName;
  final EntityType entityType;

  const TimeLoggingDialog({
    super.key,
    required this.entityId,
    required this.entityName,
    required this.entityType,
  });

  @override
  State<TimeLoggingDialog> createState() => _TimeLoggingDialogState();
}

class _TimeLoggingDialogState extends State<TimeLoggingDialog> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;
  LoggingMode _selectedMode = LoggingMode.addTime;

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final result = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.single,
        selectedDayHighlightColor: Theme.of(context).colorScheme.primary,
        firstDate: DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now(),
        currentDate: _selectedDate,
      ),
      dialogSize: const Size(325, 400),
    );

    if (result != null && result.isNotEmpty && result[0] != null) {
      setState(() {
        _selectedDate = result[0]!;
      });
    }
  }

  int _getDurationInSeconds() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    return (hours * 3600) + (minutes * 60);
  }

  bool _isValidInput() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    return hours >= 0 && minutes >= 0 && (hours > 0 || minutes > 0) && minutes < 60;
  }

  Future<void> _logTime() async {
    if (!_isValidInput()) {
      setState(() {
        _errorMessage = _getInvalidInputMessage();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final durationInSeconds = _getDurationInSeconds();

      if (_selectedMode == LoggingMode.setTotalForDay) {
        // Calculate current total for the day and determine delta
        final currentTotal = await _getCurrentTotalDuration();
        final delta = durationInSeconds - currentTotal;

        if (delta != 0) {
          await _addTimeRecord(delta);
        }
      } else {
        // Simple time addition
        await _addTimeRecord(durationInSeconds);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<int> _getCurrentTotalDuration() async {
    final startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    if (widget.entityType == EntityType.task) {
      final response = await _mediator.send<GetTotalDurationByTaskIdQuery, GetTotalDurationByTaskIdQueryResponse>(
        GetTotalDurationByTaskIdQuery(
          taskId: widget.entityId,
          startDate: startDate,
          endDate: endDate,
        ),
      );
      return response.totalDuration;
    } else {
      final response = await _mediator.send<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse>(
        GetTotalDurationByHabitIdQuery(
          habitId: widget.entityId,
          startDate: startDate,
          endDate: endDate,
        ),
      );
      return response.totalDuration;
    }
  }

  Future<void> _addTimeRecord(int duration) async {
    final customDateTime = _selectedDate;

    if (widget.entityType == EntityType.task) {
      await _mediator.send<AddTaskTimeRecordCommand, AddTaskTimeRecordCommandResponse>(
        AddTaskTimeRecordCommand(
          taskId: widget.entityId,
          duration: duration,
          customDateTime: customDateTime,
        ),
      );
    } else {
      await _mediator.send<AddHabitTimeRecordCommand, AddHabitTimeRecordCommandResponse>(
        AddHabitTimeRecordCommand(
          habitId: widget.entityId,
          duration: duration,
          customDateTime: customDateTime,
        ),
      );
    }
  }

  String _getInvalidInputMessage() {
    if (widget.entityType == EntityType.task) {
      return _translationService.translate(TaskTranslationKeys.timeLoggingInvalidInput);
    } else {
      return _translationService.translate(HabitTranslationKeys.timeLoggingInvalidInput);
    }
  }

  String _getTranslation(String key) {
    if (widget.entityType == EntityType.task) {
      return _translationService.translate('tasks.$key');
    } else {
      return _translationService.translate('habits.$key');
    }
  }

  String _getSharedTranslation(String key) {
    return _translationService.translate(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTranslation('time_logging.dialog_title')),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entity name
            Text(
              widget.entityName,
              style: AppTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.sizeLarge),

            // Mode selection
            Text(
              _getTranslation('time_logging.mode'),
              style: AppTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            SegmentedButton<LoggingMode>(
              segments: [
                ButtonSegment(
                  value: LoggingMode.addTime,
                  label: Text(_getTranslation('time_logging.add_time')),
                ),
                ButtonSegment(
                  value: LoggingMode.setTotalForDay,
                  label: Text(_getTranslation('time_logging.set_total')),
                ),
              ],
              selected: {_selectedMode},
              onSelectionChanged: (Set<LoggingMode> selection) {
                setState(() {
                  _selectedMode = selection.first;
                });
              },
            ),
            const SizedBox(height: AppTheme.sizeLarge),

            // Date selection
            Text(
              widget.entityType == EntityType.task
                  ? _getTranslation('time_logging.date')
                  : _getSharedTranslation(SharedTranslationKeys.date),
              style: AppTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sizeMedium,
                  vertical: AppTheme.sizeSmall,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppTheme.sizeSmall),
                    Text(
                      DateFormat.yMd().format(_selectedDate),
                      style: AppTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.sizeLarge),

            // Time input
            Text(
              _selectedMode == LoggingMode.addTime
                  ? _getTranslation('time_logging.duration')
                  : _getTranslation('time_logging.total_time'),
              style: AppTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hoursController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: widget.entityType == EntityType.task
                          ? _getTranslation('time_logging.hours')
                          : _getSharedTranslation(SharedTranslationKeys.hours),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: TextFormField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: widget.entityType == EntityType.task
                          ? _getTranslation('time_logging.minutes')
                          : _getSharedTranslation(SharedTranslationKeys.minutes),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            Text(
              _selectedMode == LoggingMode.addTime
                  ? _getTranslation('time_logging.add_time_description')
                  : _getTranslation('time_logging.set_total_description'),
              style: AppTheme.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppTheme.sizeMedium),
              Container(
                padding: const EdgeInsets.all(AppTheme.sizeMedium),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                ),
                child: Text(
                  _errorMessage!,
                  style: AppTheme.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      widget.entityType == EntityType.task
                          ? _getTranslation('cancel')
                          : _getSharedTranslation(SharedTranslationKeys.cancelButton),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading || !_isValidInput() ? null : _logTime,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.entityType == EntityType.task
                                ? _getTranslation('time_logging.log_time')
                                : _getSharedTranslation(SharedTranslationKeys.doneButton),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}