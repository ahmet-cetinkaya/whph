import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';

/// Controller for timer business logic and state management.
/// Handles timer lifecycle, settings persistence, and session tracking.
class TimerController extends ChangeNotifier {
  final Mediator _mediator;
  final IReminderService _reminderService;
  static const _timerAlarmId = 'timer_alarm';
  static const _timerTickInterval = Duration(seconds: 1);

  TimerController({
    required Mediator mediator,
    required IReminderService reminderService,
  })  : _mediator = mediator,
        _reminderService = reminderService;

  // Timer state
  Timer? _timer;
  Duration _remainingTime = const Duration();
  Duration _elapsedTime = const Duration();
  Duration _sessionTotalElapsed = const Duration();
  Duration _currentWorkSessionElapsed = const Duration();
  DateTime? _startTimestamp;

  bool _isWorking = true;
  bool _isRunning = false;
  bool _isAlarmPlaying = false;
  bool _isLongBreak = false;
  int _completedSessions = 0;

  // Settings
  TimerMode _timerMode = TimerMode.pomodoro;
  int _workDuration = 25;
  int _breakDuration = 5;
  int _longBreakDuration = 15;
  int _sessionsCount = 4;
  bool _autoStartBreak = false;
  bool _autoStartWork = false;
  bool _tickingEnabled = false;
  bool _keepScreenAwake = false;
  int _tickingVolume = 50;
  int _tickingSpeed = 1;

  // Getters for state
  bool get isRunning => _isRunning;
  bool get isWorking => _isWorking;
  bool get isAlarmPlaying => _isAlarmPlaying;
  bool get isLongBreak => _isLongBreak;
  Duration get remainingTime => _remainingTime;
  Duration get elapsedTime => _elapsedTime;
  Duration get sessionTotalElapsed => _sessionTotalElapsed;
  Duration get currentWorkSessionElapsed => _currentWorkSessionElapsed;
  int get completedSessions => _completedSessions;

  // Getters for settings
  TimerMode get timerMode => _timerMode;
  int get workDuration => _workDuration;
  int get breakDuration => _breakDuration;
  int get longBreakDuration => _longBreakDuration;
  int get sessionsCount => _sessionsCount;
  bool get autoStartBreak => _autoStartBreak;
  bool get autoStartWork => _autoStartWork;
  bool get tickingEnabled => _tickingEnabled;
  bool get keepScreenAwake => _keepScreenAwake;
  int get tickingVolume => _tickingVolume;
  int get tickingSpeed => _tickingSpeed;

  /// Sets the localized alarm text for notifications.
  void setAlarmText({required String title, required String body}) {
    alarmTitle = title;
    alarmBody = body;
  }

  /// Callbacks for external effects (sounds, notifications, system tray)
  VoidCallback? onTimerStarted;
  void Function(Duration elapsed)? onTimerStopped;
  void Function(Duration elapsedIncrement)? onWorkSessionComplete;
  void Function(Duration elapsedIncrement)? onTick;
  VoidCallback? onAlarmStart;
  VoidCallback? onAlarmStop;

  /// Localized alarm notification text, set by the UI layer.
  /// Falls back to English defaults when not provided.
  String alarmTitle = 'Timer Completed';
  String alarmBody = 'Timer has finished';

  int getTimeInSeconds(int value) => value * 60;

  int getTotalDurationInSeconds() {
    if (_timerMode == TimerMode.normal) {
      return getTimeInSeconds(_workDuration);
    }
    if (_isWorking) return getTimeInSeconds(_workDuration);
    if (_isLongBreak) return getTimeInSeconds(_longBreakDuration);
    return getTimeInSeconds(_breakDuration);
  }

  /// Initialize timer settings from persistence
  Future<void> initializeSettings() async {
    _timerMode = await _getTimerModeSetting();
    _workDuration = await _getSetting(SettingKeys.workTime, 25);
    _breakDuration = await _getSetting(SettingKeys.breakTime, 5);
    _longBreakDuration = await _getSetting(SettingKeys.longBreakTime, 15);
    _sessionsCount = await _getSetting(SettingKeys.sessionsBeforeLongBreak, 4);
    _autoStartBreak = await _getBoolSetting(SettingKeys.autoStartBreak, false);
    _autoStartWork = await _getBoolSetting(SettingKeys.autoStartWork, false);
    _tickingEnabled = await _getBoolSetting(SettingKeys.tickingEnabled, false);
    _keepScreenAwake = await _getBoolSetting(SettingKeys.keepScreenAwake, false);
    _tickingVolume = await _getSetting(SettingKeys.tickingVolume, 50);
    _tickingSpeed = await _getSetting(SettingKeys.tickingSpeed, 1);

    // Ensure minimum volume is 5
    if (_tickingVolume < 5) {
      _tickingVolume = 5;
      await saveSetting(SettingKeys.tickingVolume, _tickingVolume);
    }

    _remainingTime = Duration(seconds: getTimeInSeconds(_workDuration));
    _elapsedTime = const Duration();
    _isLongBreak = false;
    _completedSessions = 0;

    notifyListeners();
  }

  Future<bool> _getBoolSetting(String key, bool defaultValue) async {
    try {
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: key),
      );
      if (response == null) return defaultValue;
      return response.getValue<bool>();
    } catch (e, stackTrace) {
      Logger.warning(
        'Failed to load timer setting "$key", using default: $defaultValue',
        component: 'TimerController',
        error: e,
        stackTrace: stackTrace,
      );
      return defaultValue;
    }
  }

  Future<TimerMode> _getTimerModeSetting() async {
    try {
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: SettingKeys.defaultTimerMode),
      );
      if (response == null) return TimerMode.pomodoro;
      return TimerMode.fromString(response.getValue<String>());
    } catch (e, stackTrace) {
      Logger.warning(
        'Failed to load timer mode setting, using default: pomodoro',
        component: 'TimerController',
        error: e,
        stackTrace: stackTrace,
      );
      return TimerMode.pomodoro;
    }
  }

  Future<int> _getSetting(String key, int defaultValue) async {
    try {
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: key),
      );
      if (response == null) return defaultValue;
      return response.getValue<int>();
    } catch (e, stackTrace) {
      Logger.warning(
        'Failed to load timer setting "$key", using default: $defaultValue',
        component: 'TimerController',
        error: e,
        stackTrace: stackTrace,
      );
      return defaultValue;
    }
  }

  Future<bool> saveSetting(String key, int value) async {
    try {
      final command = SaveSettingCommand(
        key: key,
        value: value.toString(),
        valueType: SettingValueType.int,
      );
      await _mediator.send(command);
      return true;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to save timer setting "$key" with value $value',
        component: 'TimerController',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _cancelAlarm(String debugContext) async {
    try {
      await _reminderService.cancelReminder(_timerAlarmId);
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to cancel timer alarm during $debugContext',
        component: 'TimerController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Start the timer
  void startTimer() {
    if (_isRunning || _isAlarmPlaying) return;

    // Only reset elapsed times if starting a fresh session (not resuming from pause)
    final isResuming = _timerMode == TimerMode.stopwatch
        ? _elapsedTime > Duration.zero
        : _remainingTime.inSeconds < getTotalDurationInSeconds();
    if (!isResuming) {
      _sessionTotalElapsed = const Duration();
      _currentWorkSessionElapsed = const Duration();
    }

    onTimerStarted?.call();

    _isRunning = true;
    _startRegularTimer();
    notifyListeners();
  }

  void _startRegularTimer() {
    // Capture initial state to calculate elapsed time from wall-clock difference.
    // This approach ensures accuracy regardless of tick frequency or jitter.
    // Each timer tick computes: elapsed = initial + (now - startTimestamp)
    _startTimestamp = clock.now();
    var initialElapsed = _sessionTotalElapsed;
    var initialCurrentWorkElapsed = _currentWorkSessionElapsed;
    var initialStopwatchElapsed = _elapsedTime;
    var initialRemaining = _remainingTime;
    final isWorkingAtStart = _isWorking;
    var previousTotalElapsed = _sessionTotalElapsed;

    // Schedule system alarm for exact wake-up (countdown modes only)
    // Stopwatch mode runs indefinitely and has no natural end point.
    // Alarm is automatically cancelled when timer stops, pauses, or toggles between work/break.
    if (_timerMode != TimerMode.stopwatch) {
      final alarmTime = _startTimestamp!.add(initialRemaining);
      try {
        _reminderService.scheduleReminder(
          id: _timerAlarmId,
          title: alarmTitle,
          body: alarmBody,
          scheduledDate: alarmTime,
        );
      } catch (e, stackTrace) {
        Logger.error(
          'Failed to schedule timer alarm - notification may not fire when timer completes',
          component: 'TimerController',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    _timer = Timer.periodic(_timerTickInterval, (timer) {
      try {
        if (_startTimestamp == null) return;
        final now = clock.now();
        Duration elapsedIncrement = now.difference(_startTimestamp!);

        // Guard against clock being adjusted backwards (e.g., user manually changes time, NTP sync)
        // When detected, we reset the baseline to prevent negative elapsed time.
        // The timer effectively pauses for the duration of the backward jump.
        // Note: System alarm is not rescheduled, so timer may complete later than expected.
        if (elapsedIncrement.isNegative) {
          _startTimestamp = now;
          initialElapsed = _sessionTotalElapsed;
          initialCurrentWorkElapsed = _currentWorkSessionElapsed;
          initialStopwatchElapsed = _elapsedTime;
          initialRemaining = _remainingTime;
          elapsedIncrement = Duration.zero;
        }

        // Guard against clock being adjusted forward (e.g., user manually changes time, NTP sync)
        // Use a stable 30s threshold to detect real clock jumps while allowing normal operation
        final expectedMaxIncrement = const Duration(seconds: 30);
        if (elapsedIncrement > expectedMaxIncrement) {
          Logger.warning(
            'Clock adjusted forward, resetting baseline to prevent timer jump',
            component: 'TimerController',
          );
          _startTimestamp = now;
          initialElapsed = _sessionTotalElapsed;
          initialCurrentWorkElapsed = _currentWorkSessionElapsed;
          initialStopwatchElapsed = _elapsedTime;
          initialRemaining = _remainingTime;
          elapsedIncrement = Duration(seconds: timer.tick);
        }

        // Calculate all values using actual wall-clock time difference
        _sessionTotalElapsed = initialElapsed + elapsedIncrement;

        if (isWorkingAtStart) {
          _currentWorkSessionElapsed = initialCurrentWorkElapsed + elapsedIncrement;
        }

        if (_timerMode == TimerMode.stopwatch) {
          _elapsedTime = initialStopwatchElapsed + elapsedIncrement;
        } else {
          _remainingTime = initialRemaining - elapsedIncrement;
        }

        final tickDelta = _sessionTotalElapsed - previousTotalElapsed;
        previousTotalElapsed = _sessionTotalElapsed;

        onTick?.call(tickDelta);
        notifyListeners();

        // Check if countdown timer modes should finish
        if (_timerMode != TimerMode.stopwatch && _remainingTime.inSeconds <= 0) {
          _timer?.cancel();
          _isRunning = false;
          onAlarmStart?.call();
          _isAlarmPlaying = true;
          notifyListeners();

          // Only auto-start next session in Pomodoro mode
          if (_timerMode == TimerMode.pomodoro) {
            if ((_isWorking && _autoStartBreak) || (!_isWorking && _autoStartWork)) {
              Future.delayed(const Duration(seconds: 3), () {
                if (_isAlarmPlaying) {
                  toggleWorkBreak();
                }
              });
            }
          }
        }
      } catch (e, stackTrace) {
        Logger.error(
          'Timer periodic tick callback failed',
          component: 'TimerController',
          error: e,
          stackTrace: stackTrace,
        );
        _timer?.cancel();
        _isRunning = false;
        _cancelAlarm('periodic tick error');
        notifyListeners();
      }
    });
  }

  /// Pause the timer
  void pauseTimer() {
    _timer?.cancel();
    _startTimestamp = null;
    _cancelAlarm('pause');

    _isRunning = false;
    notifyListeners();
  }

  /// Stop the timer
  void stopTimer() {
    _timer?.cancel();
    onAlarmStop?.call();
    _startTimestamp = null;
    _cancelAlarm('stop');

    _isRunning = false;
    _isAlarmPlaying = false;

    if (_timerMode == TimerMode.stopwatch) {
      _elapsedTime = const Duration();
    } else {
      if (_timerMode == TimerMode.pomodoro) {
        if (!_isWorking) {
          _isWorking = true;
        }
        _completedSessions = 0;
        _isLongBreak = false;
      }
      _remainingTime = Duration(seconds: getTimeInSeconds(_workDuration));
    }

    _currentWorkSessionElapsed = Duration.zero;

    onTimerStopped?.call(_sessionTotalElapsed);
    notifyListeners();
  }

  /// Toggle between work and break (for Pomodoro mode)
  void toggleWorkBreak() {
    onAlarmStop?.call();
    _isAlarmPlaying = false;

    if (_timerMode == TimerMode.stopwatch) {
      _elapsedTime = const Duration();
      notifyListeners();
      startTimer();
      return;
    }

    if (_timerMode == TimerMode.normal) {
      _remainingTime = Duration(seconds: getTimeInSeconds(_workDuration));
      notifyListeners();
      startTimer();
      return;
    }

    // Pass the current work session duration when work completes
    if (_isWorking && _currentWorkSessionElapsed > Duration.zero) {
      onWorkSessionComplete?.call(_currentWorkSessionElapsed);
    }

    if (_isWorking) {
      _completedSessions++;
      _isWorking = false;
      _isLongBreak = _completedSessions >= _sessionsCount;

      if (_isLongBreak) {
        _completedSessions = 0;
      }

      _remainingTime = Duration(
        seconds: getTimeInSeconds(_isLongBreak ? _longBreakDuration : _breakDuration),
      );

      _currentWorkSessionElapsed = Duration.zero;
    } else {
      _isWorking = true;
      _isLongBreak = false;
      _remainingTime = Duration(seconds: getTimeInSeconds(_workDuration));
      _currentWorkSessionElapsed = Duration.zero;
    }

    _startTimestamp = null;
    _cancelAlarm('work/break toggle');
    notifyListeners();
    startTimer();
  }

  /// Update settings from dialog
  void updateSettings({
    required TimerMode timerMode,
    required int workDuration,
    required int breakDuration,
    required int longBreakDuration,
    required int sessionsCount,
    required bool autoStartBreak,
    required bool autoStartWork,
    required bool tickingEnabled,
    required bool keepScreenAwake,
    required int tickingVolume,
    required int tickingSpeed,
  }) {
    // Cancel active timer and alarm before applying new settings
    _timer?.cancel();
    _cancelAlarm('settings update');
    _startTimestamp = null;

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

    if (_timerMode == TimerMode.stopwatch) {
      _elapsedTime = const Duration();
    } else {
      _remainingTime = Duration(seconds: getTimeInSeconds(_workDuration));
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelAlarm('disposal');
    super.dispose();
  }
}
