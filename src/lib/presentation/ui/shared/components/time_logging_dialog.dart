import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:acore/components/date_time_picker/date_time_picker_field.dart';
import 'package:acore/components/numeric_input/numeric_input.dart';
import 'package:acore/components/numeric_input/numeric_input_translation_keys.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

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
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface1,
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeButton(
                        context: context,
                        mode: LoggingMode.addTime,
                        icon: Icons.add_circle_outline,
                        label: _getTranslation(SharedTranslationKeys.timeLoggingAddTime),
                      ),
                    ),
                    Expanded(
                      child: _buildModeButton(
                        context: context,
                        mode: LoggingMode.setTotalForDay,
                        icon: Icons.equalizer,
                        label: _getTranslation(SharedTranslationKeys.timeLoggingSetTotal),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.sizeXLarge),

              // Date Selection
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
                child: Text(
                  _getTranslation(SharedTranslationKeys.date),
                  style: AppTheme.labelLarge,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppTheme.sizeLarge),
                decoration: BoxDecoration(
                  color: AppTheme.surface1,
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                ),
                child: Row(
                  children: [
                    StyledIcon(Icons.calendar_today, isActive: true),
                    const SizedBox(width: AppTheme.sizeLarge),
                    Expanded(
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
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.sizeXLarge),

              // Time Input
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
                child: Text(
                  _selectedMode == LoggingMode.addTime
                      ? _getTranslation(SharedTranslationKeys.timeLoggingDuration)
                      : _getTranslation(SharedTranslationKeys.timeLoggingTotalTime),
                  style: AppTheme.labelLarge,
                ),
              ),

              Container(
                padding: const EdgeInsets.all(AppTheme.sizeLarge),
                decoration: BoxDecoration(
                  color: AppTheme.surface1,
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                ),
                child: Row(
                  children: [
                    StyledIcon(Icons.access_time_filled, isActive: true),
                    const SizedBox(width: AppTheme.sizeLarge),
                    Expanded(
                      child: AppThemeHelper.isSmallScreen(context)
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHourInput(),
                                const SizedBox(height: AppTheme.sizeSmall),
                                _buildMinuteInput(),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _buildHourInput(),
                                const SizedBox(width: AppTheme.sizeSmall),
                                _buildMinuteInput(),
                              ],
                            ),
                    ),
                  ],
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

  Widget _buildModeButton({
    required BuildContext context,
    required LoggingMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedMode == mode;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius - 4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? theme.colorScheme.onPrimary : AppTheme.textColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.colorScheme.onPrimary : AppTheme.textColor.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourInput() {
    return NumericInput(
      initialValue: 0,
      minValue: 0,
      onValueChanged: _onHoursChanged,
      valueSuffix: _getTranslation(SharedTranslationKeys.hours),
      translations: _getNumericInputTranslations(),
      style: NumericInputStyle.contained,
    );
  }

  Widget _buildMinuteInput() {
    return NumericInput(
      initialValue: 0,
      minValue: 0,
      maxValue: 59,
      decrementValue: 5,
      incrementValue: 5,
      onValueChanged: _onMinutesChanged,
      valueSuffix: _getTranslation(SharedTranslationKeys.minutes),
      translations: _getNumericInputTranslations(),
      style: NumericInputStyle.contained,
    );
  }
}
