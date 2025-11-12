import 'package:acore/acore.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_sounds.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_sounds.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';

class SoundManagerService implements ISoundManagerService {
  final ISoundPlayer _soundPlayer;
  final ISettingRepository _settingRepository;

  // Cache settings to avoid repeated database calls
  bool? _soundEnabled;
  bool? _taskCompletionSoundEnabled;
  bool? _habitCompletionSoundEnabled;
  bool? _timerControlSoundEnabled;
  bool? _timerAlarmSoundEnabled;
  bool? _tickingEnabled;

  SoundManagerService({
    required ISoundPlayer soundPlayer,
    required ISettingRepository settingRepository,
  })  : _soundPlayer = soundPlayer,
        _settingRepository = settingRepository;

  /// Master sound toggle - affects all sounds
  Future<bool> _isSoundEnabled() async {
    _soundEnabled ??= await _getBoolSetting(SettingKeys.soundEnabled, defaultValue: true);
    return _soundEnabled!;
  }

  /// Individual sound category toggles
  Future<bool> _isTaskCompletionSoundEnabled() async {
    if (!await _isSoundEnabled()) return false;
    _taskCompletionSoundEnabled ??= await _getBoolSetting(SettingKeys.taskCompletionSoundEnabled, defaultValue: true);
    return _taskCompletionSoundEnabled!;
  }

  Future<bool> _isHabitCompletionSoundEnabled() async {
    if (!await _isSoundEnabled()) return false;
    _habitCompletionSoundEnabled ??= await _getBoolSetting(SettingKeys.habitCompletionSoundEnabled, defaultValue: true);
    return _habitCompletionSoundEnabled!;
  }

  Future<bool> _isTimerControlSoundEnabled() async {
    if (!await _isSoundEnabled()) return false;
    _timerControlSoundEnabled ??= await _getBoolSetting(SettingKeys.timerControlSoundEnabled, defaultValue: true);
    return _timerControlSoundEnabled!;
  }

  Future<bool> _isTimerAlarmSoundEnabled() async {
    if (!await _isSoundEnabled()) return false;
    _timerAlarmSoundEnabled ??= await _getBoolSetting(SettingKeys.timerAlarmSoundEnabled, defaultValue: true);
    return _timerAlarmSoundEnabled!;
  }

  /// Helper method to get boolean setting values
  Future<bool> _getBoolSetting(String key, {required bool defaultValue}) async {
    try {
      final setting = await _settingRepository.getByKey(key);
      return setting?.getValue<bool>() ?? defaultValue;
    } catch (e) {
      Logger.error('Failed to get setting "$key": $e');
      // If there's an error accessing the setting, return the default value
      return defaultValue;
    }
  }

  /// Helper method to get ticking volume setting
  Future<double> _getTickingVolume() async {
    try {
      final setting = await _settingRepository.getByKey(SettingKeys.tickingVolume);
      final volume = setting?.getValue<int>() ?? 50; // Default to 50%
      return volume / 100.0; // Convert to 0.0-1.0 range
    } catch (e) {
      Logger.error('Failed to get ticking volume setting: $e');
      return 0.5; // Default to 50% if there's an error
    }
  }

  /// Helper method to get ticking enabled setting with caching
  Future<bool> _isTickingEnabled() async {
    _tickingEnabled ??= await _getBoolSetting(SettingKeys.tickingEnabled, defaultValue: false);
    return _tickingEnabled!;
  }

  /// Helper method to play timer sound with proper audio focus
  Future<void> _playTimerSoundWithAudioFocus(String soundPath, {double? volume}) async {
    // Ticking sounds should not interrupt other audio playback (like music or podcasts)
    if (volume != null) {
      _soundPlayer.play(soundPath, volume: volume, requestAudioFocus: false);
    } else {
      _soundPlayer.play(soundPath, requestAudioFocus: false);
    }
  }

  /// Clear cached settings - useful when settings are changed
  @override
  void clearSettingsCache() {
    _soundEnabled = null;
    _taskCompletionSoundEnabled = null;
    _habitCompletionSoundEnabled = null;
    _timerControlSoundEnabled = null;
    _timerAlarmSoundEnabled = null;
    _tickingEnabled = null;
  }

  @override
  Future<void> playTaskCompletion() async {
    if (await _isTaskCompletionSoundEnabled()) {
      _soundPlayer.play(SharedSounds.done);
    }
  }

  @override
  Future<void> playHabitCompletion() async {
    if (await _isHabitCompletionSoundEnabled()) {
      _soundPlayer.play(SharedSounds.done);
    }
  }

  @override
  Future<void> playTimerControl() async {
    if (await _isTimerControlSoundEnabled()) {
      _soundPlayer.play(SharedSounds.button);
    }
  }

  @override
  Future<void> playTimerAlarm() async {
    if (await _isTimerAlarmSoundEnabled()) {
      _soundPlayer.play(SharedSounds.alarmDone);
    }
  }

  @override
  Future<void> playTimerAlarmLoop() async {
    if (await _isTimerAlarmSoundEnabled()) {
      _soundPlayer.setLoop(true);
      _soundPlayer.play(SharedSounds.alarmDone);
    }
  }

  @override
  Future<void> stopTimerAlarmLoop() async {
    _soundPlayer.setLoop(false);
    _soundPlayer.stop();
  }

  @override
  Future<void> stopAll() async {
    _soundPlayer.stop();
  }

  @override
  Future<void> setLoop(bool loop) async {
    _soundPlayer.setLoop(loop);
  }

  @override
  Future<void> playTimerTick() async {
    if (await _isTimerControlSoundEnabled() && await _isTickingEnabled()) {
      final volume = await _getTickingVolume();
      _playTimerSoundWithAudioFocus(TaskSounds.clockTick, volume: volume);
    }
  }

  @override
  Future<void> playTimerTock() async {
    if (await _isTimerControlSoundEnabled() && await _isTickingEnabled()) {
      final volume = await _getTickingVolume();
      _playTimerSoundWithAudioFocus(TaskSounds.clockTock, volume: volume);
    }
  }
}
