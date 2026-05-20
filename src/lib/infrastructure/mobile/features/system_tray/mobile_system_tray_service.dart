import 'package:flutter/material.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';

class MobileSystemTrayService implements ISystemTrayService {
  // Constants
  static const int _notificationId = 888;
  static const String _notificationChannelId = 'system_tray';
  static const String _notificationChannelName = 'System Tray';

  // Private fields
  final FlutterLocalNotificationsPlugin _notifications;
  bool _isInitialized = false;
  String _currentTitle = '';
  String _currentBody = '';

  // Additional private fields for menu items
  List<TrayMenuItem> _menuItems = [];

  /// Accepts a shared [FlutterLocalNotificationsPlugin] instance that has
  /// already been initialized by [MobileNotificationService].
  /// This avoids a second `.initialize()` call that would overwrite the
  /// notification service's foreground/background response callbacks.
  MobileSystemTrayService(this._notifications);

  // Core methods
  @override
  Future<void> init() async {
    if (_isInitialized) return;

    await _createNotificationChannel();

    _isInitialized = true;
    // NOTE: intentionally NOT automatically showing the notification here.
    // We only want it to appear when triggered (e.g. by timer).
  }

  @override
  Future<void> destroy() async {
    try {
      _menuItems.clear();
      _isInitialized = false;
      // Only cancel the persistent notification with ID 888
      await _notifications.cancel(_notificationId);
    } catch (e) {
      // Log the error but don't throw to prevent disposal issues
      Logger.error('Error during MobileSystemTrayService destroy: $e');
    }
  }

  @override
  Future<void> reset() async {
    destroy();
  }

  @override
  Future<void> cancelNotification() async {
    await _notifications.cancel(_notificationId);
  }

  // Tray/notification appearance methods
  @override
  Future<void> setIcon(TrayIconType type) async {
    await _showPersistentNotification();
  }

  @override
  Future<void> setTitle(String title) async {
    _currentTitle = title;
    await _showPersistentNotification();
  }

  @override
  Future<void> setBody(String body) async {
    _currentBody = body;
    await _showPersistentNotification();
  }

  // Menu management methods
  @override
  List<TrayMenuItem> getMenuItems() => _menuItems;

  @override
  Future<void> setMenuItems(List<TrayMenuItem> items) async {
    _menuItems = items;
    await _showPersistentNotification();
  }

  @override
  Future<void> insertMenuItem(TrayMenuItem item, {int? index}) async {
    if (index != null) {
      _menuItems.insert(index, item);
    } else {
      _menuItems.add(item);
    }
    await _showPersistentNotification();
  }

  @override
  Future<void> updateMenuItem(String key, TrayMenuItem newItem) async {}

  @override
  Future<TrayMenuItem?> getMenuItem(String key) async => null;

  @override
  Future<void> removeMenuItem(String key) async {
    _menuItems.removeWhere((item) => item.key == key);
    await _showPersistentNotification();
  }

  // Private helper methods
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _showPersistentNotification() async {
    // Only show persistent notification when app is in background
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState == AppLifecycleState.resumed) {
      // App is in foreground, cancel any existing notification and don't show
      await _notifications.cancel(_notificationId);
      return;
    }

    final List<AndroidNotificationAction> actions = _menuItems
        .where((item) => item.label.isNotEmpty) // Filter out separators
        .map((item) {
      return AndroidNotificationAction(
        item.key,
        item.label,
        showsUserInterface: false,
        cancelNotification: false,
      );
    }).toList();

    final androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      ongoing: true,
      autoCancel: false,
      importance: Importance.defaultImportance,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      actions: actions,
      showWhen: false,
    );

    await _notifications.show(
      _notificationId,
      _currentTitle,
      _currentBody,
      NotificationDetails(android: androidDetails),
    );
  }
}
