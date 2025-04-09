import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'dart:io';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/domain/features/settings/constants/settings.dart';

class MobileNotificationService implements INotificationService {
  final ISettingRepository _settingRepository;
  final FlutterLocalNotificationsPlugin _flutterLocalNotifications;

  MobileNotificationService(this._settingRepository) : _flutterLocalNotifications = FlutterLocalNotificationsPlugin();

  @override
  Future<void> init() async {
    await _flutterLocalNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!await isEnabled()) return;

    final bool? permissionGranted = await _checkPermission();
    if (permissionGranted != true) return;

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

  Future<bool?> _checkPermission() async {
    if (Platform.isIOS) {
      return await _flutterLocalNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      return await androidImplementation?.requestNotificationsPermission();
    }

    return false;
  }

  @override
  Future<void> clearAll() async {
    await _flutterLocalNotifications.cancelAll();
  }

  @override
  Future<void> destroy() async {
    await clearAll();
  }

  @override
  Future<bool> isEnabled() async {
    final setting = await _settingRepository.getByKey(Settings.notifications);
    return setting?.value == 'false' ? false : true; // Default to true if no setting
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _checkPermission();
    }

    final setting = await _settingRepository.getByKey(Settings.notifications);
    if (setting != null) {
      setting.value = enabled.toString();
      await _settingRepository.update(setting);
    } else {
      await _settingRepository.add(Setting(
        id: nanoid(),
        key: Settings.notifications,
        value: enabled.toString(),
        valueType: SettingValueType.bool,
        createdDate: DateTime.now(),
      ));
    }
  }
}
