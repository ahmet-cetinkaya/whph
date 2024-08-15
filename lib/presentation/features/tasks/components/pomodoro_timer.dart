import 'dart:async';

import 'package:flutter/material.dart';

class PomodoroTimer extends StatefulWidget {
  final Function(Duration) onTimeUpdate;
  final int workDuration; // in minutes
  final int breakDuration; // in minutes

  const PomodoroTimer({
    super.key,
    required this.onTimeUpdate,
    this.workDuration = 25,
    this.breakDuration = 5,
  });

  @override
  _PomodoroTimerState createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
  late Timer _timer;
  Duration _remainingTime = const Duration();
  bool _isWorking = true;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  void _initializeTimer() {
    _remainingTime = Duration(minutes: widget.workDuration);
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
      _remainingTime = Duration(minutes: widget.workDuration);
      _timer.cancel();
    });
  }

  void _toggleWorkBreak() {
    _isWorking = !_isWorking;
    _remainingTime = _isWorking ? Duration(minutes: widget.workDuration) : Duration(minutes: widget.breakDuration);
    _startTimer(); // Start the next session automatically
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
    return Row(
      children: [
        Text(
          '${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 32),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(!_isRunning ? Icons.play_arrow : Icons.stop),
              onPressed: !_isRunning ? _startTimer : _stopTimer,
              tooltip: 'Start',
            ),
          ],
        ),
      ],
    );
  }
}
