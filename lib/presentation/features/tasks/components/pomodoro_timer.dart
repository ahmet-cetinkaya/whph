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
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/constants/shared_sounds.dart';

class PomodoroTimer extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final ISoundPlayer _soundPlayer = container.resolve<ISoundPlayer>();

  final Function(Duration) onTimeUpdate;

  PomodoroTimer({
    super.key,
    required this.onTimeUpdate,
  });

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
  static const int _minTimerValue = 5;
  static const int _maxTimerValue = 120;

  // Helper methods for time calculations
  int _getTimeInSeconds(int value) {
    if (kDebugMode) {
      print('DEBUG: Time will be in seconds. (PomodoroTimer)');
      return value;
    }

    return value * 60;
  }

  String _getDisplayTime() {
    final minutes = _remainingTime.inMinutes;
    final seconds = _remainingTime.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
    }
    widget._soundPlayer.stop(); // Stop any playing sounds
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
      var response = await widget._mediator.send<GetSettingQuery, GetSettingQueryResponse>(
        GetSettingQuery(key: key),
      );
      return response.getValue<int>();
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> _saveSetting(String key, int value) async {
    var command = SaveSettingCommand(key: key, value: value.toString(), valueType: SettingValueType.int);
    await widget._mediator.send(command);
  }

  void _startAlarm() {
    setState(() {
      _isAlarmPlaying = true;
    });

    widget._soundPlayer.setLoop(true);
    widget._soundPlayer.play(SharedSounds.alarmDone);
  }

  void _stopAlarm() {
    widget._soundPlayer.stop();
    widget._soundPlayer.setLoop(false);
    setState(() {
      _isAlarmPlaying = false;
    });
  }

  void _startTimer() {
    if (_isRunning || _isAlarmPlaying) return;

    if (mounted) {
      setState(() {
        _isRunning = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_remainingTime.inSeconds > 0) {
            if (!mounted) return;
            setState(() {
              _remainingTime -= const Duration(seconds: 1);
            });
            widget.onTimeUpdate(_remainingTime);
          } else {
            _timer.cancel();
            _isRunning = false;
            _startAlarm(); // Süre bitince alarm çal ve bekle
          }
        });
      });
    }
  }

  void _stopTimer() {
    if (mounted) {
      setState(() {
        _isRunning = false;
        if (!_isWorking) {
          // If in break mode, switch back to work mode
          _isWorking = true;
        }
        _remainingTime = Duration(
          seconds: _getTimeInSeconds(_workDuration), // Always set to work duration
        );
        _timer.cancel();
        widget._soundPlayer.stop(); // Stop any playing sounds
      });
    }
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
    final double multiplier = !_isRunning && !_isAlarmPlaying ? 1.0 : 2.0; // Only shrink when stopped
    final double buttonSize = (screenWidth < 600 ? 32.0 : 40.0) * multiplier;
    final double fontSize = (screenWidth < 600 ? 24.0 : 32.0) * multiplier;
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
              icon: const Icon(Icons.settings),
              onPressed: _showSettingsModal,
            ),
          SizedBox(width: spacing),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFeatures: const [
                FontFeature.tabularFigures(),
              ],
            ),
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
    final normalColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final breakColor = Theme.of(context).colorScheme.tertiaryContainer;
    final breakEndColor = Theme.of(context).colorScheme.errorContainer;

    if (_isAlarmPlaying) return _isWorking ? breakColor : breakEndColor;
    if (!_isRunning) return normalColor;
    return _isWorking ? normalColor : breakColor;
  }

  IconData _getButtonIcon() {
    if (_isAlarmPlaying) return Icons.arrow_forward; // Changed from skip_next
    if (_isRunning) return Icons.stop;
    return Icons.play_arrow;
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
          Center(child: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold))),
          const Text(
            'Default timer settings (in minutes):',
            style: TextStyle(color: AppTheme.secondaryTextColor),
          ),
          _buildSettingRow('Work Time', _workDuration, (adjustment) {
            if (!mounted) return;
            setState(() {
              _workDuration = (_workDuration + adjustment).clamp(_minTimerValue, _maxTimerValue);
            });
          }),
          _buildSettingRow('Break Time', _breakDuration, (adjustment) {
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
              icon: Icon(Icons.remove),
              onPressed: value > _minTimerValue ? () => onAdjust(-5) : null,
            ),
            SizedBox(width: 80, child: Center(child: Text("$value min"))),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: value < _maxTimerValue ? () => onAdjust(5) : null,
            ),
          ],
        ),
      ],
    );
  }
}
