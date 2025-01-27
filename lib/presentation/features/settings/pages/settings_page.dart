import 'package:flutter/material.dart';
import 'package:whph/presentation/features/settings/components/language_settings.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/sync/pages/sync_devices_page.dart';
import 'package:whph/presentation/features/about/components/app_about.dart';
import 'package:whph/presentation/features/settings/components/startup_settings.dart';
import 'package:whph/presentation/features/settings/components/notification_settings.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class SettingsPage extends StatelessWidget {
  static const String route = '/settings';

  const SettingsPage({super.key});

  void _showAboutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: SingleChildScrollView(child: AppAbout())),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: 'Settings',
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
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
              title: Text('Sync Devices', style: AppTheme.bodyMedium),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, SyncDevicesPage.route);
              },
            ),
          ),
          const SizedBox(height: 8),

          // About
          Card(
            child: ListTile(
              leading: const Icon(Icons.info),
              title: Text('About', style: AppTheme.bodyMedium),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showAboutModal(context),
            ),
          ),
        ],
      ),
    );
  }
}
