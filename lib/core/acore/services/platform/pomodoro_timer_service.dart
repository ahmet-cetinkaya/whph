import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';

class PomodoroTimerService {
  static final MethodChannel _channel = MethodChannel(AndroidAppConstants.channels.pomodoroTimer);

  static final StreamController<int> _timerController = StreamController<int>.broadcast();
  static final StreamController<void> _completionController = StreamController<void>.broadcast();

  static Stream<int> get timerStream => _timerController.stream;
  static Stream<void> get completionStream => _completionController.stream;

  static bool _isInitialized = false;

  static void _initialize() {
    if (_isInitialized) return;

    _channel.setMethodCallHandler(_handleMethodCall);
    _isInitialized = true;
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTimerTick':
        final remainingSeconds = call.arguments['remainingSeconds'] as int?;
        if (remainingSeconds != null) {
          _timerController.add(remainingSeconds);
        }
        break;
      case 'onTimerComplete':
        _completionController.add(null);
        break;
    }
  }

  static Future<bool> startTimer(int durationSeconds) async {
    _initialize();

    try {
      // Enable wake lock to prevent device from sleeping
      await WakelockPlus.enable();

      final result = await _channel.invokeMethod('startTimer', {
        'durationSeconds': durationSeconds,
      });
      return result as bool? ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting timer service: $e');
      }
      return false;
    }
  }

  static Future<bool> stopTimer() async {
    try {
      // Disable wake lock when timer stops
      await WakelockPlus.disable();

      final result = await _channel.invokeMethod('stopTimer');
      return result as bool? ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping timer service: $e');
      }
      return false;
    }
  }

  static void dispose() {
    _timerController.close();
    _completionController.close();
    // Ensure wake lock is disabled
    WakelockPlus.disable().catchError((e) {
      if (kDebugMode) {
        print('Error disabling wake lock: $e');
      }
    });
  }
}
