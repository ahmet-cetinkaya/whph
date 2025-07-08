import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/src/core/application/features/settings/queries/get_setting_query.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/infrastructure/shared/features/wakelock/abstractions/i_wakelock_service.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_sounds.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_sounds.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/src/core/domain/shared/constants/app_assets.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';

class PomodoroTimer extends StatefulWidget {
  final Function(Duration) onTimeUpdate;
  final VoidCallback? onTimerStart;
  final VoidCallback? onTimerStop;

  const PomodoroTimer({
    super.key,
    required this.onTimeUpdate,
    this.onTimerStart,
    this.onTimerStop,
  });

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
  final _mediator = container.resolve<Mediator>();
  final _soundPlayer = container.resolve<ISoundPlayer>();
  final _notificationService = container.resolve<INotificationService>();
  final _systemTrayService = container.resolve<ISystemTrayService>();
  final _translationService = container.resolve<ITranslationService>();
  final _wakelockService = container.resolve<IWakelockService>();

  static const int _minTimerValue = 5;
  static const int _maxTimerValue = 120;

  // Helper methods for time calculations
  int _getTimeInSeconds(int value) {
    return value * 60;
  }

  String _getDisplayTime() {
    if (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall)) {
      final minutes = _remainingTime.inMinutes;
      return '${minutes}m';
    }

    // On regular screens, show full time format
    return SharedUiConstants.formatDuration(_remainingTime);
  }

  late Timer _timer;
  Duration _remainingTime = const Duration();
  bool _isWorking = true;
  bool _isRunning = false;
  int _defaultWorkDuration = 25;
  int _defaultBreakDuration = 5;
  int _defaultLongBreakDuration = 15;
  int _defaultSessionsCount = 4;
  bool _defaultAutoStartBreak = false;
  bool _defaultAutoStartWork = false;
  bool _defaultTickingEnabled = false;
  bool _defaultKeepScreenAwake = false;
  bool _isTickSound = true; // Track which sound to play
  int _defaultTickingVolume = 50;
  int _defaultTickingSpeed = 1;
  late int _workDuration = _defaultWorkDuration;
  late int _breakDuration = _defaultBreakDuration;
  late int _longBreakDuration = _defaultLongBreakDuration;
  late int _sessionsCount = _defaultSessionsCount;
  late bool _autoStartBreak = _defaultAutoStartBreak;
  late bool _autoStartWork = _defaultAutoStartWork;
  late bool _tickingEnabled = _defaultTickingEnabled;
  late bool _keepScreenAwake = _defaultKeepScreenAwake;
  late int _tickingVolume = _defaultTickingVolume;
  late int _tickingSpeed = _defaultTickingSpeed;
  Timer? _tickingTimer;
  int _completedSessions = 0;
  bool _isLongBreak = false;
  bool _isAlarmPlaying = false;

  int _getTotalDurationInSeconds() {
    if (_isWorking) return _getTimeInSeconds(_workDuration);
    if (_isLongBreak) return _getTimeInSeconds(_longBreakDuration);
    return _getTimeInSeconds(_breakDuration);
  }

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  @override
  void dispose() {
    // Always cancel timers if they exist
    if (_isRunning) {
      _timer.cancel();
    }
    _tickingTimer?.cancel();

    // Stop any playing sounds
    _soundPlayer.stop();

    // Disable wakelock when disposing
    _wakelockService.disable();

    // Remove timer menu items if they were added
    if (_isTimerMenuAdded) {
      _removeTimerMenuItems();
    }

    // Always clean up system tray to ensure persistent notifications are cleared
    // This handles both timer running and non-running states
    _resetSystemTrayToDefault();

    super.dispose();
  }

  Future<void> _initializeSettings() async {
    _defaultWorkDuration = await _getSetting(SettingKeys.workTime, 25);
    _defaultBreakDuration = await _getSetting(SettingKeys.breakTime, 5);
    _defaultLongBreakDuration = await _getSetting(SettingKeys.longBreakTime, 15);
    _defaultSessionsCount = await _getSetting(SettingKeys.sessionsBeforeLongBreak, 4);
    _defaultAutoStartBreak = await _getBoolSetting(SettingKeys.autoStartBreak, false);
    _defaultAutoStartWork = await _getBoolSetting(SettingKeys.autoStartWork, false);
    _defaultTickingEnabled = await _getBoolSetting(SettingKeys.tickingEnabled, false);
    _defaultKeepScreenAwake = await _getBoolSetting(SettingKeys.keepScreenAwake, false);
    _defaultTickingVolume = await _getSetting(SettingKeys.tickingVolume, 50);
    _defaultTickingSpeed = await _getSetting(SettingKeys.tickingSpeed, 1);

    // Ensure minimum volume is 5
    if (_defaultTickingVolume < 5) {
      _defaultTickingVolume = 5;
      await _saveSetting(SettingKeys.tickingVolume, _defaultTickingVolume);
    }

    if (mounted) {
      setState(() {
        _workDuration = _defaultWorkDuration;
        _breakDuration = _defaultBreakDuration;
        _longBreakDuration = _defaultLongBreakDuration;
        _sessionsCount = _defaultSessionsCount;
        _autoStartBreak = _defaultAutoStartBreak;
        _autoStartWork = _defaultAutoStartWork;
        _tickingEnabled = _defaultTickingEnabled;
        _keepScreenAwake = _defaultKeepScreenAwake;
        _tickingVolume = _defaultTickingVolume;
        _tickingSpeed = _defaultTickingSpeed;
        _remainingTime = Duration(seconds: _getTimeInSeconds(_workDuration));
        _isLongBreak = false;
        _completedSessions = 0;
      });
    }
  }

  Future<bool> _getBoolSetting(String key, bool defaultValue) async {
    try {
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(
        GetSettingQuery(key: key),
      );
      return response.getValue<bool>();
    } catch (_) {
      return defaultValue;
    }
  }

  Future<int> _getSetting(String key, int defaultValue) async {
    try {
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(
        GetSettingQuery(key: key),
      );
      return response.getValue<int>();
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> _saveSetting(String key, int value) async {
    final command = SaveSettingCommand(
      key: key,
      value: value.toString(),
      valueType: SettingValueType.int,
    );
    await _mediator.send(command);
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final command = SaveSettingCommand(
      key: key,
      value: value.toString(),
      valueType: SettingValueType.bool,
    );
    await _mediator.send(command);
  }

  void _startAlarm() {
    setState(() {
      _isAlarmPlaying = true;
    });

    _soundPlayer.setLoop(true);
    _soundPlayer.play(SharedSounds.alarmDone, volume: 1.0);

    _sendNotification();
  }

  void _sendNotification() {
    final completionMessage = _isWorking
        ? _translationService.translate(TaskTranslationKeys.pomodoroWorkSessionCompleted)
        : _translationService.translate(_isLongBreak
            ? TaskTranslationKeys.pomodoroLongBreakSessionCompleted
            : TaskTranslationKeys.pomodoroBreakSessionCompleted);

    // Set system tray for completion state
    _setPomodoroCompletionNotification(completionMessage);

    // Also send a regular notification for immediate user attention
    _notificationService.show(
      title: _translationService.translate(TaskTranslationKeys.pomodoroNotificationTitle),
      body: completionMessage,
    );
  }

  // Helper methods for Pomodoro notification management
  void _setPomodoroTimerNotification(String status, String timeDisplay) {
    _systemTrayService.setTitle('$status - $timeDisplay');
    _systemTrayService.setBody(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayTimerRunning));
  }

  void _setPomodoroCompletionNotification(String completionMessage) {
    _systemTrayService.setTitle(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayCompleteTitle));
    _systemTrayService.setBody(completionMessage);
  }

  void _resetSystemTrayToDefault() {
    _systemTrayService.setTitle(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayAppRunning));
    _systemTrayService.setBody(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayTapToOpen));
  }

  void _stopAlarm() {
    _soundPlayer.stop();
    _soundPlayer.setLoop(false);
    setState(() {
      _isAlarmPlaying = false;
    });
  }

  void _startTimer() {
    if (_isRunning || _isAlarmPlaying) return;

    // Call the onTimerStart callback if provided
    widget.onTimerStart?.call();

    if (mounted) {
      _soundPlayer.play(SharedSounds.button, volume: 1.0);
      _setSystemTrayIcon();
      _addTimerMenuItems();
      _updateSystemTrayTimer();
      if (_tickingEnabled) _startTicking();

      // Enable wakelock if the setting is enabled
      if (_keepScreenAwake) {
        _wakelockService.enable();
      }

      setState(() {
        _isRunning = true;
        _startRegularTimer();
      });
    }
  }

  void _startRegularTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        if (!mounted) return;

        // Calculate the actual elapsed time increment for debug vs production
        final elapsedIncrement = kDebugMode
            ? const Duration(minutes: 1) // In debug mode, 1 minute of progress per second
            : const Duration(seconds: 1); // In production, 1 second of progress per second

        setState(() {
          _remainingTime -= elapsedIncrement;
        });

        // Pass the actual elapsed time increment to the callback
        widget.onTimeUpdate(elapsedIncrement);
        _updateSystemTrayTimer();
      } else {
        _timer.cancel();
        _isRunning = false;
        _startAlarm();

        // Auto-start next session if enabled
        if (_isWorking && _autoStartBreak || !_isWorking && _autoStartWork) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _isAlarmPlaying) {
              _toggleWorkBreak();
            }
          });
        }
      }
    });
  }

  void _updateSystemTrayTimer() {
    final status = _isWorking
        ? _translationService.translate(TaskTranslationKeys.pomodoroWorkLabel)
        : (_isLongBreak
            ? _translationService.translate(TaskTranslationKeys.pomodoroLongBreakLabel)
            : _translationService.translate(TaskTranslationKeys.pomodoroBreakLabel));
    final timeDisplay = _getDisplayTime();

    // Use dedicated helper method for timer notifications
    _setPomodoroTimerNotification(status, timeDisplay);
  }

  void _stopTimer() {
    if (mounted) {
      _soundPlayer.play(SharedSounds.button, volume: 1.0);
      _stopTicking();

      // Disable wakelock when stopping timer
      _wakelockService.disable();

      setState(() {
        _isRunning = false;
        _isAlarmPlaying = false; // Reset alarm state
        if (!_isWorking) {
          // If in break mode, switch back to work mode
          _isWorking = true;
        }
        _remainingTime = Duration(
          seconds: _getTimeInSeconds(_workDuration), // Always set to work duration
        );
        _completedSessions = 0; // Reset completed sessions
        _isLongBreak = false; // Reset long break flag

        // Stop timer
        _timer.cancel();

        _soundPlayer.stop(); // Stop any playing sounds
      });

      _resetSystemTrayIcon();
      _removeTimerMenuItems();
      // Reset system tray title/body when stopping timer
      _resetSystemTrayToDefault();

      // Call the onTimerStop callback if provided
      widget.onTimerStop?.call();
    }
  }

  void _setSystemTrayIcon() {
    _systemTrayService.setIcon(_isWorking ? TrayIconType.play : TrayIconType.pause);
  }

  void _resetSystemTrayIcon() {
    _systemTrayService.setIcon(TrayIconType.default_);
  }

  void _toggleWorkBreak() {
    if (mounted) {
      _stopAlarm();
      setState(() {
        if (_isWorking) {
          // Work session completed
          _completedSessions++;
          _isWorking = false;
          _isLongBreak = _completedSessions >= _sessionsCount;

          if (_isLongBreak) {
            _completedSessions = 0; // Reset session count after long break
          }

          _remainingTime = Duration(
            seconds: _getTimeInSeconds(_isLongBreak ? _longBreakDuration : _breakDuration),
          );
        } else {
          // Break completed, start work
          _isWorking = true;
          _isLongBreak = false;
          _remainingTime = Duration(
            seconds: _getTimeInSeconds(_workDuration),
          );
        }
      });
      _startTimer();
    }
  }

  Future<void> _showSettingsModal() async {
    final previousWorkDuration = _workDuration;
    final previousBreakDuration = _breakDuration;

    if (mounted) {
      setState(() {
        _isWorking = true;
        _isRunning = false;
        _workDuration = _defaultWorkDuration;
        _breakDuration = _defaultBreakDuration;
      });
    }

    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_translationService.translate(TaskTranslationKeys.pomodoroSettingsLabel)),
              automaticallyImplyLeading: false,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_translationService.translate(SharedTranslationKeys.doneButton)),
                ),
              ],
            ),
            body: _buildSettingsContent(setState),
          );
        },
      ),
      size: DialogSize.medium,
    );

    // Save settings
    _saveSetting(SettingKeys.workTime, _workDuration);
    _saveSetting(SettingKeys.breakTime, _breakDuration);
    _saveSetting(SettingKeys.longBreakTime, _longBreakDuration);
    _saveSetting(SettingKeys.sessionsBeforeLongBreak, _sessionsCount);

    _defaultWorkDuration = _workDuration;
    _defaultBreakDuration = _breakDuration;
    _defaultLongBreakDuration = _longBreakDuration;
    _defaultSessionsCount = _sessionsCount;

    // Update current timer if settings changed
    if (mounted && (previousWorkDuration != _workDuration || previousBreakDuration != _breakDuration)) {
      setState(() {
        _remainingTime =
            Duration(minutes: _isWorking ? _workDuration : (_isLongBreak ? _longBreakDuration : _breakDuration));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive sizes with running state multiplier
    final double multiplier = !_isRunning && !_isAlarmPlaying ? 1.0 : 2.0;
    final double baseButtonSize = screenWidth < 600 ? AppTheme.iconSizeLarge : AppTheme.iconSizeXLarge;
    final double baseSpacing = screenWidth < 600 ? AppTheme.sizeSmall : AppTheme.sizeLarge;
    final double buttonSize = baseButtonSize * multiplier;
    final double spacing = baseSpacing * multiplier;

    final double progress =
        _isRunning || _isAlarmPlaying ? 1.0 - (_remainingTime.inSeconds / _getTotalDurationInSeconds()) : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.zero, // Padding will be handled by the inner content
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(buttonSize),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress Bar
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(buttonSize),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.transparent, // Transparent to show container color
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressBarColor(context),
                ),
                minHeight: buttonSize * 2, // Ensure progress bar has enough height
              ),
            ),
          ),
          // Timer Content
          Padding(
            padding: EdgeInsets.all(spacing),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isRunning && !_isAlarmPlaying)
                  IconButton(
                    iconSize: buttonSize * 0.6,
                    icon: Icon(SharedUiConstants.settingsIcon),
                    onPressed: _showSettingsModal,
                  ),
                if (!_isRunning && !_isAlarmPlaying) SizedBox(width: spacing),
                // Text area for the timer display
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: _isRunning || _isAlarmPlaying ? AppTheme.displayLarge : AppTheme.headlineMedium,
                  child: Text(
                    _getDisplayTime(),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: spacing),
                IconButton(
                  iconSize: buttonSize * 0.7,
                  icon: Icon(_getButtonIcon()),
                  onPressed: _getButtonAction(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    final normalColor = AppTheme.surface2;
    final breakColor = AppTheme.successColor.withAlpha((255 * 1).toInt());
    final longBreakColor = AppTheme.infoColor.withAlpha((255 * 1).toInt());
    final workEndColor = AppTheme.successColor.withAlpha((255 * 1).toInt());
    final breakEndColor = AppTheme.errorColor.withAlpha((255 * 1).toInt());
    final longBreakEndColor = AppTheme.infoColor.withAlpha((255 * 1).toInt());

    if (_isAlarmPlaying) {
      if (_isWorking) return workEndColor;
      return _isLongBreak ? longBreakEndColor : breakEndColor;
    }
    if (!_isRunning) return normalColor;
    return _isWorking ? normalColor : (_isLongBreak ? longBreakColor : breakColor);
  }

  IconData _getButtonIcon() {
    if (_isAlarmPlaying) return TaskUiConstants.pomodoroNextIcon;
    if (_isRunning) return TaskUiConstants.pomodoroStopIcon;
    return TaskUiConstants.pomodoroPlayIcon;
  }

  VoidCallback _getButtonAction() {
    if (_isAlarmPlaying) return _toggleWorkBreak;
    if (_isRunning) return _stopTimer;
    return _startTimer;
  }

  Widget _buildSettingsContent(StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.sizeLarge),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
              },
              showMinutes: true,
            ),
            _buildSettingRow(
              _translationService.translate(TaskTranslationKeys.pomodoroBreakLabel),
              _breakDuration,
              (adjustment) {
                if (!mounted) return;
                setState(() {
                  _breakDuration = (_breakDuration + adjustment).clamp(_minTimerValue, _maxTimerValue);
                });
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
              },
              step: 1,
              minValue: 1,
              maxValue: 10,
              showMinutes: false,
            ),
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
                _saveBoolSetting(SettingKeys.autoStartBreak, value);
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
                _saveBoolSetting(SettingKeys.autoStartWork, value);
              },
            ),
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
                _saveBoolSetting(SettingKeys.tickingEnabled, value);
                if (!value) _stopTicking();
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
                  _saveSetting(SettingKeys.tickingVolume, _tickingVolume);
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
                  _saveSetting(SettingKeys.tickingSpeed, _tickingSpeed);
                  _stopTicking();
                  if (_isRunning) _startTicking();
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
                _saveBoolSetting(SettingKeys.keepScreenAwake, value);
              },
            ),
          ],
        ),
      ),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTheme.sizeSmall),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: value > min ? () => onAdjust(-step) : null,
                  visualDensity: VisualDensity.compact,
                ),
                SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(
                      "$value${showMinutes ? " ${_translationService.translate(SharedTranslationKeys.minutesShort)}" : ''}",
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: value < max ? () => onAdjust(step) : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppTheme.size2XSmall),
      ],
    );
  }

  Widget _buildSwitchSettingRow(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTheme.sizeSmall),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.size2XSmall),
      ],
    );
  }

  static const String _stopTimerMenuKey = 'stop_timer';
  static const String _pomodoroTimerSeparatorKey = 'pomodoro_timer_separator';
  bool _isTimerMenuAdded = false;
  void _addTimerMenuItems() {
    if (_isTimerMenuAdded) return;

    final menuItems = [
      TrayMenuItem.separator(
        _pomodoroTimerSeparatorKey,
      ),
      TrayMenuItem(
        key: _stopTimerMenuKey,
        label: _translationService.translate(TaskTranslationKeys.pomodoroStopTimer),
        onClicked: _stopTimer,
      ),
    ];
    for (final item in menuItems) {
      _systemTrayService.insertMenuItem(item, index: 0);
    }
    _isTimerMenuAdded = true;
  }

  void _removeTimerMenuItems() {
    _systemTrayService.removeMenuItem(_stopTimerMenuKey);
    _systemTrayService.removeMenuItem(_pomodoroTimerSeparatorKey);
    _isTimerMenuAdded = false;
  }

  void _startTicking() {
    if (!_tickingEnabled || _tickingTimer != null) return;

    final tickInterval = Duration(seconds: _tickingSpeed);
    _tickingTimer = Timer.periodic(tickInterval, (timer) {
      if (!mounted || !_isRunning) {
        _stopTicking();
        return;
      }

      // Play alternating tick and tock sounds with specific volume
      _soundPlayer.play(
        _isTickSound ? TaskSounds.clockTick : TaskSounds.clockTock,
        requestAudioFocus: false,
        volume: _tickingVolume / 100.0,
      );
      _isTickSound = !_isTickSound; // Toggle for next sound
    });
  }

  void _stopTicking() {
    _tickingTimer?.cancel();
    _tickingTimer = null;
    _isTickSound = true; // Reset to start with tick sound next time
  }

  Color _getProgressBarColor(BuildContext context) {
    if (_isRunning || _isAlarmPlaying) {
      if (_isWorking) {
        return AppTheme.successColor.withValues(alpha: 0.3);
      } else if (_isLongBreak) {
        return AppTheme.infoColor.withValues(alpha: 0.3);
      } else {
        return AppTheme.errorColor.withValues(alpha: 0.6);
      }
    }

    return Colors.transparent;
  }
}
