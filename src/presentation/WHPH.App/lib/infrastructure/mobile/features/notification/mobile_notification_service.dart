import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart' as shared;
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/infrastructure/shared/features/notification/base_notification_service.dart';

class MobileNotificationService extends BaseNotificationService {
  @override
  String get componentName => 'MobileNotificationService';

  final FlutterLocalNotificationsPlugin _flutterLocalNotifications;
  final bool _isAndroid;
  final bool _isIOS;

  MobileNotificationService(
    super.mediator, {
    FlutterLocalNotificationsPlugin? flutterLocalNotifications,
    bool? isAndroid,
    bool? isIOS,
  })  : _flutterLocalNotifications = flutterLocalNotifications ?? FlutterLocalNotificationsPlugin(),
        _isAndroid = isAndroid ?? Platform.isAndroid,
        _isIOS = isIOS ?? Platform.isIOS;

  @override
  Future<void> init() async {
    await _flutterLocalNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    if (!_isAndroid) return;

    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation == null) {
        Logger.error(
          '[notification_channel_init_failed] MobileNotificationService: Android notification implementation not available',
        );
        return;
      }

      final List<AndroidNotificationChannel> channels = [
        AndroidNotificationChannel(
          AndroidAppConstants.notificationChannels.taskChannelId,
          AndroidAppConstants.notificationChannels.taskChannelName,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
        AndroidNotificationChannel(
          AndroidAppConstants.notificationChannels.habitChannelId,
          AndroidAppConstants.notificationChannels.habitChannelName,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      ];

      for (final channel in channels) {
        try {
          await androidImplementation.createNotificationChannel(channel);
          Logger.info(
            'MobileNotificationService: Created notification channel ${channel.id}',
          );
        } catch (e, stackTrace) {
          Logger.error(
            '[notification_channel_creation_failed] MobileNotificationService: Failed to create notification channel ${channel.id}',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }
    } catch (e, stackTrace) {
      Logger.error(
        '[notification_channel_init_failed] MobileNotificationService: Failed to initialize notification channels',
        error: e,
        stackTrace: stackTrace,
      );
    }
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

    final bool? permissionGranted = await _checkPermission();
    if (permissionGranted != true) return;

    // Platform-specific notification details
    NotificationDetails notificationDetails;

    if (_isAndroid) {
      // Use task channel as default if none provided
      final String effectiveChannelId = options?.channelId ?? AndroidAppConstants.notificationChannels.taskChannelId;
      final String effectiveChannelName = effectiveChannelId == AndroidAppConstants.notificationChannels.habitChannelId
          ? AndroidAppConstants.notificationChannels.habitChannelName
          : AndroidAppConstants.notificationChannels.taskChannelName;

      notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          effectiveChannelId,
          effectiveChannelName,
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
      );
    } else {
      // iOS or other platforms
      notificationDetails = const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
    }

    await _flutterLocalNotifications.show(
      id ?? shared.KeyHelper.generateNumericId(),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<bool?> _checkPermission() async {
    if (_isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      return await androidImplementation?.requestNotificationsPermission();
    }

    if (_isIOS) {
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
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _checkPermission();
    }

    await super.setEnabled(enabled);
  }

  @override
  Future<bool> checkPermissionStatus() async {
    // Override platform check if flags are forced (testing)
    if (!_isAndroid && !_isIOS) {
      return true; // Always return true for non-mobile platforms
    }

    if (_isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final areNotificationsEnabled = await androidImplementation?.areNotificationsEnabled();
      return areNotificationsEnabled ?? false;
    }

    if (_isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      final permissions = await iosImplementation?.checkPermissions();
      // iOS notifications are enabled if alert, badge, or sound is enabled
      return permissions?.isEnabled ?? false;
    }

    return false;
  }

  @override
  Future<bool> requestPermission() async {
    // Override platform check if flags are forced (testing)
    if (!_isAndroid && !_isIOS) {
      return true; // Non-mobile platforms don't need explicit permission
    }

    bool permissionGranted = false;

    try {
      if (_isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        permissionGranted = await androidImplementation?.requestNotificationsPermission() ?? false;
      } else if (_isIOS) {
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
    } catch (e, stackTrace) {
      Logger.error(
        '[permission_request_failed] MobileNotificationService: Failed to request notification permission',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
