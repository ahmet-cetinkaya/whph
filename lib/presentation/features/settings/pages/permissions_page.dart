import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/settings/components/battery_optimization.dart';
import 'package:whph/presentation/features/settings/components/exact_alarm_permission.dart';
import 'package:whph/presentation/features/settings/components/notification_permission.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

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
        title: Text(_translationService.translate(SettingsTranslationKeys.permissionsTitle)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Notification Permission
            const NotificationPermission(),
            const SizedBox(height: 16),

            // Exact Alarm Permission (Android 12+)
            const ExactAlarmPermission(),
            const SizedBox(height: 16),

            // Battery Optimization (Android)
            const BatteryOptimization(),
          ],
        ),
      ),
    );
  }
}
