import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show PlatformUtils;

import 'package:whph/features/settings/components/about_tile.dart';
import 'package:whph/features/settings/components/language_settings.dart';
import 'package:whph/features/settings/components/permission_settings.dart';
import 'package:whph/features/settings/components/sound_settings.dart';
import 'package:whph/features/settings/components/sync_devices_tile.dart';
import 'package:whph/features/settings/components/tasks_tile.dart';
import 'package:whph/features/settings/components/habits_tile.dart';
import 'package:whph/shared/components/loading_overlay.dart';
import 'package:whph/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/features/settings/components/startup_settings.dart';
import 'package:whph/features/settings/components/notification_settings.dart';
import 'package:whph/features/settings/components/theme_settings.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/features/settings/constants/settings_translation_keys.dart';

import 'package:whph/features/settings/components/import_export_settings.dart';
import 'package:whph/features/settings/components/advanced_settings_tile.dart';
import 'package:whph/shared/components/section_header.dart';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // General Section
                SectionHeader(title: translationService.translate(SettingsTranslationKeys.sectionGeneral)),
                const SizedBox(height: AppTheme.sizeSmall),
                Column(
                  spacing: AppTheme.sizeSmall,
                  children: [
                    LanguageSettings(),
                    StartupSettings(onLoaded: _onStartupLoaded),
                    if (PlatformUtils.isMobile) PermissionSettings(),
                  ],
                ),
                const SizedBox(height: AppTheme.sizeLarge),

                // Flow Section
                SectionHeader(title: translationService.translate(SettingsTranslationKeys.sectionFlow)),
                const SizedBox(height: AppTheme.sizeSmall),
                Column(
                  spacing: AppTheme.sizeSmall,
                  children: const [
                    TasksTile(),
                    HabitsTile(),
                  ],
                ),
                const SizedBox(height: AppTheme.sizeLarge),

                // Appearance Section
                SectionHeader(title: translationService.translate(SettingsTranslationKeys.sectionAppearance)),
                const SizedBox(height: AppTheme.sizeSmall),
                Column(
                  spacing: AppTheme.sizeSmall,
                  children: [
                    ThemeSettings(onLoaded: _onThemeLoaded),
                    SoundSettings(onLoaded: _onSoundLoaded),
                  ],
                ),
                const SizedBox(height: AppTheme.sizeLarge),

                // Notifications Section
                SectionHeader(title: translationService.translate(SettingsTranslationKeys.sectionNotifications)),
                const SizedBox(height: AppTheme.sizeSmall),
                NotificationSettings(onLoaded: _onNotificationLoaded),
                const SizedBox(height: AppTheme.sizeLarge),

                // Data & Sync Section
                SectionHeader(title: translationService.translate(SettingsTranslationKeys.sectionDataSync)),
                const SizedBox(height: AppTheme.sizeSmall),
                Column(
                  spacing: AppTheme.sizeSmall,
                  children: [
                    SyncDevicesTile(),
                    const ImportExportSettings(),
                  ],
                ),
                const SizedBox(height: AppTheme.sizeLarge),

                // Advanced Section
                SectionHeader(title: translationService.translate(SettingsTranslationKeys.sectionAdvanced)),
                const SizedBox(height: AppTheme.sizeSmall),
                const AdvancedSettingsTile(),
                const SizedBox(height: AppTheme.sizeLarge),

                // About Section
                SectionHeader(title: translationService.translate(SettingsTranslationKeys.sectionAbout)),
                const SizedBox(height: AppTheme.sizeSmall),
                AboutTile(),
                const SizedBox(height: AppTheme.sizeXLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
