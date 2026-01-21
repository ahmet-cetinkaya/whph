import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mediatr/mediatr.dart';

import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/infrastructure/shared/features/window/abstractions/i_window_manager.dart';
import 'package:whph/infrastructure/windows/constants/windows_app_constants.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';

class DesktopNotificationService implements INotificationService {
  final Mediator _mediatr;
  final FlutterLocalNotificationsPlugin _flutterLocalNotifications;
  final IWindowManager _windowManager;
  final INotificationPayloadHandler _payloadHandler;

  DesktopNotificationService(
    Mediator mediatr,
    IWindowManager windowManager,
    INotificationPayloadHandler payloadHandler,
  )   : _flutterLocalNotifications = FlutterLocalNotificationsPlugin(),
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
        await _handleNotificationResponse(response);
      },
    );
  }

  /// Handle notification click events using the notification payload handler
  Future<void> _handleNotificationResponse(NotificationResponse response) async {
    // Handle action button clicks (e.g., complete task)
    if (response.actionId == 'complete_task') {
      final payload = response.payload;
      if (payload != null) {
        final taskId = _extractTaskIdFromPayload(payload);
        if (taskId != null) {
          await handleNotificationTaskCompletion(taskId);
        }
      }
      return;
    }

    // Handle default notification click (navigate to task)
    if (response.payload == null || response.payload!.isEmpty) return;

    // Ensure the app window is visible and focused
    if (!await _windowManager.isVisible()) {
      await _windowManager.show();
    }
    if (!await _windowManager.isFocused()) {
      await _windowManager.focus();
    }

    // Use the injected notification payload handler to process the payload
    await _payloadHandler.handlePayload(response.payload!);
  }

  /// Extract task ID from notification payload
  String? _extractTaskIdFromPayload(String payload) {
    try {
      // Payload format: {"route":"/tasks","arguments":{"taskId":"xxx"}}
      // Use regex to extract taskId
      final taskIdRegex = RegExp(r'"taskId"\s*:\s*"([^"]+)"');
      final match = taskIdRegex.firstMatch(payload);
      return match?.group(1);
    } catch (e) {
      Logger.error('Error extracting task ID from payload: $e');
      return null;
    }
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
    String? actionButtonText,
  }) async {
    if (!await isEnabled()) return;

    try {
      final isTaskNotification = payload != null && _isTaskCompletionPayload(payload);

      // Define platform-specific notification details
      final notificationDetails = NotificationDetails(
        // For Linux - add action button for task completion
        linux: LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.critical,
          actions: isTaskNotification
              ? [
                  LinuxNotificationAction(
                    key: 'complete_task',
                    label: 'Complete',
                  ),
                ]
              : const [],
        ),
        // For Windows - add action button for task completion
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

  /// Check if the payload indicates a task completion notification
  bool _isTaskCompletionPayload(String payload) {
    // Task completion payloads have format like: {"route":"/tasks","arguments":{"taskId":"xxx"}}
    // or contain taskId in the JSON
    return payload.contains('taskId');
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
      final setting = await _mediatr.send<GetSettingQuery, GetSettingQueryResponse?>(query);

      if (setting == null) {
        return true; // Default to true if no setting
      }

      final isEnabled = setting.value == 'false' ? false : true;
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

  @override
  Future<void> handleNotificationTaskCompletion(String taskId) async {
    try {
      Logger.info('DesktopNotificationService: Completing task from notification: $taskId');

      await _mediatr.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
        CompleteTaskCommand(id: taskId),
      );

      Logger.info('DesktopNotificationService: Task completed successfully from notification');
    } catch (e, stackTrace) {
      Logger.error(
        '[$TaskErrorIds.notificationActionFailed] DesktopNotificationService: Failed to complete task from notification',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> handleNotificationHabitCompletion(String habitId) async {
    try {
      Logger.info('DesktopNotificationService: Completing habit from notification: $habitId');

      await _mediatr.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
        ToggleHabitCompletionCommand(
          habitId: habitId,
          date: DateTime.now(),
        ),
      );

      Logger.info('DesktopNotificationService: Habit completed successfully from notification');
    } catch (e, stackTrace) {
      Logger.error(
        '[$TaskErrorIds.notificationActionFailed] DesktopNotificationService: Failed to complete habit from notification',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
