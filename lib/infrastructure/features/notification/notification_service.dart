import 'dart:io';
import 'package:local_notifier/local_notifier.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:whph/domain/features/shared/constants/app_info.dart';
import 'package:whph/presentation/features/shared/services/abstraction/i_notification_service.dart';

class NotificationService implements INotificationService {
  final List<LocalNotification> _activeDesktopNotifications = [];
  final FlutterLocalNotificationsPlugin _flutterLocalNotifications = FlutterLocalNotificationsPlugin();

  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Future<void> init() async {
    if (_isDesktop) {
      await localNotifier.setup(appName: AppInfo.name);
    } else {
      await _flutterLocalNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
    }
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_isDesktop) {
      await _showDesktopNotification(title, body, payload);
    } else {
      await _showMobileNotification(title, body, payload);
    }
  }

  Future<void> _showDesktopNotification(String title, String body, String? payload) async {
    final notification = LocalNotification(
      title: title,
      body: body,
      identifier: payload,
      actions: payload != null ? [LocalNotificationAction(type: 'button', text: 'Open')] : null,
    );

    await notification.show();
    _activeDesktopNotifications.add(notification);
  }

  Future<void> _showMobileNotification(String title, String body, String? payload) async {
    await _flutterLocalNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppInfo.name,
          AppInfo.name,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  @override
  Future<void> clearAll() async {
    if (_isDesktop) {
      for (var notification in _activeDesktopNotifications) {
        await notification.close();
      }
      _activeDesktopNotifications.clear();
    } else {
      await _flutterLocalNotifications.cancelAll();
    }
  }

  @override
  Future<void> destroy() async {
    await clearAll();
    if (_isDesktop) {
      _activeDesktopNotifications.clear();
    }
  }
}
