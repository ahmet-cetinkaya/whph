import 'package:flutter/material.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;

import 'package:whph/presentation/ui/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';

class StartupSettings extends StatefulWidget {
  final VoidCallback? onLoaded;

  const StartupSettings({super.key, this.onLoaded});

  @override
  State<StartupSettings> createState() => _StartupSettingsState();
}

class _StartupSettingsState extends State<StartupSettings> {
  final _startupService = container.resolve<IStartupSettingsService>();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
  bool get _isSystemSettingNeeded => PlatformUtils.isMobile;

  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadStartupSetting();
  }

  Future<void> _loadStartupSetting() async {
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
      onSuccess: (_) {
        widget.onLoaded?.call();
      },
      onError: (e) {
        Logger.error('Error loading startup setting: $e');
        widget.onLoaded?.call();
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
    return StreamBuilder<void>(
      stream: _themeService.themeChanges,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        return SettingsMenuTile(
          icon: Icons.launch,
          title: _translationService.translate(SettingsTranslationKeys.startupTitle),
          subtitle:
              PlatformUtils.isMobile ? _translationService.translate(SettingsTranslationKeys.startupSubtitle) : null,
          trailing: PlatformUtils.isMobile
              ? null // Defaults to chevron_right
              : _isLoading || _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(
                      value: _isEnabled,
                      onChanged: _toggleStartupSetting,
                      activeColor: theme.colorScheme.primary,
                    ),
          onTap: () => _toggleStartupSetting(!_isEnabled),
          isActive: true,
        );
      },
    );
  }
}
