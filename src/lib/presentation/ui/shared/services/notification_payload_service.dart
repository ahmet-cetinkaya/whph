import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';

@pragma('vm:entry-point')
void whphBackgroundNotificationHandler(NotificationResponse response) {
  try {
    if (response.actionId != null) {
      final SendPort? sendPort = IsolateNameServer.lookupPortByName(NotificationPayloadService.actionPortName);
      if (sendPort != null) {
        sendPort.send(response.actionId);
      } else {
        // Logger may not be initialized in background isolate — use print as fallback
        // ignore: avoid_print
        print('[NotificationPayloadService] No SendPort found for ${NotificationPayloadService.actionPortName}');
      }
    }
  } catch (e, stackTrace) {
    // Logger may not be initialized in background isolate — use print as fallback
    // ignore: avoid_print
    print('[NotificationPayloadService] Background handler failed: $e\n$stackTrace');
  }
}

/// Callback for handling task completion from notification
typedef TaskCompletionCallback = Future<void> Function(String taskId);

/// Callback for handling habit completion from notification
typedef HabitCompletionCallback = Future<void> Function(String habitId);

/// Handles notification payloads and platform channel communication
class NotificationPayloadService {
  static const String actionPortName = 'whph_notification_action_port';
  static const Duration _initialPayloadDelay = Duration(milliseconds: 1500);
  static const Duration _retryDelay = Duration(milliseconds: 500);
  static const Duration _platformHandlerDelay = Duration(milliseconds: 500);
  static const int _maxRetries = 3;

  // Tracks retry attempts per entity to prevent infinite retry loops
  static const String _retryCountTaskPrefix = 'retry_count_task_';
  static const String _retryCountHabitPrefix = 'retry_count_habit_';
  static const int _maxPendingRetries = 5;

  /// Override for testing to simulate Android platform
  static bool forceAndroid = false;

  static final StreamController<String> _actionStreamController = StreamController<String>.broadcast();
  static Stream<String> get actionStream => _actionStreamController.stream;
  static ReceivePort? _actionPort;

  static void setupActionStream() {
    if (_actionPort != null) return;
    _actionPort = ReceivePort();
    IsolateNameServer.removePortNameMapping(actionPortName);
    IsolateNameServer.registerPortWithName(_actionPort!.sendPort, actionPortName);

    _actionPort!.listen((message) {
      if (message is String) {
        _actionStreamController.add(message);
      } else {
        Logger.warning(
          'Unexpected message type in notification action port: ${message.runtimeType}',
          component: 'NotificationPayloadService',
        );
      }
    });
  }

  static void disposeActionStream() {
    _actionPort?.close();
    _actionPort = null;
    IsolateNameServer.removePortNameMapping(actionPortName);
  }

  static void handleForegroundAction(String actionId) {
    _actionStreamController.add(actionId);
  }

  static void setupNotificationListener(
    INotificationPayloadHandler payloadHandler, {
    TaskCompletionCallback? onTaskCompletion,
    HabitCompletionCallback? onHabitCompletion,
  }) {
    if (!Platform.isAndroid && !forceAndroid) return;

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
  }

  /// Retrieves and processes the notification payload that launched the app
  static Future<void> handleInitialNotificationPayload(INotificationPayloadHandler payloadHandler) async {
    bool hasHandledPayload = false;

    // Retry to handle race conditions on cold start from notification
    for (int i = 0; i < _maxRetries; i++) {
      try {
        if (hasHandledPayload) break;

        final notificationPayload = await _getInitialNotificationPayload();

        if (notificationPayload != null && notificationPayload.isNotEmpty) {
          // Wait for app to be fully initialized before processing
          await Future.delayed(_initialPayloadDelay);

          if (hasHandledPayload) break;

          await payloadHandler.handlePayload(notificationPayload);
          await _acknowledgePayload(notificationPayload);

          hasHandledPayload = true;
          break;
        }

        await Future.delayed(_retryDelay);
      } catch (e) {
        Logger.error('NotificationPayloadService: Error handling initial notification payload: $e');
        await Future.delayed(_retryDelay);
      }
    }
  }

  static Future<void> _handleNotificationPayload(
    String payload,
    INotificationPayloadHandler payloadHandler,
    MethodChannel platform,
  ) async {
    try {
      // Delay ensures the app is fully initialized before handling the payload
      await Future.delayed(_platformHandlerDelay);
      await payloadHandler.handlePayload(payload);
      await platform.invokeMethod('acknowledgePayload', payload);
    } catch (e) {
      Logger.error('NotificationPayloadService: Error handling notification payload: $e');
    }
  }

  static Future<String?> _getInitialNotificationPayload() async {
    try {
      if (Platform.isAndroid || forceAndroid) {
        final platform = MethodChannel(AndroidAppConstants.channels.notification);
        final payload = await platform.invokeMethod<String>('getInitialNotificationPayload');
        return payload;
      }
    } catch (e) {
      Logger.error('NotificationPayloadService: Error getting initial notification payload: $e');
    }
    return null;
  }

  static Future<void> _acknowledgePayload(String payload) async {
    try {
      if (Platform.isAndroid || forceAndroid) {
        final platform = MethodChannel(AndroidAppConstants.channels.notification);
        await platform.invokeMethod('acknowledgePayload', payload);
      }
    } catch (e) {
      Logger.error('NotificationPayloadService: Error acknowledging payload: $e');
    }
  }

  /// Processes pending task completions stored while the app was not running.
  /// Call on startup after registering the completion callback.
  static Future<void> processPendingTaskCompletions(TaskCompletionCallback onTaskCompletion) async {
    if (!Platform.isAndroid && !forceAndroid) return;

    try {
      final platform = MethodChannel(AndroidAppConstants.channels.notification);
      final pendingTaskIds = await platform.invokeMethod<List<dynamic>>('getPendingTaskCompletions');

      if (pendingTaskIds == null || pendingTaskIds.isEmpty) return;

      for (final taskId in pendingTaskIds) {
        if (taskId is String && taskId.isNotEmpty) {
          await _processPendingCompletionWithRetry(
            platform: platform,
            entityId: taskId,
            retryCountPrefix: _retryCountTaskPrefix,
            clearMethod: 'clearPendingTaskCompletion',
            entityName: 'Task',
            maxRetriesErrorId: TaskErrorIds.pendingTaskMaxRetriesExceeded,
            processingErrorId: TaskErrorIds.pendingTaskProcessingFailed,
            completionCallback: () => onTaskCompletion(taskId),
          );
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

  /// Processes pending habit completions stored while the app was not running.
  /// Call on startup after registering the completion callback.
  static Future<void> processPendingHabitCompletions(HabitCompletionCallback onHabitCompletion) async {
    if (!Platform.isAndroid && !forceAndroid) return;

    try {
      final platform = MethodChannel(AndroidAppConstants.channels.notification);
      final pendingHabitIds = await platform.invokeMethod<List<dynamic>>('getPendingHabitCompletions');

      if (pendingHabitIds == null || pendingHabitIds.isEmpty) return;

      for (final habitId in pendingHabitIds) {
        if (habitId is String && habitId.isNotEmpty) {
          await _processPendingCompletionWithRetry(
            platform: platform,
            entityId: habitId,
            retryCountPrefix: _retryCountHabitPrefix,
            clearMethod: 'clearPendingHabitCompletion',
            entityName: 'Habit',
            maxRetriesErrorId: TaskErrorIds.pendingHabitMaxRetriesExceeded,
            processingErrorId: TaskErrorIds.pendingHabitProcessingFailed,
            completionCallback: () => onHabitCompletion(habitId),
          );
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

  /// Processes a pending completion with retry limit enforcement.
  /// Reduces duplication between task and habit completion handlers.
  static Future<void> _processPendingCompletionWithRetry({
    required MethodChannel platform,
    required String entityId,
    required String retryCountPrefix,
    required String clearMethod,
    required String entityName,
    required String maxRetriesErrorId,
    required String processingErrorId,
    required Future<void> Function() completionCallback,
  }) async {
    final retryCountKey = '$retryCountPrefix$entityId';
    final currentRetryCount = await _getRetryCount(platform, retryCountKey);

    if (currentRetryCount >= _maxPendingRetries) {
      Logger.error(
        '[$maxRetriesErrorId] NotificationPayloadService: Max retries ($_maxPendingRetries) exceeded for $entityName $entityId, clearing pending entry',
      );
      await platform.invokeMethod(clearMethod, entityId);
      await _clearRetryCount(platform, retryCountKey);
      return;
    }

    try {
      await completionCallback();
      await platform.invokeMethod(clearMethod, entityId);
      await _clearRetryCount(platform, retryCountKey);
    } catch (e, stackTrace) {
      final newRetryCount = currentRetryCount + 1;
      await _setRetryCount(platform, retryCountKey, newRetryCount);

      Logger.error(
        '[$processingErrorId] NotificationPayloadService: Failed to process pending $entityName $entityId (attempt $newRetryCount/$_maxPendingRetries) - will retry on next startup',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<int> _getRetryCount(MethodChannel platform, String key) async {
    try {
      final result = await platform.invokeMethod<int>('getRetryCount', key);
      return result ?? 0;
    } catch (e) {
      Logger.warning('NotificationPayloadService: Failed to get retry count for $key, assuming 0: $e');
      return 0;
    }
  }

  static Future<void> _setRetryCount(MethodChannel platform, String key, int count) async {
    try {
      await platform.invokeMethod('setRetryCount', {'key': key, 'count': count});
    } catch (e) {
      Logger.error('NotificationPayloadService: Failed to set retry count for $key: $e');
    }
  }

  static Future<void> _clearRetryCount(MethodChannel platform, String key) async {
    try {
      await platform.invokeMethod('clearRetryCount', key);
    } catch (e) {
      Logger.warning('NotificationPayloadService: Failed to clear retry count for $key: $e');
    }
  }
}
