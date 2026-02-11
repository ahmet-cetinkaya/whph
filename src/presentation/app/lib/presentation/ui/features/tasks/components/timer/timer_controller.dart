import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';

/// Controller for timer business logic and state management.
/// Handles timer lifecycle, settings persistence, and session tracking.
class TimerController extends ChangeNotifier {
  final Mediator _mediator;

  TimerController({required Mediator mediator}) : _mediator = mediator;

  // Timer state
  Timer? _timer;
  Duration _remainingTime = const Duration();
  Duration _elapsedTime = const Duration();
  Duration _sessionTotalElapsed = const Duration();
  Duration _currentWorkSessionElapsed = const Duration();

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

  /// Callbacks for external effects (sounds, notifications, system tray)
  VoidCallback? onTimerStarted;
  void Function(Duration elapsed)? onTimerStopped;
  void Function(Duration elapsed)? onWorkSessionComplete;
  void Function(Duration elapsedIncrement)? onTick;
  VoidCallback? onAlarmStart;
  VoidCallback? onAlarmStop;

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
    } catch (_) {
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
    } catch (_) {
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
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> saveSetting(String key, int value) async {
    final command = SaveSettingCommand(
      key: key,
      value: value.toString(),
      valueType: SettingValueType.int,
    );
    await _mediator.send(command);
  }

  /// Start the timer
  void startTimer() {
    if (_isRunning || _isAlarmPlaying) return;

    _sessionTotalElapsed = const Duration();
    _currentWorkSessionElapsed = const Duration();

    onTimerStarted?.call();

    _isRunning = true;
    _startRegularTimer();
    notifyListeners();
  }

  void _startRegularTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsedIncrement = kDebugMode ? const Duration(minutes: 1) : const Duration(seconds: 1);

      if (_timerMode == TimerMode.stopwatch) {
        _elapsedTime += elapsedIncrement;
      } else {
        _remainingTime -= elapsedIncrement;
      }

      _sessionTotalElapsed += elapsedIncrement;

      if (_isWorking) {
        _currentWorkSessionElapsed += elapsedIncrement;
      }

      onTick?.call(elapsedIncrement);
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
          if (_isWorking && _autoStartBreak || !_isWorking && _autoStartWork) {
            Future.delayed(const Duration(seconds: 3), () {
              if (_isAlarmPlaying) {
                toggleWorkBreak();
              }
            });
          }
        }
      }
    });
  }

  /// Stop the timer
  void stopTimer() {
    _timer?.cancel();
    onAlarmStop?.call();

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
    super.dispose();
  }
}
