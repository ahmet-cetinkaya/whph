import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/src/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/src/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

class MobileNotificationService implements INotificationService {
  final Mediator _mediator;
  final FlutterLocalNotificationsPlugin _flutterLocalNotifications;

  MobileNotificationService(this._mediator) : _flutterLocalNotifications = FlutterLocalNotificationsPlugin();

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
    int? id,
  }) async {
    if (!await isEnabled()) return;

    final bool? permissionGranted = await _checkPermission();
    if (permissionGranted != true) return;

    await _flutterLocalNotifications.show(
      id ?? KeyHelper.generateNumericId(),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppInfo.name,
          AppInfo.name,
          importance: Importance.max,
          priority: Priority.high,
          channelShowBadge: true,
          enableLights: true,
          enableVibration: true,
          playSound: true,
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
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      return await androidImplementation?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      return await _flutterLocalNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
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
    try {
      final query = GetSettingQuery(key: SettingKeys.notifications);
      final setting = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(query);
      return setting.value == 'false' ? false : true; // Default to true if no setting
    } catch (e) {
      return true; // Default to true if setting not found
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _checkPermission();
    }

    final command = SaveSettingCommand(
      key: SettingKeys.notifications,
      value: enabled.toString(),
      valueType: SettingValueType.bool,
    );

    await _mediator.send(command);
  }

  @override
  Future<bool> checkPermissionStatus() async {
    if (!PlatformUtils.isMobile) {
      return true; // Always return true for non-mobile platforms
    }

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final areNotificationsEnabled = await androidImplementation?.areNotificationsEnabled();
      return areNotificationsEnabled ?? false;
    }

    return false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!PlatformUtils.isMobile && !Platform.isIOS) {
      return true; // Non-mobile platforms don't need explicit permission
    }

    bool permissionGranted = false;

    try {
      if (PlatformUtils.isMobile) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        permissionGranted = await androidImplementation?.requestNotificationsPermission() ?? false;
      } else if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImplementation =
            _flutterLocalNotifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

        permissionGranted = await iosImplementation?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      // If permission is granted, ensure notifications are enabled in app settings
      if (permissionGranted) {
        await setEnabled(true);
      }

      return permissionGranted;
    } catch (e) {
      Logger.error('Error requesting notification permission: $e');
      return false;
    }
  }
}
