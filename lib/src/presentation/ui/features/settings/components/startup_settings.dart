import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

class StartupSettings extends StatefulWidget {
  static bool get compatiblePlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux || Platform.isAndroid;

  const StartupSettings({super.key});

  @override
  State<StartupSettings> createState() => _StartupSettingsState();
}

class _StartupSettingsState extends State<StartupSettings> {
  final _startupService = container.resolve<IStartupSettingsService>();
  final _translationService = container.resolve<ITranslationService>();
  get _isSystemSettingNeeded => Platform.isAndroid;

  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadStartupSetting();
  }

  Future<void> _loadStartupSetting() async {
    if (!StartupSettings.compatiblePlatform) return;

    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isLoading = isLoading;
      }),
      errorMessage: "Error loading startup settings",
      operation: () async {
        final isEnabled = await _startupService.isEnabledAtStartup();
        setState(() {
          _isEnabled = isEnabled;
        });
        return true;
      },
      onError: (e) {
        Logger.error('Error loading startup setting: $e');
      },
    );
  }

  Future<void> _toggleStartupSetting(bool value) async {
    if (_isUpdating) return;

    // Only need to manage loading state manually if not using system settings
    if (!_isSystemSettingNeeded) {
      await AsyncErrorHandler.executeWithLoading(
        context: context,
        setLoading: (isLoading) => setState(() {
          _isUpdating = isLoading;
        }),
        errorMessage: _translationService.translate(
            value ? SettingsTranslationKeys.enableStartupError : SettingsTranslationKeys.disableStartupError),
        operation: () async {
          if (value) {
            await _startupService.enableStartAtStartup();
          } else {
            await _startupService.disableStartAtStartup();
          }
          return true;
        },
        onSuccess: (_) async {
          await _loadStartupSetting();
        },
      );
    } else {
      // For Android, we don't need to manage loading state because it redirects to system settings
      await AsyncErrorHandler.executeVoid(
        context: context,
        errorMessage: _translationService.translate(
            value ? SettingsTranslationKeys.enableStartupError : SettingsTranslationKeys.disableStartupError),
        operation: () async {
          if (value) {
            await _startupService.enableStartAtStartup();
          } else {
            await _startupService.disableStartAtStartup();
          }
        },
        onSuccess: () async {
          await _loadStartupSetting();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!StartupSettings.compatiblePlatform) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.launch),
        title: Text(
          _translationService.translate(SettingsTranslationKeys.startupTitle),
          style: AppTheme.bodyMedium,
        ),
        subtitle: Platform.isAndroid
            ? Text(
                _translationService.translate(SettingsTranslationKeys.startupSubtitle),
                style: AppTheme.bodySmall,
              )
            : null,
        trailing: Platform.isAndroid
            ? const Icon(Icons.arrow_forward_ios, size: AppTheme.fontSizeLarge)
            : _isLoading || _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: _isEnabled,
                    onChanged: _toggleStartupSetting,
                  ),
        onTap: () => _toggleStartupSetting(!_isEnabled),
      ),
    );
  }
}
