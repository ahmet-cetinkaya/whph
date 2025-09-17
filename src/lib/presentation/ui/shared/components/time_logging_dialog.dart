import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:acore/components/date_time_picker/date_time_picker_field.dart';
import 'package:acore/components/numeric_input.dart';

// Event class for time logging
class TimeLoggingSubmittedEvent {
  final String entityId;
  final DateTime date;
  final int durationInSeconds;
  final bool isSetTotalMode; // True for setTotalForDay, false for addTime

  TimeLoggingSubmittedEvent({
    required this.entityId,
    required this.date,
    required this.durationInSeconds,
    required this.isSetTotalMode,
  });
}

enum LoggingMode { addTime, setTotalForDay }

class TimeLoggingDialog extends StatefulWidget {
  final String entityId;
  final VoidCallback? onCancel;
  final Future<void> Function(TimeLoggingSubmittedEvent event)? onTimeLoggingSubmitted;

  const TimeLoggingDialog({
    super.key,
    required this.entityId,
    this.onCancel,
    this.onTimeLoggingSubmitted,
  });

  @override
  State<TimeLoggingDialog> createState() => _TimeLoggingDialogState();
}

class _TimeLoggingDialogState extends State<TimeLoggingDialog> {
  final _translationService = container.resolve<ITranslationService>();

  int _hours = 0;
  int _minutes = 0;
  final _dateController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;
  LoggingMode _selectedMode = LoggingMode.addTime;

  @override
  void initState() {
    super.initState();
    // Initialize date controller with current date
    _dateController.text = DateFormat.yMd().format(_selectedDate);
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime? selectedDate) {
    if (selectedDate != null) {
      setState(() {
        _selectedDate = selectedDate;
        // Update the date controller text
        _dateController.text = DateFormat.yMd().format(selectedDate);
      });
    }
  }

  int _getDurationInSeconds() {
    return (_hours * 3600) + (_minutes * 60);
  }

  void _onHoursChanged(int value) {
    setState(() {
      _hours = value;
    });
  }

  void _onMinutesChanged(int value) {
    setState(() {
      _minutes = value;
    });
  }

  bool _isValidInput() {
    final isZeroAllowed = _selectedMode == LoggingMode.setTotalForDay;
    return _hours >= 0 && _minutes >= 0 && _minutes < 60 && (isZeroAllowed || (_hours > 0 || _minutes > 0));
  }

  Future<void> _logTime() async {
    if (!_isValidInput()) {
      setState(() {
        _errorMessage = _translationService.translate(SharedTranslationKeys.unexpectedError);
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final durationInSeconds = _getDurationInSeconds();

      // Emit event instead of calling commands directly
      if (widget.onTimeLoggingSubmitted != null) {
        // For manual time logging, use actual current time if logging for today,
        // otherwise use the selected date with current time-of-day
        final now = DateTime.now();
        final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final todayOnly = DateTime(now.year, now.month, now.day);

        final DateTime occurredAt;
        if (selectedDateOnly.isAtSameMomentAs(todayOnly)) {
          // Logging for today - use current timestamp to preserve actual time
          occurredAt = now;
        } else {
          // Logging for past/future date - use selected date with current time-of-day
          occurredAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, now.hour, now.minute,
              now.second, now.millisecond);
        }

        final event = TimeLoggingSubmittedEvent(
          entityId: widget.entityId,
          date: occurredAt,
          durationInSeconds: durationInSeconds,
          isSetTotalMode: _selectedMode == LoggingMode.setTotalForDay,
        );
        await widget.onTimeLoggingSubmitted!(event);
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

  String _getTranslation(String key) {
    return _translationService.translate(key);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_getTranslation(TaskTranslationKeys.timeLoggingDialogTitle)),
      content: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode selection
            Text(
              _getTranslation(TaskTranslationKeys.timeLoggingMode),
              style: AppTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            SegmentedButton<LoggingMode>(
              segments: [
                ButtonSegment(
                  value: LoggingMode.addTime,
                  label: Row(
                    children: [
                      Icon(
                        Icons.add,
                        size: 16,
                      ),
                      const SizedBox(width: AppTheme.sizeSmall),
                      Text(_getTranslation(TaskTranslationKeys.timeLoggingAddTime)),
                    ],
                  ),
                ),
                ButtonSegment(
                  value: LoggingMode.setTotalForDay,
                  label: Row(
                    children: [
                      Icon(
                        Icons.equalizer,
                        size: 16,
                      ),
                      const SizedBox(width: AppTheme.sizeSmall),
                      Text(_getTranslation(TaskTranslationKeys.timeLoggingSetTotal)),
                    ],
                  ),
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

            // Short description moved to top
            Text(
              _selectedMode == LoggingMode.addTime
                  ? _getTranslation(TaskTranslationKeys.timeLoggingAddTimeDescription)
                  : _getTranslation(TaskTranslationKeys.timeLoggingSetTotalDescription),
              style: AppTheme.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.sizeLarge),

            // Date selection
            Text(
              _getTranslation(SharedTranslationKeys.date),
              style: AppTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            DateTimePickerField(
              controller: _dateController,
              hintText: DateFormat.yMd().format(_selectedDate),
              onConfirm: _onDateSelected,
              minDateTime: DateTime.now().subtract(const Duration(days: 30)),
              maxDateTime: DateTime.now(),
              initialValue: _selectedDate,
            ),
            const SizedBox(height: AppTheme.sizeLarge),

            // Time input
            Text(
              _selectedMode == LoggingMode.addTime
                  ? _getTranslation(TaskTranslationKeys.timeLoggingDuration)
                  : _getTranslation(TaskTranslationKeys.timeLoggingTotalTime),
              style: AppTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            Row(
              children: [
                Expanded(
                  child: NumericInput(
                    initialValue: 0,
                    minValue: 0,
                    onValueChanged: _onHoursChanged,
                    valueSuffix: _getTranslation(SharedTranslationKeys.hours),
                  ),
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: NumericInput(
                    initialValue: 0,
                    minValue: 0,
                    maxValue: 59,
                    decrementValue: 5,
                    incrementValue: 5,
                    onValueChanged: _onMinutesChanged,
                    valueSuffix: _getTranslation(SharedTranslationKeys.minutes),
                  ),
                ),
              ],
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

            // Action buttons with default style
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            widget.onCancel?.call();
                            Navigator.of(context).pop();
                          },
                    child: Text(_getTranslation(SharedTranslationKeys.cancelButton)),
                  ),
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading || !_isValidInput() ? null : _logTime,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_getTranslation(SharedTranslationKeys.doneButton)),
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
