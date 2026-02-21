import 'dart:io';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/infrastructure/shared/features/window/abstractions/i_window_manager.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/infrastructure/shared/features/notification/base_notification_service.dart';

class FlatpakNotificationService extends BaseNotificationService {
  static const String _componentName = 'FlatpakNotificationService';
  @override
  String get componentName => _componentName;

  // Track notification payloads to handle synthetic click events if needed
  // Since dbus action signals are hard to listen to natively in dart without a dbus library,
  // we might not fully support interactive buttons unless we use a dbus package.
  // For now we will support basic notifications via gdbus.
  final Map<int, String> _payloads = {};

  FlatpakNotificationService(
    super.mediator,
    IWindowManager windowManager,
    INotificationPayloadHandler payloadHandler,
  );

  @override
  Future<void> init() async {
    // No specific initialization needed for gdbus portal calls
    Logger.debug('Initialized', component: _componentName);
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
    NotificationOptions? options,
  }) async {
    if (!await isEnabled()) return;

    final int notificationId = id ?? KeyHelper.generateNumericId();
    if (payload != null) {
      _payloads[notificationId] = payload;
    }

    try {
      // Create a D-Bus variant map for the notification options
      // format: {'title': <'Test Title'>, 'body': <'Test Body'>}

      // Escape single quotes in title and body to prevent command injection
      final String safeTitle = title.replaceAll("'", "''");
      final String safeBody = body.replaceAll("'", "''");

      // Build the dictionary string
      final String dbusDict = "{'title': <'$safeTitle'>, 'body': <'$safeBody'>}";
      final result = await Process.run('gdbus', [
        'call',
        '--session',
        '--dest',
        'org.freedesktop.portal.Desktop',
        '--object-path',
        '/org/freedesktop/portal/desktop',
        '--method',
        'org.freedesktop.portal.Notification.AddNotification',
        notificationId.toString(),
        dbusDict,
      ]);
      Logger.info('SENT NOTIFICATION WITH FLATPAK SERVICE', component: _componentName);

      if (result.exitCode != 0) {
        Logger.error('Failed to show notification: ${result.stderr}', component: _componentName);
      }
    } catch (e, stackTrace) {
      Logger.error(
        '[notification_show_failed] Failed to show notification',
        error: e,
        stackTrace: stackTrace,
        component: _componentName,
      );
    }
  }

  @override
  Future<void> clearAll() async {
    // The portal does not seem to have a RemoveAllNotifications, but we can clean up payloads
    _payloads.clear();
  }

  @override
  Future<bool> checkPermissionStatus() async {
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    // Portal handles its own permission requests if necessary
    await setEnabled(true);
    return true;
  }
}
