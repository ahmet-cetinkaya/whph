import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';

/// Callback type for handling task completion from notification
typedef TaskCompletionCallback = Future<void> Function(String taskId);

/// Service responsible for handling notification payloads and platform channel communication
class NotificationPayloadService {
  static const Duration _initialPayloadDelay = Duration(milliseconds: 1500);
  static const Duration _retryDelay = Duration(milliseconds: 500);
  static const Duration _platformHandlerDelay = Duration(milliseconds: 500);
  static const int _maxRetries = 3;

  /// Sets up notification click listener for Android platform
  static void setupNotificationListener(
    INotificationPayloadHandler payloadHandler, {
    TaskCompletionCallback? onTaskCompletion,
  }) {
    if (!Platform.isAndroid) {
      Logger.debug('NotificationPayloadService: Not Android platform, skipping notification listener setup');
      return;
    }

    Logger.debug('NotificationPayloadService: Setting up Android notification listener...');

    final platform = MethodChannel(AndroidAppConstants.channels.notification);
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onNotificationClicked':
          final payload = call.arguments as String?;
          if (payload != null) {
            await _handleNotificationPayload(payload, payloadHandler, platform);
          }
          break;
        case 'completeTask':
          final taskId = call.arguments as String?;
          if (taskId != null && onTaskCompletion != null) {
            await onTaskCompletion(taskId);
          }
          break;
      }
      return null;
    });

    Logger.debug('NotificationPayloadService: Android notification listener setup completed');
  }

  /// Handles the initial notification payload when the app is launched from a notification
  static Future<void> handleInitialNotificationPayload(INotificationPayloadHandler payloadHandler) async {
    Logger.debug('NotificationPayloadService: Checking for initial notification payload...');

    // Track if we've already handled a notification payload
    bool hasHandledPayload = false;

    // Try multiple times to get the initial notification payload
    // This helps with race conditions when the app is cold-started from a notification
    for (int i = 0; i < _maxRetries; i++) {
      try {
        // Skip if we've already handled a payload
        if (hasHandledPayload) break;

        final notificationPayload = await _getInitialNotificationPayload();

        if (notificationPayload != null && notificationPayload.isNotEmpty) {
          // Wait for app to be fully initialized before handling the payload
          await Future.delayed(_initialPayloadDelay);

          // Check again if a payload has been handled during this delay
          // (could happen via the method channel handler)
          if (hasHandledPayload) break;

          await payloadHandler.handlePayload(notificationPayload);

          // Acknowledge receipt of payload to native side
          await _acknowledgePayload(notificationPayload);

          hasHandledPayload = true;
          Logger.debug('NotificationPayloadService: Initial notification payload handled successfully');
          break; // Exit the retry loop if successful
        }

        // If no payload found, wait before trying again
        await Future.delayed(_retryDelay);
      } catch (e) {
        Logger.error('NotificationPayloadService: Error handling initial notification payload: $e');
        await Future.delayed(_retryDelay);
      }
    }

    Logger.debug('NotificationPayloadService: Initial notification payload check completed');
  }

  /// Handles a notification payload from the platform channel
  static Future<void> _handleNotificationPayload(
    String payload,
    INotificationPayloadHandler payloadHandler,
    MethodChannel platform,
  ) async {
    try {
      Logger.debug('NotificationPayloadService: Handling notification payload: $payload');

      // Delay to ensure the app is fully initialized before handling the payload
      await Future.delayed(_platformHandlerDelay);
      await payloadHandler.handlePayload(payload);

      // Acknowledge receipt of payload to native side
      await platform.invokeMethod('acknowledgePayload', payload);

      Logger.debug('NotificationPayloadService: Notification payload handled and acknowledged');
    } catch (e) {
      Logger.error('NotificationPayloadService: Error handling notification payload: $e');
    }
  }

  /// Gets the initial notification payload if the app was launched from a notification
  static Future<String?> _getInitialNotificationPayload() async {
    try {
      if (Platform.isAndroid) {
        // Get the initial notification payload from the platform channel
        final platform = MethodChannel(AndroidAppConstants.channels.notification);
        final payload = await platform.invokeMethod<String>('getInitialNotificationPayload');
        return payload;
      }
    } catch (e) {
      Logger.error('NotificationPayloadService: Error getting initial notification payload: $e');
    }
    return null;
  }

  /// Acknowledges receipt of payload to the native side
  static Future<void> _acknowledgePayload(String payload) async {
    try {
      if (Platform.isAndroid) {
        final platform = MethodChannel(AndroidAppConstants.channels.notification);
        await platform.invokeMethod('acknowledgePayload', payload);
      }
    } catch (e) {
      Logger.error('NotificationPayloadService: Error acknowledging payload: $e');
    }
  }

  /// Processes any pending task completions that were stored while app was not running
  /// Should be called on app startup after the task completion callback is registered
  static Future<void> processPendingTaskCompletions(TaskCompletionCallback onTaskCompletion) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      Logger.debug('NotificationPayloadService: Checking for pending task completions...');

      final platform = MethodChannel(AndroidAppConstants.channels.notification);
      final pendingTaskIds = await platform.invokeMethod<List<dynamic>>('getPendingTaskCompletions');

      if (pendingTaskIds == null || pendingTaskIds.isEmpty) {
        Logger.debug('NotificationPayloadService: No pending task completions found');
        return;
      }

      Logger.debug('NotificationPayloadService: Found ${pendingTaskIds.length} pending task completions');

      // Process each pending task completion
      for (final taskId in pendingTaskIds) {
        if (taskId is String && taskId.isNotEmpty) {
          try {
            // First, complete the task
            await onTaskCompletion(taskId);

            // Only clear the pending action if completion succeeded
            // This prevents lost actions if completion fails
            await platform.invokeMethod('clearPendingTaskCompletion', taskId);

            Logger.debug('NotificationPayloadService: Processed pending task completion: $taskId');
          } catch (e, stackTrace) {
            // Log the error but DON'T clear the pending action
            // It will be retried on next app startup
            Logger.error(
              'NotificationPayloadService: Failed to process pending task $taskId - will retry on next startup',
              error: e,
              stackTrace: stackTrace,
            );
          }
        }
      }
    } catch (e, stackTrace) {
      Logger.error(
        'NotificationPayloadService: Critical error processing pending task completions',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
