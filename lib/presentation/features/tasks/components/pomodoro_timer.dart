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
  late int _currentWorkDuration;
  late int _currentBreakDuration;

  @override
  void initState() {
    super.initState();
    _getSettings().then((_) {
      _initializeTimer();
    });
  }

  void _initializeTimer() {
    _remainingTime = Duration(minutes: _currentWorkDuration);
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
      _remainingTime = Duration(minutes: _currentWorkDuration);
      _timer.cancel();
    });
  }

  void _toggleWorkBreak() {
    setState(() {
      _isWorking = !_isWorking;
      _remainingTime = _isWorking ? Duration(minutes: _currentWorkDuration) : Duration(minutes: _currentBreakDuration);
      _startTimer(); // Start the next session automatically
    });
  }

  Future<void> _getSettings() async {
    var workDurationSettingQuery = GetSettingQuery(key: 'workDuration');
    var breakDurationSettingQuery = GetSettingQuery(key: 'breakDuration');

    try {
      var workDurationSettingQueryResponse =
          await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(workDurationSettingQuery);

      setState(() {
        _currentWorkDuration = workDurationSettingQueryResponse.getValue<int>();
      });
    } catch (_) {
      setState(() {
        _currentWorkDuration = 25;
      });
    }

    try {
      var breakDurationSettingQueryResponse =
          await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(breakDurationSettingQuery);

      setState(() {
        _currentBreakDuration = breakDurationSettingQueryResponse.getValue<int>();
      });
    } catch (_) {
      setState(() {
        _currentBreakDuration = 5;
      });
    }
  }

  Future<void> _saveWorkDurationSetting(int workDuration) async {
    var workDurationSetting =
        SaveSettingCommand(key: 'workDuration', value: workDuration.toString(), valueType: SettingValueType.int);

    await _mediator.send(workDurationSetting);
  }

  Future<void> _saveBreakDurationSetting(int breakDuration) async {
    var breakDurationSetting =
        SaveSettingCommand(key: 'breakDuration', value: breakDuration.toString(), valueType: SettingValueType.int);

    await _mediator.send(breakDurationSetting);
  }

  void _showSettingsModal() {
    TextEditingController workController = TextEditingController(text: _currentWorkDuration.toString());
    TextEditingController breakController = TextEditingController(text: _currentBreakDuration.toString());

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Settings',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Work Time:'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: _currentWorkDuration > 5
                            ? () {
                                setState(() {
                                  _currentWorkDuration -= 5;
                                  workController.text = _currentWorkDuration.toString();
                                  if (_isWorking) {
                                    _remainingTime = Duration(minutes: _currentWorkDuration);
                                  }
                                });
                                _saveWorkDurationSetting(_currentWorkDuration);
                              }
                            : null,
                        tooltip: 'Decrease Work Time',
                      ),
                      SizedBox(
                        width: 50,
                        child: TextField(
                          controller: workController,
                          decoration: const InputDecoration(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) {
                            int? newValue = int.tryParse(value);
                            if (newValue != null) {
                              setState(() {
                                _currentWorkDuration = newValue;
                                if (_isWorking) {
                                  _remainingTime = Duration(minutes: _currentWorkDuration);
                                }
                              });
                              _saveWorkDurationSetting(_currentWorkDuration);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            _currentWorkDuration += 5;
                            workController.text = _currentWorkDuration.toString();
                            if (_isWorking) {
                              _remainingTime = Duration(minutes: _currentWorkDuration);
                            }
                          });
                          _saveWorkDurationSetting(_currentWorkDuration);
                        },
                        tooltip: 'Increase Work Time',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Break Time:'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: _currentBreakDuration > 1
                            ? () {
                                setState(() {
                                  _currentBreakDuration -= 1;
                                  breakController.text = _currentBreakDuration.toString();
                                  if (!_isWorking) {
                                    _remainingTime = Duration(minutes: _currentBreakDuration);
                                  }
                                });
                                _saveBreakDurationSetting(_currentBreakDuration);
                              }
                            : null,
                        tooltip: 'Decrease Break Time',
                      ),
                      SizedBox(
                        width: 50,
                        child: TextField(
                          controller: breakController,
                          decoration: const InputDecoration(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) {
                            int? newValue = int.tryParse(value);
                            if (newValue != null) {
                              setState(() {
                                _currentBreakDuration = newValue;
                                if (!_isWorking) {
                                  _remainingTime = Duration(minutes: _currentBreakDuration);
                                }
                              });
                              _saveBreakDurationSetting(_currentBreakDuration);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            _currentBreakDuration += 1;
                            breakController.text = _currentBreakDuration.toString();
                            if (!_isWorking) {
                              _remainingTime = Duration(minutes: _currentBreakDuration);
                            }
                          });
                          _saveBreakDurationSetting(_currentBreakDuration);
                        },
                        tooltip: 'Increase Break Time',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    if (_isRunning) {
      _timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettingsModal,
              tooltip: 'Settings',
            ),
            Row(
              children: [
                if (!_isRunning)
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _remainingTime.inMinutes > 1
                        ? () {
                            setState(() {
                              _remainingTime -= const Duration(minutes: 5);
                            });
                          }
                        : null,
                    tooltip: 'Decrease Time',
                  ),
                Text(
                  '${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 32),
                ),
                if (!_isRunning)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        _remainingTime += const Duration(minutes: 5);
                      });
                    },
                    tooltip: 'Increase Time',
                  ),
              ],
            ),
            IconButton(
              icon: Icon(!_isRunning ? Icons.play_arrow : Icons.stop),
              onPressed: !_isRunning ? _startTimer : _stopTimer,
              tooltip: !_isRunning ? 'Start' : 'Stop',
            ),
          ],
        ),
      ],
    );
  }
}
