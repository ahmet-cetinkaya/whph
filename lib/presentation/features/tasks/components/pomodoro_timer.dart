import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/domain/features/settings/constants/settings.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_sounds.dart';
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/domain/shared/constants/app_assets.dart';
import 'package:whph/presentation/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class PomodoroTimer extends StatefulWidget {
  final Function(Duration) onTimeUpdate;

  const PomodoroTimer({
    super.key,
    required this.onTimeUpdate,
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

  static const int _minTimerValue = 5;
  static const int _maxTimerValue = 120;

  // Helper methods for time calculations
  int _getTimeInSeconds(int value) {
    return value * 60;
  }

  String _getDisplayTime() {
    return SharedUiConstants.formatDuration(_remainingTime);
  }

  late Timer _timer;
  Duration _remainingTime = const Duration();
  bool _isWorking = true;
  bool _isRunning = false;
  int _defaultWorkDuration = 25;
  int _defaultBreakDuration = 5;
  late int _workDuration = _defaultWorkDuration;
  late int _breakDuration = _defaultBreakDuration;
  bool _isAlarmPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  @override
  void dispose() {
    if (_isRunning) {
      _timer.cancel();
      _removeTimerMenuItems();
    }
    _soundPlayer.stop();
    super.dispose();
  }

  Future<void> _initializeSettings() async {
    _defaultWorkDuration = await _getSetting(Settings.workTime, 25);
    _defaultBreakDuration = await _getSetting(Settings.breakTime, 5);
    if (mounted) {
      setState(() {
        _workDuration = _defaultWorkDuration;
        _breakDuration = _defaultBreakDuration;
        _remainingTime = Duration(seconds: _getTimeInSeconds(_workDuration));
      });
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
    setState(() {
      _isAlarmPlaying = true;
    });

    _soundPlayer.setLoop(true);
    _soundPlayer.play(SharedSounds.alarmDone);

    _sendNotification();
  }

  void _sendNotification() {
    _notificationService.show(
      title: _translationService.translate(TaskTranslationKeys.pomodoroNotificationTitle),
      body: _isWorking
          ? _translationService.translate(TaskTranslationKeys.pomodoroWorkSessionCompleted)
          : _translationService.translate(TaskTranslationKeys.pomodoroBreakSessionCompleted),
    );
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

    if (mounted) {
      _setSystemTrayIcon();
      _addTimerMenuItems();
      _updateSystemTrayTimer();

      setState(() {
        _isRunning = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_remainingTime.inSeconds > 0) {
            if (!mounted) return;
            setState(() {
              _remainingTime -= kDebugMode
                  ? const Duration(minutes: 1) // Simulate 1 minute for testing
                  : const Duration(seconds: 1);
            });
            widget.onTimeUpdate(_remainingTime);
            _updateSystemTrayTimer();
          } else {
            _timer.cancel();
            _isRunning = false;
            _startAlarm();
          }
        });
      });
    }
  }

  void _updateSystemTrayTimer() {
    final status = _isWorking ? 'Work' : 'Break';
    _systemTrayService.setTitle('$status - ${_getDisplayTime()}');
    _systemTrayService.setBody('Timer running');
  }

  void _stopTimer() {
    if (mounted) {
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
        _timer.cancel();
        _soundPlayer.stop(); // Stop any playing sounds
      });

      _resetSystemTrayIcon();
      _removeTimerMenuItems();
      _systemTrayService.setTitle('App Running');
      _systemTrayService.setBody('Tap to open');
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
        _isWorking = !_isWorking;
        _remainingTime = Duration(
          seconds: _getTimeInSeconds(_isWorking ? _workDuration : _breakDuration),
        );
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

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return _buildSettingsModal(setState);
          },
        );
      },
    );

    // Save settings
    _saveSetting(Settings.workTime, _workDuration);
    _saveSetting(Settings.breakTime, _breakDuration);
    _defaultWorkDuration = _workDuration;
    _defaultBreakDuration = _breakDuration;

    // Update current timer if settings changed
    if (mounted && (previousWorkDuration != _workDuration || previousBreakDuration != _breakDuration)) {
      setState(() {
        _remainingTime = Duration(minutes: _isWorking ? _workDuration : _breakDuration);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive sizes with running state multiplier
    final double multiplier = !_isRunning && !_isAlarmPlaying ? 1.0 : 2.0;
    final double buttonSize = (screenWidth < 600 ? 32.0 : 40.0) * multiplier;
    final double spacing = (screenWidth < 600 ? 8.0 : 16.0) * multiplier;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(buttonSize),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isRunning && !_isAlarmPlaying)
            IconButton(
              iconSize: buttonSize * 0.7,
              icon: Icon(SharedUiConstants.settingsIcon),
              onPressed: _showSettingsModal,
            ),
          SizedBox(width: spacing),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: _isRunning || _isAlarmPlaying ? AppTheme.displayLarge : AppTheme.headlineMedium,
            child: Text(_getDisplayTime()),
          ),
          SizedBox(width: spacing),
          IconButton(
            iconSize: buttonSize * 0.7,
            icon: Icon(_getButtonIcon()),
            onPressed: _getButtonAction(),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    final normalColor = AppTheme.surface2;
    final breakColor = AppTheme.successColor.withAlpha((255 * 1).toInt());
    final workEndColor = AppTheme.successColor.withAlpha((255 * 1).toInt());
    final breakEndColor = AppTheme.errorColor.withAlpha((255 * 1).toInt());

    if (_isAlarmPlaying) return _isWorking ? workEndColor : breakEndColor;
    if (!_isRunning) return normalColor;
    return _isWorking ? normalColor : breakColor;
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

  Widget _buildSettingsModal(StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
              child: Text(_translationService.translate(TaskTranslationKeys.pomodoroSettingsLabel),
                  style: AppTheme.headlineSmall)),
          Text(
            _translationService.translate(TaskTranslationKeys.pomodoroTimerSettingsLabel),
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryTextColor),
          ),
          _buildSettingRow(_translationService.translate(TaskTranslationKeys.pomodoroWorkLabel), _workDuration,
              (adjustment) {
            if (!mounted) return;
            setState(() {
              _workDuration = (_workDuration + adjustment).clamp(_minTimerValue, _maxTimerValue);
            });
          }),
          _buildSettingRow(_translationService.translate(TaskTranslationKeys.pomodoroBreakLabel), _breakDuration,
              (adjustment) {
            if (!mounted) return;
            setState(() {
              _breakDuration = (_breakDuration + adjustment).clamp(_minTimerValue, _maxTimerValue);
            });
          }),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, int value, Function(int) onAdjust) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: value > _minTimerValue ? () => onAdjust(-5) : null,
            ),
            SizedBox(width: 80, child: Center(child: Text("$value min"))),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: value < _maxTimerValue ? () => onAdjust(5) : null,
            ),
          ],
        ),
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
}
