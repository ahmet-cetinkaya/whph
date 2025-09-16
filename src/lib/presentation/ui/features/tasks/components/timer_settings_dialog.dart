import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';
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
      debugPrint('Attempting to save timer mode: ${mode.value}');
      final command = SaveSettingCommand(
        key: SettingKeys.defaultTimerMode,
        value: mode.value,
        valueType: SettingValueType.string,
      );
      await _mediator.send(command);
      debugPrint('Successfully saved timer mode: ${mode.value}');

      // Immediately update parent timer component
      _notifyParentOfChanges();
    } catch (e, stackTrace) {
      debugPrint('Error saving timer mode ${mode.value}: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _notifyParentOfChanges() async {
    try {
      debugPrint('Notifying parent of settings changes');
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
      debugPrint('Parent successfully updated with new settings');
    } catch (e) {
      debugPrint('Error notifying parent of settings changes: $e');
    }
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    try {
      debugPrint('Attempting to save bool setting: $key = $value');
      final command = SaveSettingCommand(
        key: key,
        value: value.toString(),
        valueType: SettingValueType.bool,
      );
      await _mediator.send(command);
      debugPrint('Successfully saved bool setting: $key = $value');
    } catch (e, stackTrace) {
      debugPrint('Error saving bool setting $key: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _debouncedSaveBoolSetting(String key, bool value) {
    // Temporarily save immediately for debugging
    debugPrint('Immediate save triggered for bool: $key = $value');
    _saveBoolSetting(key, value).then((_) {
      // Immediately update parent timer component after saving
      _notifyParentOfChanges();
    });

    // Original debounced code (commented out for debugging)
    // _pendingSaves.add(key);
    // _saveDebounceTimer?.cancel();
    // _saveDebounceTimer = Timer(_debounceDuration, () async {
    //   await _savePendingSettings();
    // });
  }

  void _debouncedSaveIntSetting(String key, int value) {
    // Temporarily save immediately for debugging
    debugPrint('Immediate save triggered for int: $key = $value');
    _saveIntSetting(key, value).then((_) {
      // Immediately update parent timer component after saving
      _notifyParentOfChanges();
    });

    // Original debounced code (commented out for debugging)
    // _pendingSaves.add(key);
    // _saveDebounceTimer?.cancel();
    // _saveDebounceTimer = Timer(_debounceDuration, () async {
    //   await _savePendingSettings();
    // });
  }

  Future<void> _savePendingSettings() async {
    try {
      debugPrint('Saving pending settings: ${_pendingSaves.toList()}');
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
      debugPrint('Successfully saved all pending settings');
    } catch (e, stackTrace) {
      debugPrint('Error saving pending settings: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _saveIntSetting(String key, int value) async {
    try {
      debugPrint('Attempting to save int setting: $key = $value');
      final command = SaveSettingCommand(
        key: key,
        value: value.toString(),
        valueType: SettingValueType.int,
      );
      await _mediator.send(command);
      debugPrint('Successfully saved int setting: $key = $value');
    } catch (e, stackTrace) {
      debugPrint('Error saving int setting $key: $e');
      debugPrint('Stack trace: $stackTrace');
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
            (adjustment) {
              if (!mounted) return;
              setState(() {
                _workDuration = (_workDuration + adjustment).clamp(_minTimerValue, _maxTimerValue);
              });
              _debouncedSaveIntSetting(SettingKeys.workTime, _workDuration);
            },
            showMinutes: true,
          ),
        ],
        // Only show Pomodoro-specific settings in Pomodoro mode
        if (_timerMode == TimerMode.pomodoro) ...[
          _buildSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroBreakLabel),
            _breakDuration,
            (adjustment) {
              if (!mounted) return;
              setState(() {
                _breakDuration = (_breakDuration + adjustment).clamp(_minTimerValue, _maxTimerValue);
              });
              _debouncedSaveIntSetting(SettingKeys.breakTime, _breakDuration);
            },
            showMinutes: true,
          ),
          _buildSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroLongBreakLabel),
            _longBreakDuration,
            (adjustment) {
              if (!mounted) return;
              setState(() {
                _longBreakDuration = (_longBreakDuration + adjustment).clamp(_minTimerValue, _maxTimerValue);
              });
              _debouncedSaveIntSetting(SettingKeys.longBreakTime, _longBreakDuration);
            },
            showMinutes: true,
          ),
          _buildSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroSessionsCountLabel),
            _sessionsCount,
            (adjustment) {
              if (!mounted) return;
              setState(() {
                _sessionsCount = (_sessionsCount + adjustment).clamp(1, 10);
              });
              _debouncedSaveIntSetting(SettingKeys.sessionsBeforeLongBreak, _sessionsCount);
            },
            step: 1,
            minValue: 1,
            maxValue: 10,
            showMinutes: false,
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
            (adjustment) {
              if (!mounted) return;
              setState(() {
                _tickingVolume = (_tickingVolume + adjustment).clamp(5, 100);
              });
              _debouncedSaveIntSetting(SettingKeys.tickingVolume, _tickingVolume);
            },
            step: 5,
            minValue: 5,
            maxValue: 100,
            showMinutes: false,
          ),
          _buildSettingRow(
            _translationService.translate(TaskTranslationKeys.pomodoroTickingSpeedLabel),
            _tickingSpeed,
            (adjustment) {
              if (!mounted) return;
              setState(() {
                _tickingSpeed = (_tickingSpeed + adjustment).clamp(1, 5);
              });
              _debouncedSaveIntSetting(SettingKeys.tickingSpeed, _tickingSpeed);
            },
            step: 1,
            minValue: 1,
            maxValue: 5,
            showMinutes: false,
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
    Function(int) onAdjust, {
    int? minValue,
    int? maxValue,
    int step = 5,
    bool showMinutes = true,
  }) {
    final min = minValue ?? _minTimerValue;
    final max = maxValue ?? _maxTimerValue;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: value > min ? () => onAdjust(-step) : null,
                    icon: const Icon(Icons.remove, size: 18),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: Text(
                        showMinutes ? '${value}m' : value.toString(),
                        style: AppTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: value < max ? () => onAdjust(step) : null,
                    icon: const Icon(Icons.add, size: 18),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
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
