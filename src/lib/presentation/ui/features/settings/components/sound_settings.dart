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

import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

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

  void _showSoundModal() {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.large,
      child: _SoundDialog(
        soundEnabled: _soundEnabled,
        taskCompletionSoundEnabled: _taskCompletionSoundEnabled,
        habitCompletionSoundEnabled: _habitCompletionSoundEnabled,
        timerControlSoundEnabled: _timerControlSoundEnabled,
        timerAlarmSoundEnabled: _timerAlarmSoundEnabled,
        onSoundEnabledChanged: (value) {
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
          _saveAllSoundSettingsWithDebounce();
        },
        onTaskCompletionSoundChanged: (value) {
          setState(() {
            _taskCompletionSoundEnabled = value;
            _applyMasterSlaveRulesForSubSettingChange(SettingKeys.taskCompletionSoundEnabled, value);
          });
          _saveAllSoundSettingsWithDebounce();
        },
        onHabitCompletionSoundChanged: (value) {
          setState(() {
            _habitCompletionSoundEnabled = value;
            _applyMasterSlaveRulesForSubSettingChange(SettingKeys.habitCompletionSoundEnabled, value);
          });
          _saveAllSoundSettingsWithDebounce();
        },
        onTimerControlSoundChanged: (value) {
          setState(() {
            _timerControlSoundEnabled = value;
            _applyMasterSlaveRulesForSubSettingChange(SettingKeys.timerControlSoundEnabled, value);
          });
          _saveAllSoundSettingsWithDebounce();
        },
        onTimerAlarmSoundChanged: (value) {
          setState(() {
            _timerAlarmSoundEnabled = value;
            _applyMasterSlaveRulesForSubSettingChange(SettingKeys.timerAlarmSoundEnabled, value);
          });
          _saveAllSoundSettingsWithDebounce();
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
        return SettingsMenuTile(
          icon: Icons.volume_up,
          title: _translationService.translate(SettingsTranslationKeys.soundTitle),
          subtitle: _isLoading ? null : _getSoundDescription(),
          trailing: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _isLoading ? () {} : _showSoundModal,
          isActive: true,
        );
      },
    );
  }
}

class _SoundDialog extends StatefulWidget {
  final bool soundEnabled;
  final bool taskCompletionSoundEnabled;
  final bool habitCompletionSoundEnabled;
  final bool timerControlSoundEnabled;
  final bool timerAlarmSoundEnabled;
  final ValueChanged<bool> onSoundEnabledChanged;
  final ValueChanged<bool> onTaskCompletionSoundChanged;
  final ValueChanged<bool> onHabitCompletionSoundChanged;
  final ValueChanged<bool> onTimerControlSoundChanged;
  final ValueChanged<bool> onTimerAlarmSoundChanged;

  const _SoundDialog({
    required this.soundEnabled,
    required this.taskCompletionSoundEnabled,
    required this.habitCompletionSoundEnabled,
    required this.timerControlSoundEnabled,
    required this.timerAlarmSoundEnabled,
    required this.onSoundEnabledChanged,
    required this.onTaskCompletionSoundChanged,
    required this.onHabitCompletionSoundChanged,
    required this.onTimerControlSoundChanged,
    required this.onTimerAlarmSoundChanged,
  });

  @override
  State<_SoundDialog> createState() => _SoundDialogState();
}

class _SoundDialogState extends State<_SoundDialog> {
  final _translationService = container.resolve<ITranslationService>();
  late bool _soundEnabled;
  late bool _taskCompletionSoundEnabled;
  late bool _habitCompletionSoundEnabled;
  late bool _timerControlSoundEnabled;
  late bool _timerAlarmSoundEnabled;

  @override
  void initState() {
    super.initState();
    _soundEnabled = widget.soundEnabled;
    _taskCompletionSoundEnabled = widget.taskCompletionSoundEnabled;
    _habitCompletionSoundEnabled = widget.habitCompletionSoundEnabled;
    _timerControlSoundEnabled = widget.timerControlSoundEnabled;
    _timerAlarmSoundEnabled = widget.timerAlarmSoundEnabled;
  }

  @override
  void didUpdateWidget(_SoundDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.soundEnabled != widget.soundEnabled) {
      _soundEnabled = widget.soundEnabled;
    }
    if (oldWidget.taskCompletionSoundEnabled != widget.taskCompletionSoundEnabled) {
      _taskCompletionSoundEnabled = widget.taskCompletionSoundEnabled;
    }
    if (oldWidget.habitCompletionSoundEnabled != widget.habitCompletionSoundEnabled) {
      _habitCompletionSoundEnabled = widget.habitCompletionSoundEnabled;
    }
    if (oldWidget.timerControlSoundEnabled != widget.timerControlSoundEnabled) {
      _timerControlSoundEnabled = widget.timerControlSoundEnabled;
    }
    if (oldWidget.timerAlarmSoundEnabled != widget.timerAlarmSoundEnabled) {
      _timerAlarmSoundEnabled = widget.timerAlarmSoundEnabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _translationService.translate(SettingsTranslationKeys.soundTitle),
          style: AppTheme.headlineSmall,
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Toggle Card
              Card(
                elevation: 0,
                color: AppTheme.surface1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
                child: SwitchListTile.adaptive(
                  value: _soundEnabled,
                  onChanged: (value) {
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
                    widget.onSoundEnabledChanged(value);
                  },
                  title: Text(
                    _translationService.translate(SettingsTranslationKeys.soundEnabled),
                    style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _translationService.translate(SettingsTranslationKeys.soundSubtitle),
                    style: AppTheme.bodySmall,
                  ),
                  secondary: StyledIcon(
                    _soundEnabled ? Icons.volume_up : Icons.volume_off,
                    isActive: _soundEnabled,
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.sizeLarge),

              // Animated Sub-settings Section
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
                      child: Text(
                        _translationService.translate(SettingsTranslationKeys.soundSettings),
                        style: AppTheme.labelLarge,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface1,
                        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                      ),
                      child: Column(
                        children: [
                          _buildSoundOption(
                            title: _translationService.translate(SettingsTranslationKeys.taskCompletionSound),
                            value: _taskCompletionSoundEnabled,
                            icon: Icons.check_circle_outline,
                            onChanged: (value) {
                              setState(() {
                                _taskCompletionSoundEnabled = value;
                                if (value) _soundEnabled = true;
                              });
                              widget.onTaskCompletionSoundChanged(value);
                            },
                          ),
                          Divider(height: 1, color: theme.dividerColor, indent: 56, endIndent: 16),
                          _buildSoundOption(
                            title: _translationService.translate(SettingsTranslationKeys.habitCompletionSound),
                            value: _habitCompletionSoundEnabled,
                            icon: Icons.repeat,
                            onChanged: (value) {
                              setState(() {
                                _habitCompletionSoundEnabled = value;
                                if (value) _soundEnabled = true;
                              });
                              widget.onHabitCompletionSoundChanged(value);
                            },
                          ),
                          Divider(height: 1, color: theme.dividerColor, indent: 56, endIndent: 16),
                          _buildSoundOption(
                            title: _translationService.translate(SettingsTranslationKeys.timerControlSound),
                            value: _timerControlSoundEnabled,
                            icon: Icons.play_circle_outline,
                            onChanged: (value) {
                              setState(() {
                                _timerControlSoundEnabled = value;
                                if (value) _soundEnabled = true;
                              });
                              widget.onTimerControlSoundChanged(value);
                            },
                          ),
                          Divider(height: 1, color: theme.dividerColor, indent: 56, endIndent: 16),
                          _buildSoundOption(
                            title: _translationService.translate(SettingsTranslationKeys.timerAlarmSound),
                            value: _timerAlarmSoundEnabled,
                            icon: Icons.alarm,
                            onChanged: (value) {
                              setState(() {
                                _timerAlarmSoundEnabled = value;
                                if (value) _soundEnabled = true;
                              });
                              widget.onTimerAlarmSoundChanged(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                crossFadeState: _soundEnabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoundOption({
    required String title,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: AppTheme.bodyMedium,
      ),
      secondary: StyledIcon(
        icon,
        isActive: value,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
    );
  }
}
