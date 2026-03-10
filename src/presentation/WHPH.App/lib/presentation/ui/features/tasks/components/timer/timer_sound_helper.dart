import 'dart:async';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';

/// Helper class for timer sound effects.
/// Handles alarm and ticking sounds.
class TimerSoundHelper {
  final ISoundManagerService _soundManagerService;

  Timer? _tickingTimer;
  bool _isTickSound = true;

  TimerSoundHelper({required ISoundManagerService soundManagerService}) : _soundManagerService = soundManagerService;

  /// Start the alarm sound
  void startAlarm() {
    stopTicking();
    _soundManagerService.playTimerAlarmLoop();
  }

  /// Stop the alarm sound
  void stopAlarm() {
    _soundManagerService.stopTimerAlarmLoop();
  }

  /// Play the timer control sound (for start/stop button)
  void playControlSound() {
    _soundManagerService.setLoop(false);
    _soundManagerService.playTimerControl();
  }

  /// Stop all sounds
  void stopAll() {
    _soundManagerService.stopAll();
  }

  /// Start the ticking sound with specified interval
  void startTicking({
    required bool isEnabled,
    required int tickingSpeed,
    required bool isRunning,
  }) {
    if (!isEnabled || _tickingTimer != null) return;

    final tickInterval = Duration(seconds: tickingSpeed);
    _tickingTimer = Timer.periodic(tickInterval, (timer) {
      if (!isRunning) {
        stopTicking();
        return;
      }

      if (_isTickSound) {
        _soundManagerService.playTimerTick();
      } else {
        _soundManagerService.playTimerTock();
      }
      _isTickSound = !_isTickSound;
    });
  }

  /// Stop the ticking sound
  void stopTicking() {
    _tickingTimer?.cancel();
    _tickingTimer = null;
    _isTickSound = true;
  }

  /// Dispose resources
  void dispose() {
    _tickingTimer?.cancel();
    _soundManagerService.stopAll();
  }
}
