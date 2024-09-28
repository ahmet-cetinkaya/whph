import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/main.dart';

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
  final Mediator _mediator = container.resolve<Mediator>();
  late Timer _timer;
  Duration _remainingTime = const Duration();
  bool _isWorking = true;
  bool _isRunning = false;
  late int _workDuration;
  late int _breakDuration;

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
    _workDuration = await _getSetting('workDuration', 25);
    _breakDuration = await _getSetting('breakDuration', 5);
    _remainingTime = Duration(minutes: _workDuration);
    setState(() {});
  }

  Future<int> _getSetting(String key, int defaultValue) async {
    try {
      var response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(
        GetSettingQuery(key: key),
      );
      return response.getValue<int>();
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> _saveSetting(String key, int value) async {
    var command = SaveSettingCommand(key: key, value: value.toString(), valueType: SettingValueType.int);
    await _mediator.send(command);
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

  void _adjustWorkDuration(int adjustment) {
    setState(() {
      _workDuration = (_workDuration + adjustment).clamp(5, 60);
      if (_isWorking) _remainingTime = Duration(minutes: _workDuration);
    });
    _saveSetting('workDuration', _workDuration);
  }

  void _adjustBreakDuration(int adjustment) {
    setState(() {
      _breakDuration = (_breakDuration + adjustment).clamp(1, 30);
      if (!_isWorking) _remainingTime = Duration(minutes: _breakDuration);
    });
    _saveSetting('breakDuration', _breakDuration);
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      builder: (_) => _buildSettingsModal(),
    );
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettingsModal,
        ),
        _buildTimeDisplay(),
        IconButton(
          icon: Icon(!_isRunning ? Icons.play_arrow : Icons.stop),
          onPressed: !_isRunning ? _startTimer : _stopTimer,
        ),
      ],
    );
  }

  Widget _buildSettingsModal() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSettingRow('Work Time', _workDuration, _adjustWorkDuration),
          const SizedBox(height: 16),
          _buildSettingRow('Break Time', _breakDuration, _adjustBreakDuration),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, int duration, Function(int) onAdjust) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: duration > (label == 'Work Time' ? 5 : 1) ? () => onAdjust(-1) : null,
            ),
            Text('$duration min', style: const TextStyle(fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onAdjust(1),
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
                onPressed: _remainingTime.inMinutes > 1
                    ? () {
                        setState(() {
                          _remainingTime -= const Duration(minutes: 5);
                        });
                      }
                    : null,
              ),
        Text(
          '${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 32),
        ),
        _isRunning
            ? const SizedBox(width: 40)
            : IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    _remainingTime += const Duration(minutes: 5);
                  });
                },
              ),
      ],
    );
  }
}
