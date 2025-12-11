import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:acore/components/numeric_input/numeric_input.dart';
import 'package:acore/components/numeric_input/numeric_input_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

class TaskSettings extends StatefulWidget {
  final VoidCallback? onLoaded;

  const TaskSettings({
    super.key,
    this.onLoaded,
  });

  @override
  State<TaskSettings> createState() => _TaskSettingsState();
}

class _TaskSettingsState extends State<TaskSettings> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  bool _isLoading = true;
  int? _defaultEstimatedTime;
  bool _isSettingEnabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isLoading = isLoading;
      }),
      errorMessage: _translationService.translate(SettingsTranslationKeys.taskDefaultEstimatedTimeLoadError),
      operation: () async {
        try {
          final setting = await _mediator.send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.taskDefaultEstimatedTime),
          );

          if (setting != null) {
            final value = setting.getValue<int?>();
            setState(() {
              _defaultEstimatedTime = value;
              _isSettingEnabled = value != null && value > 0;
            });
          } else {
            // Default to TaskConstants.defaultEstimatedTime minutes if setting doesn't exist
            setState(() {
              _defaultEstimatedTime = TaskConstants.defaultEstimatedTime;
              _isSettingEnabled = true;
            });
            // Create the setting with default value
            await _saveDefaultEstimatedTime(TaskConstants.defaultEstimatedTime);
          }
          return true;
        } catch (e, s) {
          // Don't show overlay notification for missing setting key - just use default
          Logger.error('Failed to load default estimated time setting: $e\n$s');
          // Set default values anyway
          setState(() {
            _defaultEstimatedTime = TaskConstants.defaultEstimatedTime;
            _isSettingEnabled = true;
          });
          return true;
        }
      },
      onSuccess: (_) {
        widget.onLoaded?.call();
      },
    );
  }

  Future<void> _saveDefaultEstimatedTime(int? value) async {
    if (_isSaving) return; // Prevent concurrent saves

    setState(() {
      _isSaving = true;
    });

    try {
      await _mediator.send(
        SaveSettingCommand(
          key: SettingKeys.taskDefaultEstimatedTime,
          value: value?.toString() ?? '0',
          valueType: SettingValueType.int,
        ),
      );
    } catch (error, stackTrace) {
      // Show error message without reverting all settings
      if (mounted) {
        Logger.error('Failed to save default estimated time setting: $error\n$stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translationService.translate(SettingsTranslationKeys.taskDefaultEstimatedTimeSaveError)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        // Revert only the changed value to previous state
        _loadSettings();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _onToggleChanged(bool enabled) {
    if (!enabled) {
      // Disable the setting by setting value to 0
      setState(() {
        _isSettingEnabled = false;
        _defaultEstimatedTime = 0;
      });
      _saveDefaultEstimatedTime(0);
    } else {
      // Enable with a default of TaskConstants.defaultEstimatedTime minutes
      setState(() {
        _isSettingEnabled = true;
        _defaultEstimatedTime = TaskConstants.defaultEstimatedTime;
      });
      _saveDefaultEstimatedTime(TaskConstants.defaultEstimatedTime);
    }
  }

  void _onEstimatedTimeChanged(int value) {
    if (value != _defaultEstimatedTime) {
      setState(() {
        _defaultEstimatedTime = value;
        // Enable setting if value is greater than 0
        _isSettingEnabled = value > 0;
      });
      // Debounce save operation to avoid excessive saves while user is adjusting
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isSaving && value == _defaultEstimatedTime) {
          _saveDefaultEstimatedTime(value);
        }
      });
    }
  }

  Map<NumericInputTranslationKey, String> _getNumericInputTranslations() {
    return NumericInputTranslationKey.values.asMap().map(
          (key, value) =>
              MapEntry(value, _translationService.translate(SharedTranslationKeys.mapNumericInputKey(value))),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeSmall),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.sizeLarge),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeSmall),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.sizeSmall),
                Text(
                  _translationService.translate(SettingsTranslationKeys.taskSettingsTitle),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeMedium),

            // Default Estimated Time Setting
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle and Title
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _translationService.translate(SettingsTranslationKeys.taskDefaultEstimatedTimeTitle),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppTheme.sizeSmall),
                          Text(
                            _translationService.translate(SettingsTranslationKeys.taskDefaultEstimatedTimeDescription),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isSettingEnabled,
                      onChanged: _onToggleChanged,
                    ),
                  ],
                ),

                if (_isSettingEnabled) ...[
                  const SizedBox(height: AppTheme.sizeMedium),

                  // Numeric Input
                  Row(
                    children: [
                      Expanded(
                        child: NumericInput(
                          initialValue: _defaultEstimatedTime ?? TaskConstants.defaultEstimatedTime,
                          minValue: 5,
                          maxValue: 480, // Increased from 60 to 480 minutes (8 hours) for better usability
                          incrementValue: 5,
                          decrementValue: 5,
                          onValueChanged: _onEstimatedTimeChanged,
                          valueSuffix: _translationService.translate(SharedTranslationKeys.minutes),
                          iconSize: 20,
                          iconColor: theme.colorScheme.primary,
                          translations: _getNumericInputTranslations(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
