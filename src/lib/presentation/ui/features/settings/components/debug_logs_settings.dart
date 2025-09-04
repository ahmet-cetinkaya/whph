import 'package:flutter/material.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/shared/services/abstraction/i_logger_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/components/debug_logs_dialog.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:mediatr/mediatr.dart';

class DebugLogsSettings extends StatefulWidget {
  const DebugLogsSettings({super.key});

  @override
  State<DebugLogsSettings> createState() => _DebugLogsSettingsState();
}

class _DebugLogsSettingsState extends State<DebugLogsSettings> {
  final _mediator = container.resolve<Mediator>();
  final _loggerService = container.resolve<ILoggerService>();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadDebugLogsSetting();
  }

  Future<void> _loadDebugLogsSetting() async {
    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isLoading = isLoading;
      }),
      errorMessage: _translationService.translate(SettingsTranslationKeys.debugLogsLoadSettingsError),
      operation: () async {
        try {
          final query = GetSettingQuery(key: SettingKeys.debugLogsEnabled);
          final response = await _mediator.send(query) as GetSettingQueryResponse?;
          _isEnabled = response?.getValue<bool>() ?? false;
        } catch (e) {
          // Setting doesn't exist yet, use default (false)
          _isEnabled = false;
        }
        return true;
      },
    );
  }

  Future<void> _toggleDebugLogs(bool value) async {
    if (_isUpdating) return;

    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isUpdating = isLoading;
      }),
      errorMessage: _translationService.translate(SettingsTranslationKeys.debugLogsUpdateSettingsError),
      operation: () async {
        final command = SaveSettingCommand(
          key: SettingKeys.debugLogsEnabled,
          value: value.toString(),
          valueType: SettingValueType.bool,
        );
        await _mediator.send(command);

        // Reconfigure the logger with new setting
        await _loggerService.configureLogger();

        return true;
      },
      onSuccess: (_) async {
        setState(() {
          _isEnabled = value;
        });
      },
    );
  }

  void _showDebugLogsDialog(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const DebugLogsDialog(),
      size: DialogSize.large,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _themeService.themeChanges,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        return Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.bug_report,
                  color: theme.colorScheme.onSurface,
                ),
                title: Text(
                  _translationService.translate(SettingsTranslationKeys.debugLogsTitle),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  _translationService.translate(SettingsTranslationKeys.debugLogsDescription),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                trailing: _isLoading || _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: _isEnabled,
                        onChanged: _toggleDebugLogs,
                        activeColor: theme.colorScheme.primary,
                      ),
                onTap: () => _isLoading || _isUpdating ? null : _toggleDebugLogs(!_isEnabled),
              ),
              if (_isEnabled)
                ListTile(
                  leading: Icon(
                    Icons.description,
                    color: theme.colorScheme.onSurface,
                  ),
                  title: Text(
                    _translationService.translate(SettingsTranslationKeys.viewLogsTitle),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    _translationService.translate(SettingsTranslationKeys.viewLogsDescription),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 16,
                  ),
                  onTap: () => _showDebugLogsDialog(context),
                ),
            ],
          ),
        );
      },
    );
  }
}
