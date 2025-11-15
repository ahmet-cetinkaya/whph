import 'dart:async';
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
  // Sub-setting keys for easier maintenance
  static const Set<String> _subSettingKeys = {
    SettingKeys.taskCompletionSoundEnabled,
    SettingKeys.habitCompletionSoundEnabled,
    SettingKeys.timerControlSoundEnabled,
    SettingKeys.timerAlarmSoundEnabled,
  };

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
  bool _isSaving = false;

  // Debouncing for rapid interactions
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSoundSettings();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
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

  void _applyMasterSlaveRulesForSubSettingChange(String changedKey, bool newValue) {
    // Only apply to sub-settings, not master setting
    if (!_subSettingKeys.contains(changedKey)) return;

    // Rule 1: If any sub-setting is enabled, enable master sound
    if (newValue) {
      _soundEnabled = true;
      return;
    }

    // Rule 2: If this sub-setting is being disabled, check if all are now disabled
    final allSubSettingsDisabled = !_taskCompletionSoundEnabled &&
        !_habitCompletionSoundEnabled &&
        !_timerControlSoundEnabled &&
        !_timerAlarmSoundEnabled;

    if (allSubSettingsDisabled) {
      _soundEnabled = false;
    }
  }

  Future<void> _saveAllSoundSettingsWithDebounce() async {
    // Cancel existing debounce timer
    _debounceTimer?.cancel();

    // Create new debounce timer - wait 300ms before saving
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_isSaving) return; // Skip if already saving

      _isSaving = true;

      try {
        // The UI state is the source of truth. Save all settings based on the current state.
        await Future.wait([
          _mediator.send(SaveSettingCommand(
            key: SettingKeys.soundEnabled,
            value: _soundEnabled.toString(),
            valueType: SettingValueType.bool,
          )),
          _mediator.send(SaveSettingCommand(
            key: SettingKeys.taskCompletionSoundEnabled,
            value: _taskCompletionSoundEnabled.toString(),
            valueType: SettingValueType.bool,
          )),
          _mediator.send(SaveSettingCommand(
            key: SettingKeys.habitCompletionSoundEnabled,
            value: _habitCompletionSoundEnabled.toString(),
            valueType: SettingValueType.bool,
          )),
          _mediator.send(SaveSettingCommand(
            key: SettingKeys.timerControlSoundEnabled,
            value: _timerControlSoundEnabled.toString(),
            valueType: SettingValueType.bool,
          )),
          _mediator.send(SaveSettingCommand(
            key: SettingKeys.timerAlarmSoundEnabled,
            value: _timerAlarmSoundEnabled.toString(),
            valueType: SettingValueType.bool,
          )),
        ]);

        // Clear sound manager cache when settings change
        _soundManagerService.clearSettingsCache();
      } catch (e) {
        Logger.error('Error saving sound settings in background: $e');
      } finally {
        _isSaving = false;
      }
    });
  }

  void _handleSubSettingToggle(
      String settingKey, bool value, Function(bool) setStateFunction, void Function(VoidCallback) updateDialogState) {
    // Optimistic UI update - update both states immediately
    void updateState() {
      setStateFunction(value);
      // Apply master-slave rules immediately
      _applyMasterSlaveRulesForSubSettingChange(settingKey, value);
    }

    updateDialogState(updateState);
    setState(updateState);
    // Save all sound settings in background without blocking UI
    _saveAllSoundSettingsWithDebounce();
  }

  void _showSoundModal() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(_translationService.translate(SettingsTranslationKeys.soundTitle)),
            content: SingleChildScrollView(
              child: Column(
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
                      void updateState() {
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
                      }

                      setDialogState(updateState);
                      setState(updateState);
                      // Save all sound settings in background without blocking UI
                      _saveAllSoundSettingsWithDebounce();
                    },
                  ),
                  const Divider(),
                  // Individual sound toggles with optimistic updates and background saving
                  SwitchListTile(
                    title: Text(_translationService.translate(SettingsTranslationKeys.taskCompletionSound)),
                    value: _taskCompletionSoundEnabled,
                    onChanged: (value) {
                      _handleSubSettingToggle(
                        SettingKeys.taskCompletionSoundEnabled,
                        value,
                        (newValue) => _taskCompletionSoundEnabled = newValue,
                        setDialogState,
                      );
                    },
                  ),
                  SwitchListTile(
                    title: Text(_translationService.translate(SettingsTranslationKeys.habitCompletionSound)),
                    value: _habitCompletionSoundEnabled,
                    onChanged: (value) {
                      _handleSubSettingToggle(
                        SettingKeys.habitCompletionSoundEnabled,
                        value,
                        (newValue) => _habitCompletionSoundEnabled = newValue,
                        setDialogState,
                      );
                    },
                  ),
                  SwitchListTile(
                    title: Text(_translationService.translate(SettingsTranslationKeys.timerControlSound)),
                    value: _timerControlSoundEnabled,
                    onChanged: (value) {
                      _handleSubSettingToggle(
                        SettingKeys.timerControlSoundEnabled,
                        value,
                        (newValue) => _timerControlSoundEnabled = newValue,
                        setDialogState,
                      );
                    },
                  ),
                  SwitchListTile(
                    title: Text(_translationService.translate(SettingsTranslationKeys.timerAlarmSound)),
                    value: _timerAlarmSoundEnabled,
                    onChanged: (value) {
                      _handleSubSettingToggle(
                        SettingKeys.timerAlarmSoundEnabled,
                        value,
                        (newValue) => _timerAlarmSoundEnabled = newValue,
                        setDialogState,
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // State is updated optimistically, so no need to reload here.
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
