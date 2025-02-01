import 'package:flutter/material.dart';
import 'package:whph/presentation/features/settings/components/language_settings.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/sync/pages/sync_devices_page.dart';
import 'package:whph/presentation/features/about/components/app_about.dart';
import 'package:whph/presentation/features/settings/components/startup_settings.dart';
import 'package:whph/presentation/features/settings/components/notification_settings.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/features/settings/components/import_export_settings.dart';

class SettingsPage extends StatelessWidget {
  static const String route = '/settings';

  const SettingsPage({super.key});

  void _showAboutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: SingleChildScrollView(child: AppAbout())),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return ResponsiveScaffoldLayout(
      title: translationService.translate(SettingsTranslationKeys.settingsTitle),
      builder: (context) => ListView(
        children: [
          // Startup
          if (StartupSettings.compatiblePlatform) ...[
            const StartupSettings(),
            const SizedBox(height: 8),
          ],
          // Notification
          const NotificationSettings(),
          const SizedBox(height: 8),

          // Language
          LanguageSettings(),
          const SizedBox(height: 8),

          // Sync Devices
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync),
              title: Text(translationService.translate(SettingsTranslationKeys.syncDevicesTitle),
                  style: AppTheme.bodyMedium),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pushNamed(context, SyncDevicesPage.route);
              },
            ),
          ),
          const SizedBox(height: 8),

          // Import/Export Settings
          const ImportExportSettings(),
          const SizedBox(height: 8),

          // About
          Card(
            child: ListTile(
              leading: const Icon(Icons.info, size: AppTheme.fontSizeLarge),
              title: Text(translationService.translate(SettingsTranslationKeys.aboutTitle), style: AppTheme.bodyMedium),
              trailing: const Icon(Icons.arrow_forward_ios, size: AppTheme.fontSizeLarge),
              onTap: () => _showAboutModal(context),
            ),
          ),
        ],
      ),
    );
  }
}
