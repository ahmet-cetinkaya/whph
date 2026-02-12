import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:application/features/settings/commands/save_setting_command.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:whph/main.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/setting_keys.dart';
import 'package:whph/shared/enums/timer_mode.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/components/styled_icon.dart';
import 'package:whph/shared/components/custom_tab_bar.dart';

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

  Map<NumericInputTranslationKey, String> _getNumericInputTranslations() {
    return NumericInputTranslationKey.values.asMap().map(
          (key, value) =>
              MapEntry(value, _translationService.translate(SharedTranslationKeys.mapNumericInputKey(value))),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _translationService.translate(TaskTranslationKeys.pomodoroSettingsLabel),
          style: AppTheme.headlineSmall,
        ),
        elevation: 0,
        leading: IconButton(
          onPressed: _onClose,
          icon: const Icon(Icons.arrow_back),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: _buildSettingsContent(),
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timer Mode Selection
        _buildTimerModeRow(),

        const SizedBox(height: AppTheme.sizeLarge),

        // Animated Settings Section
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duration Settings
              if (_timerMode != TimerMode.stopwatch) ...[
                Padding(
                  padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
                  child: Text(
                    _translationService.translate(TaskTranslationKeys.pomodoroTimerSettingsLabel),
                    style: AppTheme.labelLarge,
                  ),
                ),
                _buildSettingRow(
                  _translationService.translate(TaskTranslationKeys.pomodoroWorkLabel),
                  _workDuration,
                  Icons.work,
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

              // Pomodoro Specific Settings
              if (_timerMode == TimerMode.pomodoro) ...[
                const SizedBox(height: AppTheme.sizeMedium),
                _buildSettingRow(
                  _translationService.translate(TaskTranslationKeys.pomodoroBreakLabel),
                  _breakDuration,
                  Icons.coffee,
                  (newValue) {
                    if (!mounted) return;
                    setState(() {
                      _breakDuration = newValue.clamp(_minTimerValue, _maxTimerValue);
                    });
                    _debouncedSaveIntSetting(SettingKeys.breakTime, _breakDuration);
                  },
                  valueSuffix: _translationService.translate(SharedTranslationKeys.minutesShort),
                ),
                const SizedBox(height: AppTheme.sizeMedium),
                _buildSettingRow(
                  _translationService.translate(TaskTranslationKeys.pomodoroLongBreakLabel),
                  _longBreakDuration,
                  Icons.weekend,
                  (newValue) {
                    if (!mounted) return;
                    setState(() {
                      _longBreakDuration = newValue.clamp(_minTimerValue, _maxTimerValue);
                    });
                    _debouncedSaveIntSetting(SettingKeys.longBreakTime, _longBreakDuration);
                  },
                  valueSuffix: _translationService.translate(SharedTranslationKeys.minutesShort),
                ),
                const SizedBox(height: AppTheme.sizeMedium),
                _buildSettingRow(
                  _translationService.translate(TaskTranslationKeys.pomodoroSessionsCountLabel),
                  _sessionsCount,
                  Icons.repeat,
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

                const SizedBox(height: AppTheme.sizeXLarge),

                // Auto Start Settings
                Padding(
                  padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
                  child: Text(
                    _translationService.translate(TaskTranslationKeys.pomodoroAutoStartSectionLabel),
                    style: AppTheme.labelLarge,
                  ),
                ),
                _buildSwitchSettingRow(
                  _translationService.translate(TaskTranslationKeys.pomodoroAutoStartBreakLabel),
                  _autoStartBreak,
                  Icons.play_arrow_rounded,
                  (value) {
                    if (!mounted) return;
                    setState(() {
                      _autoStartBreak = value;
                    });
                    _debouncedSaveBoolSetting(SettingKeys.autoStartBreak, value);
                  },
                ),
                const SizedBox(height: AppTheme.sizeMedium),
                _buildSwitchSettingRow(
                  _translationService.translate(TaskTranslationKeys.pomodoroAutoStartWorkLabel),
                  _autoStartWork,
                  Icons.work_history_rounded,
                  (value) {
                    if (!mounted) return;
                    setState(() {
                      _autoStartWork = value;
                    });
                    _debouncedSaveBoolSetting(SettingKeys.autoStartWork, value);
                  },
                ),
              ],
            ],
          ),
          crossFadeState: _timerMode != TimerMode.stopwatch ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),

        const SizedBox(height: AppTheme.sizeXLarge),

        // Sound Settings
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
          child: Text(
            _translationService.translate(TaskTranslationKeys.pomodoroTickingSoundSectionLabel),
            style: AppTheme.labelLarge,
          ),
        ),
        _buildSwitchSettingRow(
          _translationService.translate(TaskTranslationKeys.pomodoroTickingSoundLabel),
          _tickingEnabled,
          Icons.volume_up,
          (value) {
            if (!mounted) return;
            setState(() {
              _tickingEnabled = value;
            });
            _debouncedSaveBoolSetting(SettingKeys.tickingEnabled, value);
          },
        ),

        // Animated Sound Details
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              const SizedBox(height: AppTheme.sizeMedium),
              _buildSettingRow(
                _translationService.translate(TaskTranslationKeys.pomodoroTickingVolumeLabel),
                _tickingVolume,
                Icons.volume_down,
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
              const SizedBox(height: AppTheme.sizeMedium),
              _buildSettingRow(
                _translationService.translate(TaskTranslationKeys.pomodoroTickingSpeedLabel),
                _tickingSpeed,
                Icons.speed,
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
          ),
          crossFadeState: _tickingEnabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),

        const SizedBox(height: AppTheme.sizeXLarge),

        // Screen Awake Setting
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
          child: Text(
            _translationService.translate(TaskTranslationKeys.pomodoroKeepScreenAwakeSectionLabel),
            style: AppTheme.labelLarge,
          ),
        ),
        _buildSwitchSettingRow(
          _translationService.translate(TaskTranslationKeys.pomodoroKeepScreenAwakeLabel),
          _keepScreenAwake,
          Icons.screen_lock_portrait,
          (value) {
            if (!mounted) return;
            setState(() {
              _keepScreenAwake = value;
            });
            _debouncedSaveBoolSetting(SettingKeys.keepScreenAwake, value);
          },
        ),

        // Bottom padding for scrolling
        const SizedBox(height: AppTheme.sizeXLarge),
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
          return _translationService.translate(SharedTranslationKeys.pomodoroTimer);
        case TimerMode.normal:
          return _translationService.translate(SharedTranslationKeys.normalTimer);
        case TimerMode.stopwatch:
          return _translationService.translate(SharedTranslationKeys.stopwatchTimer);
      }
    }

    return CustomTabBar(
      selectedIndex: TimerMode.values.indexOf(_timerMode),
      onTap: (index) async {
        final mode = TimerMode.values[index];
        if (mode != _timerMode) {
          setState(() {
            _timerMode = mode;
          });
          await _saveTimerModeSetting(mode);
        }
      },
      items: TimerMode.values.map((mode) {
        return CustomTabItem(
          icon: getTimerModeIcon(mode),
          label: getTimerModeDisplay(mode),
        );
      }).toList(),
    );
  }

  Widget _buildSettingRow(
    String label,
    int value,
    IconData icon,
    Function(int) onValueChanged, {
    int? minValue,
    int? maxValue,
    int step = 5,
    String? valueSuffix,
  }) {
    final min = minValue ?? _minTimerValue;
    final max = maxValue ?? _maxTimerValue;

    return Container(
      padding: const EdgeInsets.all(AppTheme.sizeLarge),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      child: Row(
        children: [
          StyledIcon(icon, isActive: true),
          const SizedBox(width: AppTheme.sizeLarge),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          NumericInput(
            initialValue: value,
            onValueChanged: onValueChanged,
            minValue: min,
            maxValue: max,
            incrementValue: step,
            decrementValue: step,
            valueSuffix: valueSuffix,
            iconSize: 20,
            translations: _getNumericInputTranslations(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSettingRow(
    String label,
    bool value,
    IconData icon,
    Function(bool) onChanged,
  ) {
    return Card(
      elevation: 0,
      color: AppTheme.surface1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(
          label,
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w500),
        ),
        secondary: StyledIcon(
          icon,
          isActive: value,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeLarge, vertical: 4),
      ),
    );
  }
}
