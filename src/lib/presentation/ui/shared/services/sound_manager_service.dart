import 'package:acore/acore.dart';
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
      // If there's an error accessing the setting, return the default value
      return defaultValue;
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
  }

  @override
  void playTaskCompletion() async {
    if (await _isTaskCompletionSoundEnabled()) {
      _soundPlayer.play(SharedSounds.done);
    }
  }

  @override
  void playHabitCompletion() async {
    if (await _isHabitCompletionSoundEnabled()) {
      _soundPlayer.play(SharedSounds.done);
    }
  }

  @override
  void playTimerControl() async {
    if (await _isTimerControlSoundEnabled()) {
      _soundPlayer.play(SharedSounds.button);
    }
  }

  @override
  void playTimerAlarm() async {
    if (await _isTimerAlarmSoundEnabled()) {
      _soundPlayer.play(SharedSounds.alarmDone);
    }
  }

  @override
  void playTimerTick() async {
    if (await _isTimerAlarmSoundEnabled()) {
      _soundPlayer.play(TaskSounds.clockTick);
    }
  }

  @override
  void playTimerTock() async {
    if (await _isTimerAlarmSoundEnabled()) {
      _soundPlayer.play(TaskSounds.clockTock);
    }
  }
}
