import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/infrastructure/shared/features/wakelock/abstractions/i_wakelock_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer_settings_dialog.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_sounds.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_sounds.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';

class AppTimer extends StatefulWidget {
  final Function(Duration)? onTick; // For UI updates only - receives current elapsed/remaining time
  final VoidCallback? onTimerStart;
  final Function(Duration)? onTimerStop; // For data persistence - receives total elapsed duration
  final bool isMiniLayout; // Use compact layout for detail tables

  const AppTimer({
    super.key,
    this.onTick,
    this.onTimerStart,
    this.onTimerStop,
    this.isMiniLayout = false,
  });

  @override
  State<AppTimer> createState() => _AppTimerState();
}

class _AppTimerState extends State<AppTimer> {
  final _mediator = container.resolve<Mediator>();
  final _soundPlayer = container.resolve<ISoundPlayer>();
  final _soundManagerService = container.resolve<ISoundManagerService>();
  final _notificationService = container.resolve<INotificationService>();
  final _systemTrayService = container.resolve<ISystemTrayService>();
  final _translationService = container.resolve<ITranslationService>();
  final _wakelockService = container.resolve<IWakelockService>();

  // Helper methods for time calculations
  int _getTimeInSeconds(int value) {
    return value * 60;
  }

  String _getDisplayTime() {
    final timeToDisplay = _timerMode == TimerMode.stopwatch ? _elapsedTime : _remainingTime;

    if (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall)) {
      final minutes = timeToDisplay.inMinutes;
      return '${minutes}m';
    }

    // On regular screens, show full time format
    return SharedUiConstants.formatDuration(timeToDisplay);
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
  TimerMode _timerMode = TimerMode.pomodoro;
  Duration _elapsedTime = const Duration(); // For stopwatch mode
  Duration _sessionTotalElapsed = const Duration(); // Total elapsed time for the entire session

  int _getTotalDurationInSeconds() {
    if (_timerMode == TimerMode.normal) {
      return _getTimeInSeconds(_workDuration); // Use work duration as the timer duration in normal mode
    }

    // Pomodoro mode logic
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
    _timerMode = await _getTimerModeSetting();
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
        _elapsedTime = const Duration(); // Reset stopwatch
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

  Future<TimerMode> _getTimerModeSetting() async {
    try {
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(
        GetSettingQuery(key: SettingKeys.defaultTimerMode),
      );
      return TimerMode.fromString(response.getValue<String>());
    } catch (_) {
      return TimerMode.pomodoro; // Default value
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

  void _startAlarm() {
    // Ensure ticking is completely stopped before starting alarm
    _stopTicking();

    setState(() {
      _isAlarmPlaying = true;
    });

    // The sound player's play() method handles stopping previous sounds internally
    if (mounted && _isAlarmPlaying) {
      _soundManagerService.playTimerAlarm();
      // Set looping for continuous alarm (needs direct sound player access)
      _soundPlayer.setLoop(true);
    }

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

    // Reset session total elapsed time for new session
    _sessionTotalElapsed = const Duration();

    // Call the onTimerStart callback if provided
    widget.onTimerStart?.call();

    if (mounted) {
      _soundPlayer.setLoop(false);
      _soundManagerService.playTimerControl();
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
      if (!mounted) return;

      // Calculate the actual elapsed time increment for debug vs production
      final elapsedIncrement = kDebugMode
          ? const Duration(minutes: 1) // In debug mode, 1 minute of progress per second
          : const Duration(seconds: 1); // In production, 1 second of progress per second

      setState(() {
        if (_timerMode == TimerMode.stopwatch) {
          // Stopwatch mode: count up indefinitely
          _elapsedTime += elapsedIncrement;
        } else {
          // Normal and Pomodoro modes: count down
          _remainingTime -= elapsedIncrement;
        }
      });

      // Update session total elapsed time
      _sessionTotalElapsed += elapsedIncrement;

      // Call onTick for UI updates (passes current elapsed/remaining time, not increments)
      if (widget.onTick != null) {
        final timeToDisplay = _timerMode == TimerMode.stopwatch ? _elapsedTime : _remainingTime;
        widget.onTick!(timeToDisplay);
      }
      _updateSystemTrayTimer();

      // Check if countdown timer modes should finish
      if (_timerMode != TimerMode.stopwatch && _remainingTime.inSeconds <= 0) {
        _timer.cancel();
        _isRunning = false;
        _stopTicking(); // Stop ticking sound when timer completes
        _startAlarm();

        // Only auto-start next session in Pomodoro mode
        if (_timerMode == TimerMode.pomodoro) {
          if (_isWorking && _autoStartBreak || !_isWorking && _autoStartWork) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && _isAlarmPlaying) {
                _toggleWorkBreak();
              }
            });
          }
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
      // Stop ticking timer first
      _stopTicking();

      // Stop any playing sounds before playing button sound
      _soundPlayer.stop();

      // Disable looping and play button sound
      _soundPlayer.setLoop(false);
      _soundManagerService.playTimerControl();

      // Disable wakelock when stopping timer
      _wakelockService.disable();

      setState(() {
        _isRunning = false;
        _isAlarmPlaying = false; // Reset alarm state

        if (_timerMode == TimerMode.stopwatch) {
          _elapsedTime = const Duration(); // Reset stopwatch
        } else {
          if (_timerMode == TimerMode.pomodoro) {
            if (!_isWorking) {
              // If in break mode, switch back to work mode
              _isWorking = true;
            }
            _completedSessions = 0; // Reset completed sessions
            _isLongBreak = false; // Reset long break flag
          }

          _remainingTime = Duration(
            seconds: _getTimeInSeconds(_workDuration), // Always set to work duration
          );
        }

        // Stop timer
        _timer.cancel();

        _soundPlayer.stop(); // Stop any playing sounds
      });

      _resetSystemTrayIcon();
      _removeTimerMenuItems();
      // Reset system tray title/body when stopping timer
      _resetSystemTrayToDefault();

      // Call the onTimerStop callback with total elapsed duration for the session
      if (widget.onTimerStop != null) {
        widget.onTimerStop!(_sessionTotalElapsed);
      }
    }
  }

  void _setSystemTrayIcon() {
    _systemTrayService.setIcon(_isWorking ? TrayIconType.play : TrayIconType.pause);
  }

  void _resetSystemTrayIcon() {
    _systemTrayService.setIcon(TrayIconType.default_);
  }

  void _toggleWorkBreak() {
    if (!mounted) return;

    _stopAlarm();

    if (_timerMode == TimerMode.stopwatch) {
      // In stopwatch mode, just restart the timer
      setState(() {
        _elapsedTime = const Duration();
      });
      _startTimer();
      return;
    }

    if (_timerMode == TimerMode.normal) {
      // In normal mode, just restart the timer
      setState(() {
        _remainingTime = Duration(seconds: _getTimeInSeconds(_workDuration));
      });
      _startTimer();
      return;
    }

    // Pomodoro mode logic
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

  Future<void> _showSettingsModal() async {
    if (mounted) {
      await ResponsiveDialogHelper.showResponsiveDialog(
        context: context,
        size: DialogSize.medium,
        child: TimerSettingsDialog(
          initialTimerMode: _timerMode,
          initialWorkDuration: _workDuration,
          initialBreakDuration: _breakDuration,
          initialLongBreakDuration: _longBreakDuration,
          initialSessionsCount: _sessionsCount,
          initialAutoStartBreak: _autoStartBreak,
          initialAutoStartWork: _autoStartWork,
          initialTickingEnabled: _tickingEnabled,
          initialKeepScreenAwake: _keepScreenAwake,
          initialTickingVolume: _tickingVolume,
          initialTickingSpeed: _tickingSpeed,
          onSettingsChanged: (timerMode, workDuration, breakDuration, longBreakDuration, sessionsCount, autoStartBreak,
              autoStartWork, tickingEnabled, keepScreenAwake, tickingVolume, tickingSpeed) async {
            // Save settings
            await _saveSetting(SettingKeys.workTime, workDuration);
            await _saveSetting(SettingKeys.breakTime, breakDuration);
            await _saveSetting(SettingKeys.longBreakTime, longBreakDuration);
            await _saveSetting(SettingKeys.sessionsBeforeLongBreak, sessionsCount);

            if (mounted) {
              setState(() {
                _isWorking = true;
                _isRunning = false;
                _timerMode = timerMode;
                _workDuration = workDuration;
                _breakDuration = breakDuration;
                _longBreakDuration = longBreakDuration;
                _sessionsCount = sessionsCount;
                _autoStartBreak = autoStartBreak;
                _autoStartWork = autoStartWork;
                _tickingEnabled = tickingEnabled;
                _keepScreenAwake = keepScreenAwake;
                _tickingVolume = tickingVolume;
                _tickingSpeed = tickingSpeed;
                _isLongBreak = false;
                _completedSessions = 0;

                // Update timer display based on current mode
                if (_timerMode == TimerMode.stopwatch) {
                  // Reset stopwatch to 0:00
                  _elapsedTime = const Duration();
                } else {
                  // Update countdown timer
                  _remainingTime = Duration(seconds: _getTimeInSeconds(_workDuration));
                }
              });

              // Update defaults
              _defaultWorkDuration = workDuration;
              _defaultBreakDuration = breakDuration;
              _defaultLongBreakDuration = longBreakDuration;
              _defaultSessionsCount = sessionsCount;
              _defaultAutoStartBreak = autoStartBreak;
              _defaultAutoStartWork = autoStartWork;
              _defaultTickingEnabled = tickingEnabled;
              _defaultKeepScreenAwake = keepScreenAwake;
              _defaultTickingVolume = tickingVolume;
              _defaultTickingSpeed = tickingSpeed;
            }
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Calculate responsive sizes with running state multiplier
    final double multiplier = widget.isMiniLayout ? 1.0 : (!_isRunning && !_isAlarmPlaying ? 1.0 : 2.0);
    final double baseButtonSize = widget.isMiniLayout
        ? AppTheme.iconSizeSmall
        : (screenWidth < 600 ? AppTheme.iconSizeLarge : AppTheme.iconSizeXLarge);
    final double baseSpacing =
        widget.isMiniLayout ? AppTheme.size2XSmall : (screenWidth < 600 ? AppTheme.sizeSmall : AppTheme.sizeLarge);
    final double buttonSize = baseButtonSize * multiplier;
    final double spacing = baseSpacing * multiplier;

    final double progress;
    if (_timerMode == TimerMode.stopwatch) {
      // For stopwatch, we don't show progress (or could show elapsed time as a visual indicator)
      progress = 0.0;
    } else {
      progress = _isRunning || _isAlarmPlaying ? 1.0 - (_remainingTime.inSeconds / _getTotalDurationInSeconds()) : 0.0;
    }

    return AnimatedContainer(
      duration: widget.isMiniLayout ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.zero, // Padding will be handled by the inner content
      decoration: BoxDecoration(
        color: widget.isMiniLayout ? Colors.transparent : _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(buttonSize),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress Bar (hidden in mini layout)
          if (!widget.isMiniLayout)
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
                  duration: widget.isMiniLayout ? Duration.zero : const Duration(milliseconds: 300),
                  style: widget.isMiniLayout
                      ? AppTheme.bodyMedium
                      : (_isRunning || _isAlarmPlaying ? AppTheme.displayLarge : AppTheme.headlineMedium),
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
    final stopwatchColor = AppTheme.infoColor.withAlpha((255 * 0.8).toInt());
    final breakColor = AppTheme.successColor.withAlpha((255 * 1).toInt());
    final longBreakColor = AppTheme.infoColor.withAlpha((255 * 1).toInt());
    final workEndColor = AppTheme.successColor.withAlpha((255 * 1).toInt());
    final breakEndColor = AppTheme.errorColor.withAlpha((255 * 1).toInt());
    final longBreakEndColor = AppTheme.infoColor.withAlpha((255 * 1).toInt());

    if (_timerMode == TimerMode.stopwatch) {
      return _isRunning ? stopwatchColor : normalColor;
    }

    if (_timerMode == TimerMode.normal) {
      if (_isAlarmPlaying) return workEndColor;
      return normalColor;
    }

    // Pomodoro mode logic
    if (_isAlarmPlaying) {
      if (_isWorking) return workEndColor;
      return _isLongBreak ? longBreakEndColor : breakEndColor;
    }
    if (!_isRunning) return normalColor;
    return _isWorking ? normalColor : (_isLongBreak ? longBreakColor : breakColor);
  }

  IconData _getButtonIcon() {
    if (_isAlarmPlaying) {
      if (_timerMode == TimerMode.stopwatch || _timerMode == TimerMode.normal) {
        return TaskUiConstants.pomodoroStopIcon; // In stopwatch/normal mode, show stop to reset
      }
      return TaskUiConstants.pomodoroNextIcon; // In pomodoro mode, show next to continue
    }
    if (_isRunning) return TaskUiConstants.pomodoroStopIcon;
    return TaskUiConstants.pomodoroPlayIcon;
  }

  VoidCallback _getButtonAction() {
    if (_isAlarmPlaying) {
      if (_timerMode == TimerMode.stopwatch || _timerMode == TimerMode.normal) {
        return _stopTimer; // In stopwatch/normal mode, stop/reset the timer
      }
      return _toggleWorkBreak; // In pomodoro mode, continue to next phase
    }
    if (_isRunning) return _stopTimer;
    return _startTimer;
  }

  void _stopTicking() {
    _tickingTimer?.cancel();
    _tickingTimer = null;
    _isTickSound = true; // Reset to start with tick sound next time
  }

  Color _getProgressBarColor(BuildContext context) {
    if (_isRunning || _isAlarmPlaying) {
      if (_timerMode == TimerMode.stopwatch) {
        return AppTheme.infoColor.withValues(alpha: 0.3);
      }

      if (_timerMode == TimerMode.normal) {
        return AppTheme.successColor.withValues(alpha: 0.3);
      }

      // Pomodoro mode logic
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
      // Check if timer alarm sounds are enabled before playing ticking sounds
      if (_tickingEnabled) {
        if (_isTickSound) {
          _soundManagerService.playTimerTick();
        } else {
          _soundManagerService.playTimerTock();
        }
      }
      _isTickSound = !_isTickSound; // Toggle for next sound
    });
  }
}
