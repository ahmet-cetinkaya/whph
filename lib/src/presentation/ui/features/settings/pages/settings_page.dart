import 'package:flutter/material.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/src/presentation/ui/features/settings/components/about_tile.dart';
import 'package:whph/src/presentation/ui/features/settings/components/language_settings.dart';
import 'package:whph/src/presentation/ui/features/settings/components/permission_settings.dart';
import 'package:whph/src/presentation/ui/features/settings/components/sync_devices_tile.dart';
import 'package:whph/src/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/src/presentation/ui/features/settings/components/startup_settings.dart';
import 'package:whph/src/presentation/ui/features/settings/components/notification_settings.dart';
import 'package:whph/src/presentation/ui/features/settings/components/theme_settings.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/features/settings/components/import_export_settings.dart';
import 'package:whph/src/presentation/ui/features/settings/components/advanced_settings_tile.dart';

class SettingsPage extends StatelessWidget {
  static const String route = '/settings';

  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return ResponsiveScaffoldLayout(
      title: translationService.translate(SettingsTranslationKeys.settingsTitle),
      builder: (context) => Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: AppTheme.sizeSmall),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8.0,
              children: [
                // Startup
                const StartupSettings(),

                // Notification
                const NotificationSettings(),

                // Theme Settings
                const ThemeSettings(),

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
    );
  }
}
