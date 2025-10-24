import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/corePackages/acore/lib/components/numeric_input.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';

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
            // Default to 15 minutes if setting doesn't exist
            setState(() {
              _defaultEstimatedTime = 15;
              _isSettingEnabled = true;
            });
            // Create the setting with default value
            await _saveDefaultEstimatedTime(15);
          }
          return true;
        } catch (e) {
          // Don't show overlay notification for missing setting key - just use default
          // Set default values anyway
          setState(() {
            _defaultEstimatedTime = 15;
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
    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) {
        // Show loading indicator if needed
      },
      errorMessage: _translationService.translate(SettingsTranslationKeys.taskDefaultEstimatedTimeSaveError),
      operation: () async {
        await _mediator.send(
          SaveSettingCommand(
            key: SettingKeys.taskDefaultEstimatedTime,
            value: value?.toString() ?? '0',
            valueType: SettingValueType.int,
          ),
        );
        return true;
      },
      onError: (error) {
        // Don't show overlay notification for setting key errors - just revert change
        // Revert change on error
        _loadSettings();
      },
    );
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
      // Enable with a default of 15 minutes
      setState(() {
        _isSettingEnabled = true;
        _defaultEstimatedTime = 15;
      });
      _saveDefaultEstimatedTime(15);
    }
  }

  void _onEstimatedTimeChanged(int value) {
    if (value != _defaultEstimatedTime) {
      setState(() {
        _defaultEstimatedTime = value;
      });
      _saveDefaultEstimatedTime(value);
    }
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
                          initialValue: _defaultEstimatedTime ?? 15,
                          minValue: 5,
                          maxValue: 60,
                          incrementValue: 5,
                          decrementValue: 5,
                          onValueChanged: _onEstimatedTimeChanged,
                          valueSuffix: _translationService.translate(SharedTranslationKeys.minutes),
                          iconSize: 20,
                          iconColor: theme.colorScheme.primary,
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
