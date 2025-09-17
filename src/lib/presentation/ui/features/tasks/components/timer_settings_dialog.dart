import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/corePackages/acore/lib/components/numeric_input.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class TimerSettingsDialog extends StatefulWidget {
  final TimerMode initialTimerMode;
  final int initialWorkDuration;
  final int initialBreakDuration;
  final int initialLongBreakDuration;
  final int initialSessionsCount;
  final bool initialAutoStartBreak;
  final bool initialAutoStartWork;
  final bool initialTickingEnabled;
  final bool initialKeepScreenAwake;
  final int initialTickingVolume;
  final int initialTickingSpeed;
  final Function(
      TimerMode timerMode,
      int workDuration,
      int breakDuration,
      int longBreakDuration,
      int sessionsCount,
      bool autoStartBreak,
      bool autoStartWork,
      bool tickingEnabled,
      bool keepScreenAwake,
      int tickingVolume,
      int tickingSpeed) onSettingsChanged;

  const TimerSettingsDialog({
    super.key,
    required this.initialTimerMode,
    required this.initialWorkDuration,
    required this.initialBreakDuration,
    required this.initialLongBreakDuration,
    required this.initialSessionsCount,
    required this.initialAutoStartBreak,
    required this.initialAutoStartWork,
    required this.initialTickingEnabled,
    required this.initialKeepScreenAwake,
    required this.initialTickingVolume,
    required this.initialTickingSpeed,
    required this.onSettingsChanged,
  });

  @override
  State<TimerSettingsDialog> createState() => _TimerSettingsDialogState();
}

class _TimerSettingsDialogState extends State<TimerSettingsDialog> {
  final _translationService = container.resolve<ITranslationService>();
  final _mediator = container.resolve<Mediator>();

  static const int _minTimerValue = 1;
  static const int _maxTimerValue = 120;

  // Debounce for saving settings
  Timer? _saveDebounceTimer;

  // Track which settings need to be saved
  final Set<String> _pendingSaves = <String>{};

  late TimerMode _timerMode;
  late int _workDuration;
  late int _breakDuration;
  late int _longBreakDuration;
  late int _sessionsCount;
  late bool _autoStartBreak;
  late bool _autoStartWork;
  late bool _tickingEnabled;
  late bool _keepScreenAwake;
  late int _tickingVolume;
  late int _tickingSpeed;

  @override
  void initState() {
    super.initState();
    _timerMode = widget.initialTimerMode;
    _workDuration = widget.initialWorkDuration;
    _breakDuration = widget.initialBreakDuration;
    _longBreakDuration = widget.initialLongBreakDuration;
    _sessionsCount = widget.initialSessionsCount;
    _autoStartBreak = widget.initialAutoStartBreak;
    _autoStartWork = widget.initialAutoStartWork;
    _tickingEnabled = widget.initialTickingEnabled;
    _keepScreenAwake = widget.initialKeepScreenAwake;
    _tickingVolume = widget.initialTickingVolume;
    _tickingSpeed = widget.initialTickingSpeed;
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveTimerModeSetting(TimerMode mode) async {
    try {
      final command = SaveSettingCommand(
        key: SettingKeys.defaultTimerMode,
        value: mode.value,
        valueType: SettingValueType.string,
      );
      await _mediator.send(command);

      // Immediately update parent timer component
      _notifyParentOfChanges();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _notifyParentOfChanges() async {
    try {
      await widget.onSettingsChanged(
        _timerMode,
        _workDuration,
        _breakDuration,
        _longBreakDuration,
        _sessionsCount,
        _autoStartBreak,
        _autoStartWork,
        _tickingEnabled,
        _keepScreenAwake,
        _tickingVolume,
        _tickingSpeed,
      );
    } catch (e) {
      // Settings notification failed - not critical
    }
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    try {
      final command = SaveSettingCommand(
        key: key,
        value: value.toString(),
        valueType: SettingValueType.bool,
      );
      await _mediator.send(command);
    } catch (e) {
      rethrow;
    }
  }

  void _debouncedSaveBoolSetting(String key, bool value) {
    _pendingSaves.add(key);
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _savePendingSettings();
    });
  }

  void _debouncedSaveIntSetting(String key, int value) {
    _pendingSaves.add(key);
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _savePendingSettings();
    });
  }

  Future<void> _savePendingSettings() async {
    try {
      final saves = <Future<void>>[];

      for (final key in _pendingSaves) {
        switch (key) {
          case SettingKeys.autoStartBreak:
            saves.add(_saveBoolSetting(key, _autoStartBreak));
            break;
          case SettingKeys.autoStartWork:
            saves.add(_saveBoolSetting(key, _autoStartWork));
            break;
          case SettingKeys.tickingEnabled:
            saves.add(_saveBoolSetting(key, _tickingEnabled));
            break;
          case SettingKeys.keepScreenAwake:
            saves.add(_saveBoolSetting(key, _keepScreenAwake));
            break;
          case SettingKeys.tickingVolume:
            saves.add(_saveIntSetting(key, _tickingVolume));
            break;
          case SettingKeys.tickingSpeed:
            saves.add(_saveIntSetting(key, _tickingSpeed));
            break;
          case SettingKeys.workTime:
            saves.add(_saveIntSetting(key, _workDuration));
            break;
          case SettingKeys.breakTime:
            saves.add(_saveIntSetting(key, _breakDuration));
            break;
          case SettingKeys.longBreakTime:
            saves.add(_saveIntSetting(key, _longBreakDuration));
            break;
          case SettingKeys.sessionsBeforeLongBreak:
            saves.add(_saveIntSetting(key, _sessionsCount));
            break;
        }
      }

      await Future.wait(saves);
      _pendingSaves.clear();
    } catch (e) {
      // Setting save failed - will be retried on next debounced save
    }
  }

  Future<void> _saveIntSetting(String key, int value) async {
    try {
      final command = SaveSettingCommand(
        key: key,
        value: value.toString(),
        valueType: SettingValueType.int,
      );
      await _mediator.send(command);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _onClose() async {
    // Execute any pending debounced saves immediately before closing
    if (_saveDebounceTimer?.isActive == true) {
      _saveDebounceTimer?.cancel();
      await _savePendingSettings();
    }

    if (mounted) {
      widget.onSettingsChanged(
        _timerMode,
        _workDuration,
        _breakDuration,
        _longBreakDuration,
        _sessionsCount,
        _autoStartBreak,
        _autoStartWork,
        _tickingEnabled,
        _keepScreenAwake,
        _tickingVolume,
        _tickingSpeed,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          _translationService.translate(TaskTranslationKeys.pomodoroSettingsLabel),
        ),
        elevation: 0,
        leading: IconButton(
          onPressed: _onClose,
          icon: const Icon(Icons.arrow_back),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: _buildSettingsContent(),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Timer Mode Selection
        _buildTimerModeRow(),
        // Only show duration settings for modes that need them
        if (_timerMode != TimerMode.stopwatch) ...[
          Text(
            _translationService.translate(TaskTranslationKeys.pomodoroTimerSettingsLabel),
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryTextColor),
          ),
          _buildSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroWorkLabel),
            _workDuration,
            (newValue) {
              if (!mounted) return;
              setState(() {
                _workDuration = newValue.clamp(_minTimerValue, _maxTimerValue);
              });
              _debouncedSaveIntSetting(SettingKeys.workTime, _workDuration);
            },
            valueSuffix: _translationService.translate(SharedTranslationKeys.minutesShort),
          ),
        ],
        // Only show Pomodoro-specific settings in Pomodoro mode
        if (_timerMode == TimerMode.pomodoro) ...[
          _buildSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroBreakLabel),
            _breakDuration,
            (newValue) {
              if (!mounted) return;
              setState(() {
                _breakDuration = newValue.clamp(_minTimerValue, _maxTimerValue);
              });
              _debouncedSaveIntSetting(SettingKeys.breakTime, _breakDuration);
            },
            valueSuffix: _translationService.translate(SharedTranslationKeys.minutesShort),
          ),
          _buildSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroLongBreakLabel),
            _longBreakDuration,
            (newValue) {
              if (!mounted) return;
              setState(() {
                _longBreakDuration = newValue.clamp(_minTimerValue, _maxTimerValue);
              });
              _debouncedSaveIntSetting(SettingKeys.longBreakTime, _longBreakDuration);
            },
            valueSuffix: _translationService.translate(SharedTranslationKeys.minutesShort),
          ),
          _buildSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroSessionsCountLabel),
            _sessionsCount,
            (newValue) {
              if (!mounted) return;
              setState(() {
                _sessionsCount = newValue.clamp(1, 10);
              });
              _debouncedSaveIntSetting(SettingKeys.sessionsBeforeLongBreak, _sessionsCount);
            },
            step: 1,
            minValue: 1,
            maxValue: 10,
          ),
          // Only show auto-start settings in Pomodoro mode
          const SizedBox(height: 24),
          Text(
            _translationService.translate(TaskTranslationKeys.pomodoroAutoStartSectionLabel),
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryTextColor),
          ),
          const SizedBox(height: 8),
          _buildSwitchSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroAutoStartBreakLabel),
            _autoStartBreak,
            (value) {
              if (!mounted) return;
              setState(() {
                _autoStartBreak = value;
              });
              _debouncedSaveBoolSetting(SettingKeys.autoStartBreak, value);
            },
          ),
          _buildSwitchSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroAutoStartWorkLabel),
            _autoStartWork,
            (value) {
              if (!mounted) return;
              setState(() {
                _autoStartWork = value;
              });
              _debouncedSaveBoolSetting(SettingKeys.autoStartWork, value);
            },
          ),
        ],
        const SizedBox(height: 24),
        Text(
          _translationService.translate(TaskTranslationKeys.pomodoroTickingSoundSectionLabel),
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryTextColor),
        ),
        const SizedBox(height: 8),
        _buildSwitchSettingRow(
          _translationService.translate(TaskTranslationKeys.pomodoroTickingSoundLabel),
          _tickingEnabled,
          (value) {
            if (!mounted) return;
            setState(() {
              _tickingEnabled = value;
            });
            _debouncedSaveBoolSetting(SettingKeys.tickingEnabled, value);
          },
        ),
        if (_tickingEnabled) ...[
          _buildSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroTickingVolumeLabel),
            _tickingVolume,
            (newValue) {
              if (!mounted) return;
              setState(() {
                _tickingVolume = newValue.clamp(5, 100);
              });
              _debouncedSaveIntSetting(SettingKeys.tickingVolume, _tickingVolume);
            },
            step: 5,
            minValue: 5,
            maxValue: 100,
          ),
          _buildSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroTickingSpeedLabel),
            _tickingSpeed,
            (newValue) {
              if (!mounted) return;
              setState(() {
                _tickingSpeed = newValue.clamp(1, 5);
              });
              _debouncedSaveIntSetting(SettingKeys.tickingSpeed, _tickingSpeed);
            },
            step: 1,
            minValue: 1,
            maxValue: 5,
          ),
        ],
        const SizedBox(height: 24),
        Text(
          _translationService.translate(TaskTranslationKeys.pomodoroKeepScreenAwakeSectionLabel),
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryTextColor),
        ),
        const SizedBox(height: 8),
        _buildSwitchSettingRow(
          _translationService.translate(TaskTranslationKeys.pomodoroKeepScreenAwakeLabel),
          _keepScreenAwake,
          (value) {
            if (!mounted) return;
            setState(() {
              _keepScreenAwake = value;
            });
            _debouncedSaveBoolSetting(SettingKeys.keepScreenAwake, value);
          },
        ),
      ],
    );
  }

  Widget _buildTimerModeRow() {
    IconData getTimerModeIcon(TimerMode mode) {
      switch (mode) {
        case TimerMode.pomodoro:
          return Icons.work_outline;
        case TimerMode.normal:
          return Icons.timer_outlined;
        case TimerMode.stopwatch:
          return Icons.play_circle_outline;
      }
    }

    String getTimerModeDisplay(TimerMode mode) {
      switch (mode) {
        case TimerMode.pomodoro:
          return _translationService.translate(TaskTranslationKeys.timerModePomodoro);
        case TimerMode.normal:
          return _translationService.translate(TaskTranslationKeys.timerModeNormal);
        case TimerMode.stopwatch:
          return _translationService.translate(TaskTranslationKeys.timerModeStopwatch);
      }
    }

    return Column(
      children: [
        Row(
          children: TimerMode.values.map((mode) {
            final isSelected = _timerMode == mode;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ElevatedButton(
                  onPressed: () async {
                    if (mode != _timerMode) {
                      setState(() {
                        _timerMode = mode;
                      });
                      await _saveTimerModeSetting(mode);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                    foregroundColor:
                        isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: isSelected ? 2 : 0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        getTimerModeIcon(mode),
                        size: 16,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        getTimerModeDisplay(mode),
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSettingRow(
    String label,
    int value,
    Function(int) onValueChanged, {
    int? minValue,
    int? maxValue,
    int step = 5,
    String? valueSuffix,
  }) {
    final min = minValue ?? _minTimerValue;
    final max = maxValue ?? _maxTimerValue;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: AppTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: NumericInput(
                  initialValue: value,
                  onValueChanged: onValueChanged,
                  minValue: min,
                  maxValue: max,
                  incrementValue: step,
                  decrementValue: step,
                  valueSuffix: valueSuffix,
                  iconSize: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSwitchSettingRow(String label, bool value, Function(bool) onChanged) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyMedium,
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
