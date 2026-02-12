import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:acore/components/date_time_picker/date_time_picker_field.dart';
import 'package:acore/components/numeric_input/numeric_input.dart';
import 'package:acore/components/numeric_input/numeric_input_translation_keys.dart';

import 'package:whph/shared/components/styled_icon.dart';
import 'package:whph/shared/components/custom_tab_bar.dart';

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

enum TimeUnit { minutes, hours }

class _TimeLoggingDialogState extends State<TimeLoggingDialog> {
  final _translationService = container.resolve<ITranslationService>();

  int _durationValue = 0;
  TimeUnit _selectedUnit = TimeUnit.minutes;
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
    if (_selectedUnit == TimeUnit.hours) {
      return _durationValue * 3600;
    }
    return _durationValue * 60;
  }

  void _onDurationChanged(int value) {
    setState(() {
      _durationValue = value;
    });
  }

  void _onUnitChanged(TimeUnit? unit) {
    if (unit != null) {
      setState(() {
        _selectedUnit = unit;
      });
    }
  }

  bool _isValidInput() {
    final isZeroAllowed = _selectedMode == LoggingMode.setTotalForDay;
    return _durationValue >= 0 && (isZeroAllowed || _durationValue > 0);
  }

  Future<void> _logTime() async {
    if (!_isValidInput()) {
      setState(() {
        _errorMessage = _translationService.translate(SharedTranslationKeys.timeLoggingInvalidInput);
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

  Map<NumericInputTranslationKey, String> _getNumericInputTranslations() {
    return NumericInputTranslationKey.values.asMap().map(
          (key, value) =>
              MapEntry(value, _translationService.translate(SharedTranslationKeys.mapNumericInputKey(value))),
        );
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getTranslation(SharedTranslationKeys.timeLoggingDialogTitle),
          style: AppTheme.headlineSmall,
        ),
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.onCancel?.call();
            Navigator.of(context).pop();
          },
          tooltip: _getTranslation(SharedTranslationKeys.backButton),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading || !_isValidInput() ? null : _logTime,
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Text(
                    _getTranslation(SharedTranslationKeys.doneButton),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mode Selection
              CustomTabBar(
                selectedIndex: _selectedMode == LoggingMode.addTime ? 0 : 1,
                onTap: (index) {
                  setState(() {
                    _selectedMode = index == 0 ? LoggingMode.addTime : LoggingMode.setTotalForDay;
                  });
                },
                items: [
                  CustomTabItem(
                    icon: Icons.add_circle_outline,
                    label: _getTranslation(SharedTranslationKeys.timeLoggingAddTime),
                  ),
                  CustomTabItem(
                    icon: Icons.equalizer,
                    label: _getTranslation(SharedTranslationKeys.timeLoggingSetTotal),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.sizeXLarge),

              // Date Selection
              _buildSection(
                label: _getTranslation(SharedTranslationKeys.date),
                icon: Icons.calendar_today,
                content: IntrinsicWidth(
                  child: DateTimePickerField(
                    controller: _dateController,
                    onConfirm: _onDateSelected,
                    minDateTime: DateTime.now().subtract(const Duration(days: 30)),
                    maxDateTime: DateTime.now(),
                    initialValue: _selectedDate,
                    translateKey: (key) => _getTranslation(SharedTranslationKeys.mapDateTimePickerKey(key)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.sizeXLarge),

              // Time Input
              _buildSection(
                label: _selectedMode == LoggingMode.addTime
                    ? _getTranslation(SharedTranslationKeys.timeLoggingDuration)
                    : _getTranslation(SharedTranslationKeys.timeLoggingTotalTime),
                icon: Icons.access_time_filled,
                content: IntrinsicWidth(
                  child: _buildDurationInput(),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppTheme.sizeMedium),
                AnimatedOpacity(
                  opacity: _errorMessage != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.sizeMedium),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: AppTheme.sizeSmall),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTheme.bodySmall.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationInput() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: NumericInput(
            initialValue: 0,
            minValue: 0,
            incrementValue: 1,
            decrementValue: 1,
            onValueChanged: _onDurationChanged,
            translations: _getNumericInputTranslations(),
            style: NumericInputStyle.contained,
          ),
        ),
        const SizedBox(width: AppTheme.sizeSmall),
        DropdownButton<TimeUnit>(
          value: _selectedUnit,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down),
          onChanged: _onUnitChanged,
          items: TimeUnit.values.map((TimeUnit unit) {
            return DropdownMenuItem<TimeUnit>(
              value: unit,
              child: Text(
                unit == TimeUnit.minutes
                    ? _getTranslation(SharedTranslationKeys.minutes)
                    : _getTranslation(SharedTranslationKeys.hours),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
