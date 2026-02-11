import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

class HabitReverseDayOrderSetting extends StatefulWidget {
  final bool initialValue;
  final VoidCallback? onSettingsChanged;

  const HabitReverseDayOrderSetting({
    super.key,
    this.initialValue = false,
    this.onSettingsChanged,
  });

  @override
  State<HabitReverseDayOrderSetting> createState() => _HabitReverseDayOrderSettingState();
}

class _HabitReverseDayOrderSettingState extends State<HabitReverseDayOrderSetting> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();

  late bool _isSettingEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isSettingEnabled = widget.initialValue;
  }

  @override
  void didUpdateWidget(HabitReverseDayOrderSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setState(() {
        _isSettingEnabled = widget.initialValue;
      });
    }
  }

  Future<void> _saveSetting(bool value) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _isSettingEnabled = value;
    });

    try {
      await _mediator.send(
        SaveSettingCommand(
          key: SettingKeys.habitReverseDayOrder,
          value: value.toString(),
          valueType: SettingValueType.bool,
        ),
      );
      _habitsService.notifySettingsChanged();
      widget.onSettingsChanged?.call();
    } catch (error, stackTrace) {
      if (mounted) {
        DomainLogger.error('Failed to save habit reverse day order setting: $error\n$stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translationService.translate('settings.habit.save_error')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        // Revert to the initial value on error to avoid a misleading UI state.
        setState(() {
          _isSettingEnabled = widget.initialValue;
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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StyledIcon(
              Icons.swap_horiz,
              isActive: _isSettingEnabled,
            ),
            const SizedBox(width: AppTheme.sizeMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _translationService.translate(SettingsTranslationKeys.habitReverseDayOrderTitle),
                    style: AppTheme.labelLarge,
                  ),
                  const SizedBox(height: AppTheme.sizeSmall),
                  Text(
                    _translationService.translate(SettingsTranslationKeys.habitReverseDayOrderDescription),
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: _isSettingEnabled,
              onChanged: _saveSetting,
            ),
          ],
        ),
      ),
    );
  }
}
