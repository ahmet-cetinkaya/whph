import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_date_picker_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/utils/reminder_helper.dart';

class DefaultReminderSetting extends StatefulWidget {
  final ReminderTime? initialValue;
  final int? initialCustomOffset;
  final VoidCallback? onSettingsChanged;

  const DefaultReminderSetting({
    super.key,
    this.initialValue,
    this.initialCustomOffset,
    this.onSettingsChanged,
  });

  @override
  State<DefaultReminderSetting> createState() => _DefaultReminderSettingState();
}

class _DefaultReminderSettingState extends State<DefaultReminderSetting> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  late ReminderTime? _defaultPlannedDateReminder;
  late int? _defaultPlannedDateReminderCustomOffset;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _defaultPlannedDateReminder = widget.initialValue;
    _defaultPlannedDateReminderCustomOffset = widget.initialCustomOffset;
  }

  @override
  void didUpdateWidget(DefaultReminderSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue || oldWidget.initialCustomOffset != widget.initialCustomOffset) {
      setState(() {
        _defaultPlannedDateReminder = widget.initialValue;
        _defaultPlannedDateReminderCustomOffset = widget.initialCustomOffset;
      });
    }
  }

  Future<void> _saveDefaultPlannedDateReminder(ReminderTime value, [int? customOffset]) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _defaultPlannedDateReminder = value;
      _defaultPlannedDateReminderCustomOffset = customOffset;
    });

    try {
      if (value == ReminderTime.custom && customOffset != null) {
        await _mediator.send(
          SaveSettingCommand(
            key: SettingKeys.taskDefaultPlannedDateReminderCustomOffset,
            value: customOffset.toString(),
            valueType: SettingValueType.int,
          ),
        );
      }

      await _mediator.send(
        SaveSettingCommand(
          key: SettingKeys.taskDefaultPlannedDateReminder,
          value: value.name,
          valueType: SettingValueType.string,
        ),
      );
      widget.onSettingsChanged?.call();
    } catch (error, stackTrace) {
      if (mounted) {
        DomainLogger.error('Failed to save default planned date reminder setting: $error\n$stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_translationService.translate(SettingsTranslationKeys.taskDefaultPlannedDateReminderSaveError)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        // Revert to the initial value on error to avoid a misleading UI state.
        setState(() {
          _defaultPlannedDateReminder = widget.initialValue;
          _defaultPlannedDateReminderCustomOffset = widget.initialCustomOffset;
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

  String _getReminderText(ReminderTime? reminderTime) {
    return ReminderHelper.getReminderText(
      reminderTime,
      _translationService,
      _defaultPlannedDateReminderCustomOffset,
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
                  Icons.notifications_outlined,
                  isActive: _defaultPlannedDateReminder != null && _defaultPlannedDateReminder != ReminderTime.none,
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _translationService.translate(SettingsTranslationKeys.taskDefaultPlannedDateReminderTitle),
                        style: AppTheme.labelLarge,
                      ),
                      const SizedBox(height: AppTheme.sizeSmall),
                      Text(
                        _translationService
                            .translate(SettingsTranslationKeys.taskDefaultPlannedDateReminderDescription),
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeMedium),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface1,
                borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
              ),
              child: InkWell(
                onTap: () async {
                  final result = await TaskDatePickerDialog.showReminderSelectionDialog(
                    context,
                    _defaultPlannedDateReminder,
                    _translationService,
                    _defaultPlannedDateReminderCustomOffset,
                  );

                  if (result != null) {
                    _saveDefaultPlannedDateReminder(result.reminderTime, result.customOffset);
                  }
                },
                borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.sizeMedium,
                    vertical: AppTheme.sizeMedium,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (_defaultPlannedDateReminder == null || _defaultPlannedDateReminder == ReminderTime.none)
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_active,
                        color: (_defaultPlannedDateReminder == null || _defaultPlannedDateReminder == ReminderTime.none)
                            ? theme.disabledColor
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppTheme.sizeMedium),
                      Expanded(
                        child: Text(
                          _getReminderText(_defaultPlannedDateReminder),
                          style: AppTheme.bodyMedium,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
