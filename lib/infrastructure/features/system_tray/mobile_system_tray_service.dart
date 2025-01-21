import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:whph/presentation/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/domain/shared/constants/app_assets.dart';

class MobileSystemTrayService implements ISystemTrayService {
  static const int _notificationId = 888;
  static const String _notificationChannelId = 'system_tray';
  static const String _notificationChannelName = 'System Tray';

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      importance: Importance.min,
      playSound: false,
      enableVibration: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _isInitialized = true;
    await _showPersistentNotification();
  }

  Future<void> _showPersistentNotification() async {
    final androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      ongoing: true,
      autoCancel: false,
      importance: Importance.min,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
    );

    await _notifications.show(
      _notificationId,
      'App Running',
      'Tap to open',
      NotificationDetails(android: androidDetails),
    );
  }

  @override
  Future<void> setTrayIcon(TrayIconType type) async {
    // Update notification icon if needed
    await _showPersistentNotification();
  }

  @override
  Future<void> destroy() async {
    await _notifications.cancel(_notificationId);
  }

  @override
  Future<void> showWindow() async {
    // Not needed for mobile
  }

  @override
  Future<void> hideWindow() async {
    // Not needed for mobile
  }

  @override
  Future<void> exitApp() async {
    await destroy();
  }

  // Menu related methods - not applicable for mobile but need to be implemented
  @override
  Future<void> addMenuItem(dynamic item) async {}

  @override
  Future<void> addMenuItems(List items) async {}

  @override
  Future<void> insertMenuItems(List items, int index) async {}

  @override
  Future<void> removeMenuItem(String key) async {}

  @override
  Future<void> clearMenu() async {}

  @override
  Future<void> rebuildMenu() async {}
}
