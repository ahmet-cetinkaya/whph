import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';
import 'package:whph/presentation/ui/shared/components/custom_tab_bar.dart';

class TimerSettingsDialog extends StatefulWidget {
  /// Quiet period after the last edit before pending settings are written.
  static const Duration saveDebounce = Duration(milliseconds: 500);

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

  // Saves run strictly one after another (FIFO); a dispose flush queues behind an in-flight save.
  Future<void> _saveChain = Future.value();

  // Set in dispose: a dead State cannot retry a failed save.
  bool _disposed = false;

  // True once the user changed anything; the parent must be told even if the saves already finished.
  bool _dirty = false;

  // Set once _onClose took over notifying the parent, so dispose never notifies a second time.
  bool _closed = false;

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
    _disposed = true;
    // Dismissal by barrier tap, Esc or drag never reaches _onClose: flush and notify here.
    final hadChanges = _dirty || _pendingSaves.isNotEmpty;
    if (_pendingSaves.isNotEmpty) {
      // No setState/context here; _savePendingSettings has its own try/catch.
      unawaited(_savePendingSettings());
    }
    if (!_closed && hadChanges) {
      _closed = true;
      final onChanged = widget.onSettingsChanged;
      final args = (
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
      // Post-frame: the parent may call setState/notifyListeners, which is unsafe mid-unmount.
      // The parent callback guards against its own widget already being disposed.
      // Known divergence: the parent applies these in-memory values even if the DB save above failed; the next
      // app start then reads the old persisted values (the failure is only logged).
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await onChanged(
              args.$1, args.$2, args.$3, args.$4, args.$5, args.$6, args.$7, args.$8, args.$9, args.$10, args.$11);
        } catch (e, s) {
          Logger.error('Failed to notify timer settings change after dismiss: $e', stackTrace: s);
        }
      });
    }
    super.dispose();
  }

  Future<void> _saveTimerModeSetting() async {
    // Saved immediately, but tracked like the other keys so a failed save is retried on close/dismiss.
    _pendingSaves.add(SettingKeys.defaultTimerMode);
    _dirty = true;
    _saveDebounceTimer?.cancel();
    await _savePendingSettings();

    // If the dialog was closed meanwhile, _onClose/dispose already notify the parent.
    if (!_closed) await _notifyParentOfChanges();
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
    } catch (e, s) {
      Logger.error('Failed to apply timer settings: $e', stackTrace: s);
    }
  }

  void _debouncedSave(String key) {
    _pendingSaves.add(key);
    _dirty = true;
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(TimerSettingsDialog.saveDebounce, _savePendingSettings);
  }

  Future<void> _flushPendingSaves() async {
    _saveDebounceTimer?.cancel();
    // Also waits for an in-flight save; if that one fails its keys are re-added and retried by this run.
    await _savePendingSettings();
  }

  Future<void> _savePendingSettings() {
    final run = _saveChain.then((_) => _runPendingSave());
    _saveChain = run; // _runPendingSave never throws, so the chain never breaks
    return run;
  }

  Future<void> _runPendingSave() async {
    // Snapshot and clear when the save starts: keys changed while it is in flight stay pending for the next one.
    final keys = _pendingSaves.toList();
    _pendingSaves.clear();
    if (keys.isEmpty) return;
    try {
      await Future.wait(keys.map(_saveKey));
    } catch (e, s) {
      if (_disposed) {
        // A dead State has no later close/dispose flush, so this edit is lost (only logged).
        Logger.error('Timer settings not saved after the dialog was dismissed: $e', stackTrace: s);
      } else {
        // Keep the keys pending so the next save (or the close/dispose flush) retries them.
        _pendingSaves.addAll(keys);
        Logger.error('Failed to save timer settings: $e', stackTrace: s);
      }
      return;
    }

    if (keys.contains(SettingKeys.tickingEnabled)) {
      try {
        container.resolve<ISoundManagerService>().clearSettingsCache();
      } catch (e, s) {
        Logger.error('Failed to clear sound settings cache: $e', stackTrace: s);
      }
    }
  }

  Future<void> _saveKey(String key) {
    final (String value, SettingValueType type) = switch (key) {
      SettingKeys.defaultTimerMode => (_timerMode.value, SettingValueType.string),
      SettingKeys.autoStartBreak => ('$_autoStartBreak', SettingValueType.bool),
      SettingKeys.autoStartWork => ('$_autoStartWork', SettingValueType.bool),
      SettingKeys.tickingEnabled => ('$_tickingEnabled', SettingValueType.bool),
      SettingKeys.keepScreenAwake => ('$_keepScreenAwake', SettingValueType.bool),
      SettingKeys.tickingVolume => ('$_tickingVolume', SettingValueType.int),
      SettingKeys.tickingSpeed => ('$_tickingSpeed', SettingValueType.int),
      SettingKeys.workTime => ('$_workDuration', SettingValueType.int),
      SettingKeys.breakTime => ('$_breakDuration', SettingValueType.int),
      SettingKeys.longBreakTime => ('$_longBreakDuration', SettingValueType.int),
      SettingKeys.sessionsBeforeLongBreak => ('$_sessionsCount', SettingValueType.int),
      _ => throw ArgumentError('Unknown timer setting key: $key'),
    };
    return _mediator.send(SaveSettingCommand(key: key, value: value, valueType: type));
  }

  Future<void> _onClose() async {
    if (_closed) return;
    _closed = true;

    // Only a real change may reach the parent: applying settings resets a running timer and alarm.
    final hadChanges = _dirty || _pendingSaves.isNotEmpty;
    await _flushPendingSaves();
    if (hadChanges) await _notifyParentOfChanges();

    // A failed save still closes; the keys stay pending and the dispose flush retries once.
    if (mounted) Navigator.of(context).pop();
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
        actions: [
          TextButton(
            onPressed: _onClose,
            child: Text(
              _translationService.translate(SharedTranslationKeys.doneButton),
              style: AppTheme.labelLarge.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
                    _debouncedSave(SettingKeys.workTime);
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
                    _debouncedSave(SettingKeys.breakTime);
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
                    _debouncedSave(SettingKeys.longBreakTime);
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
                    _debouncedSave(SettingKeys.sessionsBeforeLongBreak);
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
                    _debouncedSave(SettingKeys.autoStartBreak);
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
                    _debouncedSave(SettingKeys.autoStartWork);
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
            _debouncedSave(SettingKeys.tickingEnabled);
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
                  _debouncedSave(SettingKeys.tickingVolume);
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
                  _debouncedSave(SettingKeys.tickingSpeed);
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
            _debouncedSave(SettingKeys.keepScreenAwake);
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
          await _saveTimerModeSetting();
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
