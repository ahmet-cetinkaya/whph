import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/settings/commands/save_setting_command.dart';
import 'package:application/features/settings/queries/get_setting_query.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:domain/features/tasks/task_constants.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/features/settings/components/settings_menu_tile.dart';
import 'package:whph/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/shared/constants/setting_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/utils/async_error_handler.dart';

class SkipQuickAddSetting extends StatefulWidget {
  final bool? initialValue;

  const SkipQuickAddSetting({super.key, this.initialValue});

  @override
  State<SkipQuickAddSetting> createState() => _SkipQuickAddSettingState();
}

class _SkipQuickAddSettingState extends State<SkipQuickAddSetting> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  bool? _isEnabled;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _isEnabled = widget.initialValue;
      _isLoading = false;
    } else {
      _loadSetting();
    }
  }

  Future<void> _loadSetting() async {
    try {
      final setting = await _mediator.send<GetSettingQuery, Setting?>(
        GetSettingQuery(key: SettingKeys.taskSkipQuickAdd),
      );

      if (mounted) {
        setState(() {
          if (setting != null) {
            _isEnabled = setting.getValue<bool>();
          } else {
            _isEnabled = TaskConstants.defaultSkipQuickAdd;
          }
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      DomainLogger.error(
        _translationService.translate(SettingsTranslationKeys.taskSkipQuickAddLoadError),
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _isEnabled = TaskConstants.defaultSkipQuickAdd;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onChanged(bool value) async {
    // Optimistic UI update
    final previousValue = _isEnabled;
    setState(() {
      _isEnabled = value;
      _isSaving = true;
    });

    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) {
        if (mounted) {
          setState(() {
            _isSaving = isLoading;
          });
        }
      },
      errorMessage: _translationService.translate(SettingsTranslationKeys.taskSkipQuickAddSaveError),
      operation: () async {
        await _mediator.send<SaveSettingCommand, SaveSettingCommandResponse>(
          SaveSettingCommand(
            key: SettingKeys.taskSkipQuickAdd,
            value: value.toString(),
            valueType: SettingValueType.bool,
          ),
        );
        return true;
      },
      onError: (_) {
        // Revert on error
        if (mounted) {
          setState(() {
            _isEnabled = previousValue;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return SettingsMenuTile(
      icon: Icons.flash_on,
      title: _translationService.translate(SettingsTranslationKeys.taskSkipQuickAddTitle),
      subtitle: _translationService.translate(SettingsTranslationKeys.taskSkipQuickAddDescription),
      isActive: _isEnabled ?? TaskConstants.defaultSkipQuickAdd,
      trailing: Switch(
        value: _isEnabled ?? TaskConstants.defaultSkipQuickAdd,
        onChanged: _isSaving ? null : _onChanged,
        activeColor: theme.colorScheme.primary,
      ),
      onTap: _isSaving ? () {} : () => _onChanged(!(_isEnabled ?? TaskConstants.defaultSkipQuickAdd)),
    );
  }
}
