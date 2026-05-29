import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/infrastructure/shared/features/notification/base_notification_service.dart';
import 'package:whph/infrastructure/shared/features/window/abstractions/i_window_manager.dart';
import 'package:whph/infrastructure/windows/constants/windows_app_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_task_notification_handler.dart';

class DesktopNotificationService extends BaseNotificationService {
  @override
  String get componentName => 'DesktopNotificationService';

  final FlutterLocalNotificationsPlugin _flutterLocalNotifications;
  final IWindowManager _windowManager;
  final INotificationPayloadHandler _payloadHandler;
  final ITaskNotificationHandler _taskNotificationHandler;

  DesktopNotificationService(
    super.mediator,
    IWindowManager windowManager,
    INotificationPayloadHandler payloadHandler,
    ITaskNotificationHandler taskNotificationHandler,
  )   : _flutterLocalNotifications = FlutterLocalNotificationsPlugin(),
        _windowManager = windowManager,
        _payloadHandler = payloadHandler,
        _taskNotificationHandler = taskNotificationHandler;

  @override
  Future<void> init() async {
    final initializationSettings = InitializationSettings(
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open',
        defaultIcon: AssetsLinuxIcon(AppAssets.logoAdaptiveFg),
      ),
      windows: WindowsInitializationSettings(
        appName: AppInfo.name,
        appUserModelId: WindowsAppConstants.notifications.appUserModelId,
        guid: WindowsAppConstants.notifications.guid,
        iconPath: AppAssets.logoAdaptiveFgIco,
      ),
      macOS: const DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _flutterLocalNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        await _handleNotificationResponse(response);
      },
    );
  }

  Future<void> _handleNotificationResponse(NotificationResponse response) async {
    if (response.actionId == 'complete_task') {
      final payload = response.payload;
      if (payload != null) {
        final taskId = _extractTaskIdFromPayload(payload);
        if (taskId != null) {
          await _taskNotificationHandler.handleNotificationTaskCompletion(taskId);
        }
      }
      return;
    }

    if (response.payload == null || response.payload!.isEmpty) return;

    if (!await _windowManager.isVisible()) {
      await _windowManager.show();
    }
    if (!await _windowManager.isFocused()) {
      await _windowManager.focus();
    }

    await _payloadHandler.handlePayload(response.payload!);
  }

  String? _extractTaskIdFromPayload(String payload) {
    try {
      final taskIdRegex = RegExp(r'"taskId"\s*:\s*"([^"]+)"');
      final match = taskIdRegex.firstMatch(payload);
      return match?.group(1);
    } catch (e, stackTrace) {
      Logger.error(
        '[payload_extraction_failed] DesktopNotificationService: Failed to extract task ID from notification payload',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
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

    try {
      final isTaskNotification = payload != null && _isTaskCompletionPayload(payload);

      final notificationDetails = NotificationDetails(
        linux: LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.critical,
          actions: isTaskNotification && options?.actionButtonText != null
              ? [
                  LinuxNotificationAction(
                    key: 'complete_task',
                    label: options!.actionButtonText!,
                  ),
                ]
              : [],
        ),
        windows: WindowsNotificationDetails(),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _flutterLocalNotifications.show(
        id ?? KeyHelper.generateNumericId(),
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e, stackTrace) {
      Logger.error(
        '[notification_show_failed] DesktopNotificationService: Failed to show notification',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  bool _isTaskCompletionPayload(String payload) {
    // Task completion payloads contain taskId in the JSON
    return payload.contains('taskId');
  }

  @override
  Future<void> clearAll() async {
    await _flutterLocalNotifications.cancelAll();
  }

  @override
  Future<bool> checkPermissionStatus() async {
    if (Platform.isMacOS) {
      try {
        final macOSImplementation =
            _flutterLocalNotifications.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();

        if (macOSImplementation == null) {
          Logger.warning(
            'DesktopNotificationService: macOS notification implementation not available',
          );
          return false; // Safer default
        }

        final settings = await macOSImplementation.checkPermissions();
        final hasPermission =
            settings?.isAlertEnabled == true || settings?.isBadgeEnabled == true || settings?.isSoundEnabled == true;
        return hasPermission;
      } catch (e, stackTrace) {
        Logger.error(
          '[permission_check_failed] DesktopNotificationService: Failed to check macOS notification permission',
          error: e,
          stackTrace: stackTrace,
        );
        return false; // Safer to assume no permission on error
      }
    }

    // Linux/Windows: no standardized API; assume granted
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    bool permissionGranted = false;

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
      } catch (e, stackTrace) {
        Logger.error(
          '[permission_request_failed] DesktopNotificationService: Failed to request macOS notification permission',
          error: e,
          stackTrace: stackTrace,
        );
        permissionGranted = false;
      }
    } else {
      permissionGranted = true;
    }

    if (permissionGranted) {
      await setEnabled(true);
    }

    return permissionGranted;
  }
}
