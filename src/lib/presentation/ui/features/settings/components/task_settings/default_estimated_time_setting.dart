import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:acore/components/numeric_input/numeric_input.dart';
import 'package:acore/components/numeric_input/numeric_input_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

class DefaultEstimatedTimeSetting extends StatefulWidget {
  final int? initialValue;
  final VoidCallback? onSettingsChanged;

  const DefaultEstimatedTimeSetting({
    super.key,
    this.initialValue,
    this.onSettingsChanged,
  });

  @override
  State<DefaultEstimatedTimeSetting> createState() => _DefaultEstimatedTimeSettingState();
}

class _DefaultEstimatedTimeSettingState extends State<DefaultEstimatedTimeSetting> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  late int? _defaultEstimatedTime;
  late bool _isSettingEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _defaultEstimatedTime = widget.initialValue;
    _isSettingEnabled = _defaultEstimatedTime != null && _defaultEstimatedTime! > 0;
  }

  @override
  void didUpdateWidget(DefaultEstimatedTimeSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setState(() {
        _defaultEstimatedTime = widget.initialValue;
        _isSettingEnabled = _defaultEstimatedTime != null && _defaultEstimatedTime! > 0;
      });
    }
  }

  Future<void> _saveDefaultEstimatedTime(int? value) async {
    if (_isSaving) return;

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
      widget.onSettingsChanged?.call();
    } catch (error, stackTrace) {
      if (mounted) {
        Logger.error('Failed to save default estimated time setting: $error\n$stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translationService.translate(SettingsTranslationKeys.taskDefaultEstimatedTimeSaveError)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        // Revert to the initial value on error to avoid a misleading UI state.
        setState(() {
          _defaultEstimatedTime = widget.initialValue;
          _isSettingEnabled = widget.initialValue != null && widget.initialValue! > 0;
        });
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
      setState(() {
        _isSettingEnabled = false;
        _defaultEstimatedTime = 0;
      });
      _saveDefaultEstimatedTime(0);
    } else {
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
        _isSettingEnabled = value > 0;
      });

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

    return Card(
      elevation: 0,
      color: AppTheme.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StyledIcon(
                  Icons.timer_outlined,
                  isActive: _isSettingEnabled,
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _translationService.translate(SettingsTranslationKeys.taskDefaultEstimatedTimeTitle),
                        style: AppTheme.labelLarge,
                      ),
                      const SizedBox(height: AppTheme.sizeSmall),
                      Text(
                        _translationService.translate(SettingsTranslationKeys.taskDefaultEstimatedTimeDescription),
                        style: AppTheme.bodySmall,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NumericInput(
                    initialValue: _defaultEstimatedTime ?? TaskConstants.defaultEstimatedTime,
                    minValue: 5,
                    maxValue: 480,
                    incrementValue: 5,
                    decrementValue: 5,
                    onValueChanged: _onEstimatedTimeChanged,
                    valueSuffix: _translationService.translate(SharedTranslationKeys.minutes),
                    iconSize: 20,
                    iconColor: theme.colorScheme.primary,
                    translations: _getNumericInputTranslations(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
