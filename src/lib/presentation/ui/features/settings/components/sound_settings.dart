import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/core/shared/utils/logger.dart';

class SoundSettings extends StatefulWidget {
  final VoidCallback? onLoaded;

  const SoundSettings({super.key, this.onLoaded});

  @override
  State<SoundSettings> createState() => _SoundSettingsState();
}

class _SoundSettingsState extends State<SoundSettings> {
  final _settingRepository = container.resolve<ISettingRepository>();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
  final _mediator = container.resolve<Mediator>();
  final _soundManagerService = container.resolve<ISoundManagerService>();

  bool _soundEnabled = true;
  bool _taskCompletionSoundEnabled = true;
  bool _habitCompletionSoundEnabled = true;
  bool _timerControlSoundEnabled = true;
  bool _timerAlarmSoundEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSoundSettings();
  }

  Future<void> _loadSoundSettings() async {
    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isLoading = isLoading;
      }),
      errorMessage: _translationService.translate(SettingsTranslationKeys.enableSoundError),
      operation: () async {
        // Load master sound setting
        var setting = await _settingRepository.getByKey(SettingKeys.soundEnabled);
        if (setting == null) {
          // Create default setting if not exists
          await _mediator.send(SaveSettingCommand(
            key: SettingKeys.soundEnabled,
            value: 'true',
            valueType: SettingValueType.bool,
          ));
          _soundEnabled = true;
        } else {
          _soundEnabled = setting.getValue<bool>();
        }

        // Load individual sound settings with defaults
        setting = await _settingRepository.getByKey(SettingKeys.taskCompletionSoundEnabled);
        _taskCompletionSoundEnabled = setting?.getValue<bool>() ?? true;

        setting = await _settingRepository.getByKey(SettingKeys.habitCompletionSoundEnabled);
        _habitCompletionSoundEnabled = setting?.getValue<bool>() ?? true;

        setting = await _settingRepository.getByKey(SettingKeys.timerControlSoundEnabled);
        _timerControlSoundEnabled = setting?.getValue<bool>() ?? true;

        setting = await _settingRepository.getByKey(SettingKeys.timerAlarmSoundEnabled);
        _timerAlarmSoundEnabled = setting?.getValue<bool>() ?? true;

        // Auto-disable master sound if all individual sounds are disabled
        // This is now handled by optimistic UI updates and background save

        return true;
      },
      onSuccess: (_) {
        widget.onLoaded?.call();
      },
      onError: (e) {
        Logger.error('Error loading sound settings: $e');
        widget.onLoaded?.call();
      },
    );
  }

  void _applyMasterSlaveRulesForSubSettingChange(String changedKey, bool newValue, bool oldValue) {
    // Apply Rule 1: If any sub-setting is enabled, enable master sound
    if (newValue) {
      _soundEnabled = true;
    }

    // Apply Rule 2: If all sub-settings are now disabled, disable master sound
    if (!newValue && changedKey != SettingKeys.soundEnabled) {
      final allOtherSubSettingsDisabled = [
        if (changedKey != SettingKeys.taskCompletionSoundEnabled) _taskCompletionSoundEnabled,
        if (changedKey != SettingKeys.habitCompletionSoundEnabled) _habitCompletionSoundEnabled,
        if (changedKey != SettingKeys.timerControlSoundEnabled) _timerControlSoundEnabled,
        if (changedKey != SettingKeys.timerAlarmSoundEnabled) _timerAlarmSoundEnabled,
      ].every((enabled) => !enabled);

      if (allOtherSubSettingsDisabled) {
        _soundEnabled = false;
      }
    }
  }

  Future<void> _saveSoundSettingBackground(String key, bool value) async {
    // Background save without blocking UI - no loading indicators
    try {
      // Save the primary setting first
      await _mediator.send(SaveSettingCommand(
        key: key,
        value: value.toString(),
        valueType: SettingValueType.bool,
      ));

      // Rule 3 & 4: Handle master sound changes
      if (key == SettingKeys.soundEnabled) {
        if (value) {
          // Rule 3: If user enable general sound setting, enable all sub sound settings
          await Future.wait([
            _mediator.send(SaveSettingCommand(
              key: SettingKeys.taskCompletionSoundEnabled,
              value: 'true',
              valueType: SettingValueType.bool,
            )),
            _mediator.send(SaveSettingCommand(
              key: SettingKeys.habitCompletionSoundEnabled,
              value: 'true',
              valueType: SettingValueType.bool,
            )),
            _mediator.send(SaveSettingCommand(
              key: SettingKeys.timerControlSoundEnabled,
              value: 'true',
              valueType: SettingValueType.bool,
            )),
            _mediator.send(SaveSettingCommand(
              key: SettingKeys.timerAlarmSoundEnabled,
              value: 'true',
              valueType: SettingValueType.bool,
            )),
          ]);
        } else {
          // Rule 4: If user disable general sound setting, disable all sub sound settings
          await Future.wait([
            _mediator.send(SaveSettingCommand(
              key: SettingKeys.taskCompletionSoundEnabled,
              value: 'false',
              valueType: SettingValueType.bool,
            )),
            _mediator.send(SaveSettingCommand(
              key: SettingKeys.habitCompletionSoundEnabled,
              value: 'false',
              valueType: SettingValueType.bool,
            )),
            _mediator.send(SaveSettingCommand(
              key: SettingKeys.timerControlSoundEnabled,
              value: 'false',
              valueType: SettingValueType.bool,
            )),
            _mediator.send(SaveSettingCommand(
              key: SettingKeys.timerAlarmSoundEnabled,
              value: 'false',
              valueType: SettingValueType.bool,
            )),
          ]);
        }
      }

      // Rule 2: If this was a sub-setting being disabled and all others are disabled, disable master sound in database
      if ((key == SettingKeys.taskCompletionSoundEnabled ||
              key == SettingKeys.habitCompletionSoundEnabled ||
              key == SettingKeys.timerControlSoundEnabled ||
              key == SettingKeys.timerAlarmSoundEnabled) &&
          !value) {
        final allOtherSubSettingsDisabled = [
          if (key != SettingKeys.taskCompletionSoundEnabled) _taskCompletionSoundEnabled else false,
          if (key != SettingKeys.habitCompletionSoundEnabled) _habitCompletionSoundEnabled else false,
          if (key != SettingKeys.timerControlSoundEnabled) _timerControlSoundEnabled else false,
          if (key != SettingKeys.timerAlarmSoundEnabled) _timerAlarmSoundEnabled else false,
        ].every((enabled) => !enabled);

        if (allOtherSubSettingsDisabled) {
          await _mediator.send(SaveSettingCommand(
            key: SettingKeys.soundEnabled,
            value: 'false',
            valueType: SettingValueType.bool,
          ));
        }
      }

      // Clear sound manager cache when settings change
      _soundManagerService.clearSettingsCache();

      // Only reload settings if there might be a data consistency issue
      // after a delay to avoid race conditions with rapid interactions
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadSoundSettings();
        }
      });
    } catch (e) {
      Logger.error('Error saving sound setting in background: $e');
      // Optionally revert optimistic UI changes here if needed
    }
  }

  void _showSoundModal() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(_translationService.translate(SettingsTranslationKeys.soundTitle)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16.0,
              children: [
                // Master sound toggle
                SwitchListTile(
                  title: Text(_translationService.translate(SettingsTranslationKeys.soundEnabled)),
                  subtitle: Text(_translationService.translate(SettingsTranslationKeys.soundSubtitle)),
                  value: _soundEnabled,
                  onChanged: (value) {
                    // Optimistic UI update - update both states immediately
                    setDialogState(() {
                      _soundEnabled = value;
                      // Show immediate visual feedback for Rule 3 & 4
                      if (value) {
                        _taskCompletionSoundEnabled = true;
                        _habitCompletionSoundEnabled = true;
                        _timerControlSoundEnabled = true;
                        _timerAlarmSoundEnabled = true;
                      } else {
                        _taskCompletionSoundEnabled = false;
                        _habitCompletionSoundEnabled = false;
                        _timerControlSoundEnabled = false;
                        _timerAlarmSoundEnabled = false;
                      }
                    });
                    setState(() {
                      _soundEnabled = value;
                      if (value) {
                        _taskCompletionSoundEnabled = true;
                        _habitCompletionSoundEnabled = true;
                        _timerControlSoundEnabled = true;
                        _timerAlarmSoundEnabled = true;
                      } else {
                        _taskCompletionSoundEnabled = false;
                        _habitCompletionSoundEnabled = false;
                        _timerControlSoundEnabled = false;
                        _timerAlarmSoundEnabled = false;
                      }
                    });
                    // Save in background without blocking UI
                    _saveSoundSettingBackground(SettingKeys.soundEnabled, value);
                  },
                ),
                const Divider(),
                // Individual sound toggles with optimistic updates and background saving
                SwitchListTile(
                  title: Text(_translationService.translate(SettingsTranslationKeys.taskCompletionSound)),
                  value: _taskCompletionSoundEnabled,
                  onChanged: (value) {
                    // Optimistic UI update - immediate visual feedback
                    final oldTaskCompletionState = _taskCompletionSoundEnabled;
                    setDialogState(() {
                      _taskCompletionSoundEnabled = value;
                      // Apply master-slave rules immediately
                      _applyMasterSlaveRulesForSubSettingChange(
                          SettingKeys.taskCompletionSoundEnabled, value, oldTaskCompletionState);
                    });
                    setState(() {
                      _taskCompletionSoundEnabled = value;
                      // Apply master-slave rules immediately
                      _applyMasterSlaveRulesForSubSettingChange(
                          SettingKeys.taskCompletionSoundEnabled, value, oldTaskCompletionState);
                    });
                    // Save in background without blocking UI
                    _saveSoundSettingBackground(SettingKeys.taskCompletionSoundEnabled, value);
                  },
                ),
                SwitchListTile(
                  title: Text(_translationService.translate(SettingsTranslationKeys.habitCompletionSound)),
                  value: _habitCompletionSoundEnabled,
                  onChanged: (value) {
                    // Optimistic UI update - immediate visual feedback
                    final oldHabitCompletionState = _habitCompletionSoundEnabled;
                    setDialogState(() {
                      _habitCompletionSoundEnabled = value;
                      // Apply master-slave rules immediately
                      _applyMasterSlaveRulesForSubSettingChange(
                          SettingKeys.habitCompletionSoundEnabled, value, oldHabitCompletionState);
                    });
                    setState(() {
                      _habitCompletionSoundEnabled = value;
                      // Apply master-slave rules immediately
                      _applyMasterSlaveRulesForSubSettingChange(
                          SettingKeys.habitCompletionSoundEnabled, value, oldHabitCompletionState);
                    });
                    // Save in background without blocking UI
                    _saveSoundSettingBackground(SettingKeys.habitCompletionSoundEnabled, value);
                  },
                ),
                SwitchListTile(
                  title: Text(_translationService.translate(SettingsTranslationKeys.timerControlSound)),
                  value: _timerControlSoundEnabled,
                  onChanged: (value) {
                    // Optimistic UI update - immediate visual feedback
                    final oldTimerControlState = _timerControlSoundEnabled;
                    setDialogState(() {
                      _timerControlSoundEnabled = value;
                      // Apply master-slave rules immediately
                      _applyMasterSlaveRulesForSubSettingChange(
                          SettingKeys.timerControlSoundEnabled, value, oldTimerControlState);
                    });
                    setState(() {
                      _timerControlSoundEnabled = value;
                      // Apply master-slave rules immediately
                      _applyMasterSlaveRulesForSubSettingChange(
                          SettingKeys.timerControlSoundEnabled, value, oldTimerControlState);
                    });
                    // Save in background without blocking UI
                    _saveSoundSettingBackground(SettingKeys.timerControlSoundEnabled, value);
                  },
                ),
                SwitchListTile(
                  title: Text(_translationService.translate(SettingsTranslationKeys.timerAlarmSound)),
                  value: _timerAlarmSoundEnabled,
                  onChanged: (value) {
                    // Optimistic UI update - immediate visual feedback
                    final oldTimerAlarmState = _timerAlarmSoundEnabled;
                    setDialogState(() {
                      _timerAlarmSoundEnabled = value;
                      // Apply master-slave rules immediately
                      _applyMasterSlaveRulesForSubSettingChange(
                          SettingKeys.timerAlarmSoundEnabled, value, oldTimerAlarmState);
                    });
                    setState(() {
                      _timerAlarmSoundEnabled = value;
                      // Apply master-slave rules immediately
                      _applyMasterSlaveRulesForSubSettingChange(
                          SettingKeys.timerAlarmSoundEnabled, value, oldTimerAlarmState);
                    });
                    // Save in background without blocking UI
                    _saveSoundSettingBackground(SettingKeys.timerAlarmSoundEnabled, value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Reload settings to reflect changes in the main tile
                  _loadSoundSettings();
                },
                child: Text(_translationService.translate(SharedTranslationKeys.closeButton)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getSoundDescription() {
    if (!_soundEnabled) {
      return _translationService.translate(SettingsTranslationKeys.soundsDisabled);
    }

    final enabledCount = [
      _taskCompletionSoundEnabled,
      _habitCompletionSoundEnabled,
      _timerControlSoundEnabled,
      _timerAlarmSoundEnabled
    ].where((enabled) => enabled).length;

    if (enabledCount == 0) {
      return _translationService.translate(SettingsTranslationKeys.soundsDisabled);
    } else if (enabledCount == 4) {
      return _translationService.translate(SettingsTranslationKeys.allSoundsEnabled);
    } else {
      return _translationService.translate(SettingsTranslationKeys.someSoundsEnabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _themeService.themeChanges,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        return Card(
          child: ListTile(
            leading: Icon(
              Icons.volume_up,
              color: theme.colorScheme.onSurface,
            ),
            title: Text(
              _translationService.translate(SettingsTranslationKeys.soundTitle),
              style: AppTheme.bodyMedium,
            ),
            subtitle: _isLoading
                ? null
                : Text(
                    _getSoundDescription(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
            trailing: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isLoading ? null : _showSoundModal,
          ),
        );
      },
    );
  }
}
