import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mediatr/mediatr.dart';

import 'package:whph/src/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/src/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/core/domain/shared/constants/app_assets.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:whph/src/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/src/infrastructure/shared/features/window/abstractions/i_window_manager.dart';
import 'package:whph/src/infrastructure/windows/constants/windows_app_constants.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_notification_service.dart';

class DesktopNotificationService implements INotificationService {
  final Mediator _mediatr;
  final FlutterLocalNotificationsPlugin _flutterLocalNotifications;
  final IWindowManager _windowManager;
  final INotificationPayloadHandler _payloadHandler;

  DesktopNotificationService(Mediator mediatr, IWindowManager windowManager, INotificationPayloadHandler payloadHandler)
      : _flutterLocalNotifications = FlutterLocalNotificationsPlugin(),
        _mediatr = mediatr,
        _windowManager = windowManager,
        _payloadHandler = payloadHandler;

  @override
  Future<void> init() async {
    // Initialize the plugin with platform-specific settings
    final initializationSettings = InitializationSettings(
      // For Linux
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open',
        defaultIcon: AssetsLinuxIcon(AppAssets.logoAdaptiveFg),
      ),
      // For Windows
      windows: WindowsInitializationSettings(
        appName: AppInfo.name,
        appUserModelId: WindowsAppConstants.notifications.appUserModelId,
        guid: WindowsAppConstants.notifications.guid,
        iconPath: AppAssets.logoAdaptiveFgIco,
      ),
      // For macOS
      macOS: const DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    // Initialize the plugin with notification click handler
    await _flutterLocalNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload == null) return;
        await _handleNotificationResponse(response.payload!);
      },
    );
  }

  /// Handle notification click events using the notification payload handler
  Future<void> _handleNotificationResponse(String payload) async {
    if (payload.isEmpty) return;

    // Ensure the app window is visible and focused
    if (!await _windowManager.isVisible()) {
      await _windowManager.show();
    }
    if (!await _windowManager.isFocused()) {
      await _windowManager.focus();
    }

    // Use the injected notification payload handler to process the payload
    await _payloadHandler.handlePayload(payload);
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    if (!await isEnabled()) return;

    try {
      // Define platform-specific notification details
      final notificationDetails = NotificationDetails(
        // For Linux
        linux: LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.critical,
        ),
        // For Windows
        windows: WindowsNotificationDetails(),
        // For macOS
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // Show the notification
      await _flutterLocalNotifications.show(
        id ?? KeyHelper.generateNumericId(),
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      Logger.error('Error showing notification: $e');
    }
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
      final setting = await _mediatr.send<GetSettingQuery, GetSettingQueryResponse>(query);
      final isEnabled = setting.value == 'false' ? false : true; // Default to true if no setting
      return isEnabled;
    } catch (e) {
      Logger.error('Error checking if notifications are enabled: $e');
      return true; // Default to true if there's an error
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final command = SaveSettingCommand(
      key: SettingKeys.notifications,
      value: enabled.toString(),
      valueType: SettingValueType.bool,
    );

    await _mediatr.send(command);
  }

  @override
  Future<bool> checkPermissionStatus() async {
    // For desktop platforms, we can't programmatically check permission status
    // in most cases, so we'll rely on the app's notification settings

    // For macOS, we can check the permission status
    if (Platform.isMacOS) {
      try {
        final macOSImplementation =
            _flutterLocalNotifications.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();

        final settings = await macOSImplementation?.checkPermissions();
        return settings?.isAlertEnabled == true || settings?.isBadgeEnabled == true || settings?.isSoundEnabled == true;
      } catch (e) {
        Logger.error('Error checking macOS permission: $e');
      }
    }

    // For Linux/Windows, we assume permission is granted
    // as there's no standardized API to check it
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    bool permissionGranted = false;

    // For macOS, we can programmatically request permission
    if (Platform.isMacOS) {
      try {
        final macOSImplementation =
            _flutterLocalNotifications.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();

        final settings = await macOSImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

        permissionGranted = settings ?? false;
      } catch (e) {
        Logger.error('Error requesting macOS permission: $e');
        permissionGranted = false;
      }
    } else {
      // For Windows and Linux, permissions are typically managed at the OS level
      // and not programmatically by the app. We'll assume granted.
      permissionGranted = true;
    }

    // Update the app's notification settings if permission is granted
    if (permissionGranted) {
      await setEnabled(true);
    }

    return permissionGranted;
  }
}
