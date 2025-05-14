import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whph/presentation/features/settings/components/language_settings.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/sync/pages/sync_devices_page.dart';
import 'package:whph/presentation/features/about/components/app_about.dart';
import 'package:whph/presentation/features/settings/components/startup_settings.dart';
import 'package:whph/presentation/features/settings/components/notification_settings.dart';
import 'package:whph/presentation/features/settings/pages/permissions_page.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/features/settings/components/import_export_settings.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class SettingsPage extends StatelessWidget {
  static const String route = '/settings';

  const SettingsPage({super.key});

  void _showAboutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: SingleChildScrollView(child: AppAbout())),
        );
      },
    );
  }

  void _showSyncDevicesModal(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    ResponsiveDialogHelper.showResponsiveDetailsPage(
      context: context,
      title: translationService.translate(SettingsTranslationKeys.syncDevicesTitle),
      fullHeight: true,
      child: const SyncDevicesPage(),
    );
  }

  void _showPermissionsModal(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    ResponsiveDialogHelper.showResponsiveDetailsPage(
      context: context,
      title: translationService.translate(SettingsTranslationKeys.permissionsTitle),
      fullHeight: true,
      child: const PermissionsPage(),
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

          // Permissions
          if (Platform.isAndroid) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.security),
                title: Text(
                  translationService.translate(SettingsTranslationKeys.permissionsTitle),
                  style: AppTheme.bodyMedium,
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showPermissionsModal(context),
              ),
            ),
            const SizedBox(height: 8),
          ],

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
              onTap: () => _showSyncDevicesModal(context),
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
