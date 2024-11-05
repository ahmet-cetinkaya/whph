import 'dart:async';
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
  late Timer _timer;
  Duration _remainingTime = const Duration();
  bool _isWorking = true;
  bool _isRunning = false;
  late int _workDuration;
  int _defaultWorkDuration = 25;
  late int _breakDuration;
  int _defaultBreakDuration = 5;

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
    super.dispose();
  }

  Future<void> _initializeSettings() async {
    _defaultWorkDuration = await _getSetting(Settings.workTime, 25);
    _defaultBreakDuration = await _getSetting(Settings.breakTime, 5);
    setState(() {
      _workDuration = _defaultWorkDuration;
      _breakDuration = _defaultBreakDuration;
      _remainingTime = Duration(minutes: _workDuration);
    });
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

  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingTime.inSeconds > 0) {
          setState(() {
            _remainingTime -= const Duration(seconds: 1);
          });
          widget.onTimeUpdate(_remainingTime);
        } else {
          widget._soundPlayer.play(SharedSounds.alarmDone);
          _toggleWorkBreak();
        }
      });
    });
  }

  void _stopTimer() {
    setState(() {
      _isRunning = false;
      _remainingTime = Duration(minutes: _workDuration);
      _timer.cancel();
    });
  }

  void _toggleWorkBreak() {
    setState(() {
      _isWorking = !_isWorking;
      _remainingTime = _isWorking ? Duration(minutes: _workDuration) : Duration(minutes: _breakDuration);
      _startTimer(); // Automatically start the next session
    });
  }

  Future<void> _showSettingsModal() async {
    setState(() {
      _isWorking = true;
      _isRunning = false;
      _workDuration = _defaultWorkDuration;
      _breakDuration = _defaultBreakDuration;
    });
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
    _saveSetting(Settings.workTime, _workDuration);
    _defaultBreakDuration = _breakDuration;
    _saveSetting(Settings.breakTime, _breakDuration);
    _defaultWorkDuration = _workDuration;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTimerControls(),
      ],
    );
  }

  Widget _buildTimerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          icon: Icon(!_isRunning ? Icons.play_arrow : Icons.stop),
          onPressed: !_isRunning ? _startTimer : _stopTimer,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: _buildTimeDisplay(),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettingsModal,
        ),
      ],
    );
  }

  static const int _minTimerValue = 1;
  static const int _maxTimerValue = 120;
  Widget _buildSettingsModal(StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold))),
          const Text(
            'Default timer settings:',
            style: TextStyle(color: AppTheme.secondaryTextColor),
          ),
          _buildSettingRow('Work Time', _workDuration, (adjustment) {
            setState(() {
              _workDuration = (_workDuration + adjustment).clamp(_minTimerValue, _maxTimerValue);
            });
          }),
          _buildSettingRow('Break Time', _breakDuration, (adjustment) {
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
            SizedBox(width: 80, child: Center(child: Text("${value.toString()} min"))),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: value < _maxTimerValue ? () => onAdjust(5) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeDisplay() {
    return Row(
      children: [
        _isRunning
            ? const SizedBox(width: 40)
            : IconButton(
                icon: const Icon(Icons.remove),
                onPressed:
                    _isWorking && _workDuration > _minTimerValue || !_isWorking && _breakDuration > _minTimerValue
                        ? () {
                            setState(() {
                              if (_isWorking) {
                                _workDuration = (_workDuration - 5).clamp(_minTimerValue, _maxTimerValue);
                                _remainingTime = Duration(minutes: _workDuration);
                              } else {
                                _breakDuration = (_breakDuration - 5).clamp(_minTimerValue, _maxTimerValue);
                                _remainingTime = Duration(minutes: _breakDuration);
                              }
                            });
                          }
                        : null,
              ),
        SizedBox(
          width: 120,
          child: Center(
            child: Text(
              '${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
        _isRunning
            ? const SizedBox(width: 40)
            : IconButton(
                icon: const Icon(Icons.add),
                onPressed:
                    _isWorking && _workDuration < _maxTimerValue || !_isWorking && _breakDuration < _maxTimerValue
                        ? () {
                            setState(() {
                              if (_isWorking) {
                                _workDuration = (_workDuration + 5).clamp(_minTimerValue, _maxTimerValue);
                                _remainingTime = Duration(minutes: _workDuration);
                              } else {
                                _breakDuration = (_breakDuration + 5).clamp(_minTimerValue, _maxTimerValue);
                                _remainingTime = Duration(minutes: _breakDuration);
                              }
                            });
                          }
                        : null,
              ),
      ],
    );
  }
}
