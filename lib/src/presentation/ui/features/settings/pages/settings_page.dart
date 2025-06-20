import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/features/settings/components/about_tile.dart';
import 'package:whph/src/presentation/ui/features/settings/components/language_settings.dart';
import 'package:whph/src/presentation/ui/features/settings/components/permission_settings.dart';
import 'package:whph/src/presentation/ui/features/settings/components/sync_devices_tile.dart';
import 'package:whph/src/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/src/presentation/ui/features/settings/components/startup_settings.dart';
import 'package:whph/src/presentation/ui/features/settings/components/notification_settings.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/features/settings/components/import_export_settings.dart';

class SettingsPage extends StatelessWidget {
  static const String route = '/settings';

  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return ResponsiveScaffoldLayout(
      title: translationService.translate(SettingsTranslationKeys.settingsTitle),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: AppTheme.sizeSmall),
        child: SingleChildScrollView(
          child: Column(
            spacing: 8.0,
            children: [
              // Startup
              if (StartupSettings.compatiblePlatform) const StartupSettings(),

              // Notification
              const NotificationSettings(),

              // Permissions
              if (Platform.isAndroid) PermissionSettings(),

              // Language
              LanguageSettings(),

              // Sync Devices
              SyncDevicesTile(),

              // Import/Export Settings
              const ImportExportSettings(),

              // About
              AboutTile(),
            ],
          ),
        ),
      ),
    );
  }
}
