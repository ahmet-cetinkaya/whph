import 'package:flutter/material.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';

class MobileSystemTrayService implements ISystemTrayService {
  static const int _persistentNotificationId = 888;
  static const String _notificationChannelId = 'system_tray';
  static const String _notificationChannelName = 'System Tray';

  final FlutterLocalNotificationsPlugin _notifications;
  bool _isInitialized = false;
  String _currentTitle = '';
  String _currentBody = '';
  List<TrayMenuItem> _menuItems = [];
  final Map<String, VoidCallback> _actionHandlers = {};

  /// Accepts a shared [FlutterLocalNotificationsPlugin] instance that has
  /// already been initialized by [MobileNotificationService].
  /// This avoids a second `.initialize()` call that would overwrite the
  /// notification service's foreground/background response callbacks.
  MobileSystemTrayService(this._notifications);

  // Core methods
  @override
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _createNotificationChannel();
      _isInitialized = true;
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize MobileSystemTrayService',
          component: 'MobileSystemTrayService', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> destroy() async {
    try {
      _menuItems.clear();
      _actionHandlers.clear();
      _isInitialized = false;
      await _notifications.cancel(_persistentNotificationId);
    } catch (e) {
      Logger.error('Error during MobileSystemTrayService destroy: $e');
    }
  }

  @override
  Future<void> reset() async {
    await destroy();
    await init();
  }

  @override
  Future<void> cancelTrayNotification() async {
    await _notifications.cancel(_persistentNotificationId);
  }

  // Tray/notification appearance methods
  @override
  Future<void> setIcon(TrayIconType type) async {
    await _showPersistentNotification();
  }

  Future<void> updateTitle(String title) async {
    _currentTitle = title;
    await _showPersistentNotification();
  }

  @override
  Future<void> setTitle(String title) async {
    updateTitle(title);
  }

  Future<void> updateBody(String body) async {
    _currentBody = body;
    await _showPersistentNotification();
  }

  @override
  Future<void> setBody(String body) async {
    updateBody(body);
  }

  // Menu management methods
  @override
  List<TrayMenuItem> getMenuItems() => _menuItems;

  @override
  Future<void> setMenuItems(List<TrayMenuItem> items) async {
    _menuItems = items;
    _rebuildActionHandlers(items);
    await _showPersistentNotification();
  }

  @override
  Future<void> insertMenuItem(TrayMenuItem item, {int? index}) async {
    if (index != null) {
      _menuItems.insert(index, item);
    } else {
      _menuItems.add(item);
    }
    if (item.onClicked != null) {
      _actionHandlers[item.key] = item.onClicked!;
    }
    await _showPersistentNotification();
  }

  @override
  Future<void> updateMenuItem(String key, TrayMenuItem newItem) async {
    final index = _menuItems.indexWhere((item) => item.key == key);
    if (index != -1) {
      _menuItems[index] = newItem;
      if (newItem.onClicked != null) {
        _actionHandlers[key] = newItem.onClicked!;
      } else {
        _actionHandlers.remove(key);
      }
      await _showPersistentNotification();
    }
  }

  @override
  Future<TrayMenuItem?> getMenuItem(String key) async {
    try {
      return _menuItems.firstWhere((item) => item.key == key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removeMenuItem(String key) async {
    _menuItems.removeWhere((item) => item.key == key);
    _actionHandlers.remove(key);
    await _showPersistentNotification();
  }

  void handleNotificationAction(String actionId) {
    final handler = _actionHandlers[actionId];
    if (handler != null) {
      try {
        handler();
      } catch (e, stackTrace) {
        Logger.error('Notification action handler failed: $actionId',
            component: 'MobileSystemTrayService', error: e, stackTrace: stackTrace);
      }
    }
  }

  // Private helper methods
  void _rebuildActionHandlers(List<TrayMenuItem> items) {
    _actionHandlers.clear();
    for (final item in items) {
      if (item.onClicked != null) {
        _actionHandlers[item.key] = item.onClicked!;
      }
    }
  }

  Future<void> _createNotificationChannel() async {
    try {
      const androidChannel = AndroidNotificationChannel(
        _notificationChannelId,
        _notificationChannelName,
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      );

      final androidImpl =
          _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(androidChannel);
      } else {
        Logger.warning('Could not resolve Android FlutterLocalNotificationsPlugin implementation',
            component: 'MobileSystemTrayService');
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to create notification channel',
          component: 'MobileSystemTrayService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _showPersistentNotification() async {
    try {
      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      if (lifecycleState == AppLifecycleState.resumed) {
        await _notifications.cancel(_persistentNotificationId);
        return;
      }

      final List<AndroidNotificationAction> actions = _menuItems.where((item) => item.label.isNotEmpty).map((item) {
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
        _persistentNotificationId,
        _currentTitle,
        _currentBody,
        NotificationDetails(android: androidDetails),
      );
    } catch (e, stackTrace) {
      Logger.error('Failed to show persistent notification',
          component: 'MobileSystemTrayService', error: e, stackTrace: stackTrace);
    }
  }
}
