import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';

/// Callback type for handling task completion from notification
typedef TaskCompletionCallback = Future<void> Function(String taskId);

/// Callback type for handling habit completion from notification
typedef HabitCompletionCallback = Future<void> Function(String habitId);

/// Service responsible for handling notification payloads and platform channel communication
class NotificationPayloadService {
  static const Duration _initialPayloadDelay = Duration(milliseconds: 1500);
  static const Duration _retryDelay = Duration(milliseconds: 500);
  static const Duration _platformHandlerDelay = Duration(milliseconds: 500);
  static const int _maxRetries = 3;

  // Retry count tracking constants
  static const String _retryCountPrefix = 'retry_count_';
  static const int _maxPendingRetries = 5;

  /// Sets up notification click listener for Android platform
  static void setupNotificationListener(
    INotificationPayloadHandler payloadHandler, {
    TaskCompletionCallback? onTaskCompletion,
    HabitCompletionCallback? onHabitCompletion,
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
        case 'completeHabit':
          final habitId = call.arguments as String?;
          if (habitId != null && onHabitCompletion != null) {
            await onHabitCompletion(habitId);
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
          await _processPendingTaskWithRetry(platform, taskId, onTaskCompletion);
        }
      }
    } catch (e, stackTrace) {
      Logger.error(
        '[$TaskErrorIds.pendingTaskProcessingFailed] NotificationPayloadService: Critical error processing pending task completions',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Process a single pending task with retry limit enforcement
  static Future<void> _processPendingTaskWithRetry(
    MethodChannel platform,
    String taskId,
    TaskCompletionCallback onTaskCompletion,
  ) async {
    // Get current retry count from SharedPreferences
    final retryCountKey = '$_retryCountPrefix$taskId';
    final currentRetryCount = await _getRetryCount(platform, retryCountKey);

    // Check if max retries exceeded
    if (currentRetryCount >= _maxPendingRetries) {
      Logger.error(
        '[$TaskErrorIds.pendingTaskMaxRetriesExceeded] NotificationPayloadService: Max retries ($_maxPendingRetries) exceeded for task $taskId, clearing pending entry',
      );
      // Clear both the pending task and the retry count
      await platform.invokeMethod('clearPendingTaskCompletion', taskId);
      await _clearRetryCount(platform, retryCountKey);
      return;
    }

    try {
      // Complete the task
      await onTaskCompletion(taskId);

      // Success: clear the pending action and retry count
      await platform.invokeMethod('clearPendingTaskCompletion', taskId);
      await _clearRetryCount(platform, retryCountKey);

      Logger.debug('NotificationPayloadService: Processed pending task completion: $taskId');
    } catch (e, stackTrace) {
      // Increment retry count
      final newRetryCount = currentRetryCount + 1;
      await _setRetryCount(platform, retryCountKey, newRetryCount);

      Logger.error(
        '[$TaskErrorIds.pendingTaskProcessingFailed] NotificationPayloadService: Failed to process pending task $taskId (attempt $newRetryCount/$_maxPendingRetries) - will retry on next startup',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the retry count for a task from SharedPreferences
  static Future<int> _getRetryCount(MethodChannel platform, String key) async {
    try {
      final result = await platform.invokeMethod<int>('getRetryCount', key);
      return result ?? 0;
    } catch (e) {
      Logger.warning('NotificationPayloadService: Failed to get retry count for $key, assuming 0: $e');
      return 0;
    }
  }

  /// Set the retry count for a task in SharedPreferences
  static Future<void> _setRetryCount(MethodChannel platform, String key, int count) async {
    try {
      await platform.invokeMethod('setRetryCount', {'key': key, 'count': count});
    } catch (e) {
      Logger.error('NotificationPayloadService: Failed to set retry count for $key: $e');
    }
  }

  /// Clear the retry count for a task from SharedPreferences
  static Future<void> _clearRetryCount(MethodChannel platform, String key) async {
    try {
      await platform.invokeMethod('clearRetryCount', key);
    } catch (e) {
      Logger.warning('NotificationPayloadService: Failed to clear retry count for $key: $e');
    }
  }

  /// Processes any pending habit completions that were stored while app was not running
  /// Should be called on app startup after the habit completion callback is registered
  static Future<void> processPendingHabitCompletions(HabitCompletionCallback onHabitCompletion) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      Logger.debug('NotificationPayloadService: Checking for pending habit completions...');

      final platform = MethodChannel(AndroidAppConstants.channels.notification);
      final pendingHabitIds = await platform.invokeMethod<List<dynamic>>('getPendingHabitCompletions');

      if (pendingHabitIds == null || pendingHabitIds.isEmpty) {
        Logger.debug('NotificationPayloadService: No pending habit completions found');
        return;
      }

      Logger.debug('NotificationPayloadService: Found ${pendingHabitIds.length} pending habit completions');

      // Process each pending habit completion
      for (final habitId in pendingHabitIds) {
        if (habitId is String && habitId.isNotEmpty) {
          await _processPendingHabitWithRetry(platform, habitId, onHabitCompletion);
        }
      }
    } catch (e, stackTrace) {
      Logger.error(
        '[$TaskErrorIds.pendingHabitProcessingFailed] NotificationPayloadService: Critical error processing pending habit completions',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Process a single pending habit with retry limit enforcement
  static Future<void> _processPendingHabitWithRetry(
    MethodChannel platform,
    String habitId,
    HabitCompletionCallback onHabitCompletion,
  ) async {
    // Get current retry count from SharedPreferences
    final retryCountKey = '$_retryCountPrefix$habitId';
    final currentRetryCount = await _getRetryCount(platform, retryCountKey);

    // Check if max retries exceeded
    if (currentRetryCount >= _maxPendingRetries) {
      Logger.error(
        '[$TaskErrorIds.pendingHabitMaxRetriesExceeded] NotificationPayloadService: Max retries ($_maxPendingRetries) exceeded for habit $habitId, clearing pending entry',
      );
      // Clear both the pending habit and the retry count
      await platform.invokeMethod('clearPendingHabitCompletion', habitId);
      await _clearRetryCount(platform, retryCountKey);
      return;
    }

    try {
      // Complete the habit
      await onHabitCompletion(habitId);

      // Success: clear the pending action and retry count
      await platform.invokeMethod('clearPendingHabitCompletion', habitId);
      await _clearRetryCount(platform, retryCountKey);

      Logger.debug('NotificationPayloadService: Processed pending habit completion: $habitId');
    } catch (e, stackTrace) {
      // Increment retry count
      final newRetryCount = currentRetryCount + 1;
      await _setRetryCount(platform, retryCountKey, newRetryCount);

      Logger.error(
        '[$TaskErrorIds.pendingHabitProcessingFailed] NotificationPayloadService: Failed to process pending habit $habitId (attempt $newRetryCount/$_maxPendingRetries) - will retry on next startup',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
