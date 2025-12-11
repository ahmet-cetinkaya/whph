import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';

class MobileSystemTrayService implements ISystemTrayService {
  // Constants
  static const int _notificationId = 888;
  static const String _notificationChannelId = 'system_tray';
  static const String _notificationChannelName = 'System Tray';

  // Private fields
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  String _currentTitle = '';
  String _currentBody = '';

  // Additional private fields for menu items
  List<TrayMenuItem> _menuItems = [];

  // Core methods
  @override
  Future<void> init() async {
    if (_isInitialized) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationAction,
    );
    await _createNotificationChannel();

    _isInitialized = true;
    await _showPersistentNotification();
  }

  @override
  Future<void> destroy() async {
    try {
      _menuItems.clear();
      _isInitialized = false;
      // Cancel the persistent notification with ID 888
      await _notifications.cancel(_notificationId);
      // Also try to cancel all notifications as a safety measure
      await _notifications.cancelAll();
    } catch (e) {
      // Log the error but don't throw to prevent disposal issues
      Logger.error('Error during MobileSystemTrayService destroy: $e');
    }
  }

  @override
  Future<void> reset() async {
    destroy();
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
      importance: Importance.defaultImportance, // Change from min to defaultImportance
      playSound: false,
      enableVibration: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _showPersistentNotification() async {
    final List<AndroidNotificationAction> actions = _menuItems.map((item) {
      return AndroidNotificationAction(
        item.key,
        item.label,
        showsUserInterface: true,
      );
    }).toList();

    final androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      ongoing: true,
      autoCancel: false,
      importance: Importance.defaultImportance, // Change from min to defaultImportance
      priority: Priority.high, // Change from low to high
      playSound: false,
      enableVibration: false,
      actions: actions,
      category: AndroidNotificationCategory.progress,
      showWhen: false,
    );

    await _notifications.show(
      _notificationId,
      _currentTitle,
      _currentBody,
      NotificationDetails(android: androidDetails),
    );
  }

  void _handleNotificationAction(NotificationResponse response) {
    if (response.notificationResponseType == NotificationResponseType.selectedNotification) return;

    final selectedItem = _menuItems.firstWhere(
      (item) => item.key == response.actionId,
      orElse: () => TrayMenuItem(key: '', label: ''),
    );

    selectedItem.onClicked?.call();
  }
}
