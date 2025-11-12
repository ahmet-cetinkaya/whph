import 'package:flutter/material.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/presentation/ui/features/settings/components/about_tile.dart';
import 'package:whph/presentation/ui/features/settings/components/language_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/permission_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/sound_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/sync_devices_tile.dart';
import 'package:whph/presentation/ui/shared/components/loading_overlay.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/features/settings/components/startup_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/notification_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/theme_settings.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/components/import_export_settings.dart';
import 'package:whph/presentation/ui/features/settings/components/advanced_settings_tile.dart';

class SettingsPage extends StatefulWidget {
  static const String route = '/settings';

  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Track loading state for each settings tile
  bool _startupLoaded = false;
  bool _notificationLoaded = false;
  bool _themeLoaded = false;
  bool _soundLoaded = false;

  /// Check if all settings tiles have finished loading
  bool get _isPageFullyLoaded {
    return _startupLoaded && _notificationLoaded && _themeLoaded && _soundLoaded;
  }

  void _onStartupLoaded() {
    if (mounted) {
      setState(() {
        _startupLoaded = true;
      });
    }
  }

  void _onNotificationLoaded() {
    if (mounted) {
      setState(() {
        _notificationLoaded = true;
      });
    }
  }

  void _onThemeLoaded() {
    if (mounted) {
      setState(() {
        _themeLoaded = true;
      });
    }
  }

  void _onSoundLoaded() {
    if (mounted) {
      setState(() {
        _soundLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return ResponsiveScaffoldLayout(
      title: translationService.translate(SettingsTranslationKeys.settingsTitle),
      builder: (context) => LoadingOverlay(
        isLoading: !_isPageFullyLoaded,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: AppTheme.sizeSmall),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8.0,
                children: [
                  // Startup
                  StartupSettings(
                    onLoaded: _onStartupLoaded,
                  ),

                  // Notification
                  NotificationSettings(
                    onLoaded: _onNotificationLoaded,
                  ),

                  // Theme Settings
                  ThemeSettings(
                    onLoaded: _onThemeLoaded,
                  ),

                  // Sound Settings
                  SoundSettings(
                    onLoaded: _onSoundLoaded,
                  ),

                  // Permissions
                  if (PlatformUtils.isMobile) PermissionSettings(),

                  // Language
                  LanguageSettings(),

                  // Sync Devices
                  SyncDevicesTile(),

                  // Import/Export Settings
                  const ImportExportSettings(),

                  // Advanced Settings
                  const AdvancedSettingsTile(),

                  // About
                  AboutTile(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
