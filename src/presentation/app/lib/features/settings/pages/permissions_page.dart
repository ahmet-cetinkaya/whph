import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/features/settings/components/app_usage_permission.dart';
import 'package:whph/features/settings/components/battery_optimization.dart';
import 'package:whph/features/settings/components/exact_alarm_permission.dart';
import 'package:whph/features/settings/components/notification_permission.dart';
import 'package:whph/features/settings/components/startup_permission.dart';
import 'package:whph/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/constants/app_theme.dart';

/// A page that displays all permission settings in one place
class PermissionsPage extends StatefulWidget {
  static const String route = '/settings/permissions';

  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  final _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(_translationService.translate(SettingsTranslationKeys.permissionsTitle)),
      ),
      body: Padding(
        padding: context.pageBodyPadding,
        child: ListView(
          children: const [
            // App Usage Permission
            AppUsagePermission(),
            SizedBox(height: 16),

            // Notification Permission
            NotificationPermission(),
            SizedBox(height: 16),

            // Exact Alarm Permission (Android 12+)
            ExactAlarmPermission(),
            SizedBox(height: 16),

            // Startup/Auto-start Permission (Android)
            StartupPermission(),
            SizedBox(height: 16),

            // Battery Optimization (Android)
            BatteryOptimization(),
          ],
        ),
      ),
    );
  }
}
