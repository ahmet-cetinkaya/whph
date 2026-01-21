import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:acore/acore.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/background_translation_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Implementation of the reminder service for Android platforms using native APIs
class AndroidReminderService implements IReminderService {
  final INotificationService _notificationService;
  final BackgroundTranslationService _translationService;

  // Method channel for native communication
  static final MethodChannel _notificationChannel = MethodChannel(AndroidAppConstants.channels.notification);
  static final MethodChannel _bootCompletedChannel = MethodChannel(AndroidAppConstants.channels.bootCompleted);

  AndroidReminderService(this._notificationService) : _translationService = BackgroundTranslationService();

  @override
  Future<void> init() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    // Ensure we use the local timezone
    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      Logger.error('Error setting timezone: $e');
      // Even if we can't determine the timezone name, we'll use local time
    }

    // Initialize translation service for background notifications
    try {
      await _translationService.initialize();
    } catch (e) {
      Logger.error('AndroidReminderService: Error initializing translation service: $e');
    }

    // Set up boot completed event listener
    _bootCompletedChannel.setMethodCallHandler(_handleBootCompletedEvent);
  }

  @override
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!(await _notificationService.isEnabled())) {
      Logger.debug('Notifications are disabled');
      return;
    }

    // Check for exact alarm permission on Android 12+
    final hasPermission = await _checkExactAlarmPermission();
    if (!hasPermission) {
      Logger.warning('No exact alarm permission on Android 12+ - notifications may not fire exactly on time');
      // Continue anyway to use fallback scheduling methods
    }

    // Ensure the scheduled date is converted to local time properly
    final localScheduledDate = DateTimeHelper.toLocalDateTime(scheduledDate);

    // Get current time in the same timezone context for consistent comparison
    final now = DateTime.now();

    if (localScheduledDate.isBefore(now)) {
      Logger.debug('Scheduled date $localScheduledDate is in the past (current: $now)');
      return;
    }

    // Translate title and body to current app language
    final translatedTitle = _translateText(title, payload);
    final translatedBody = _translateText(body, payload);

    // Convert string ID to numeric ID using consistent method
    final notificationId = _getNotificationIdFromReminderId(id);

    // Calculate delay using consistent timezone handling
    // Use milliseconds for higher precision, then convert to seconds
    final delayMillis = localScheduledDate.difference(now).inMilliseconds;
    final int delaySeconds = (delayMillis / 1000).round();

    // Log the scheduling details for debugging timezone issues
    Logger.debug('Scheduling notification: $id');
    Logger.debug('- Original scheduled date: $scheduledDate');
    Logger.debug('- Local scheduled date: $localScheduledDate');
    Logger.debug('- Current time: $now');
    Logger.debug('- Delay: ${delaySeconds}s (${delayMillis}ms)');

    // Validate delay is reasonable
    if (delaySeconds <= 0) {
      Logger.warning('Calculated delay is non-positive: ${delaySeconds}s, skipping notification');
      return;
    }

    // Validate delay is not too far in the future (prevent overflow issues)
    const maxDelayDays = 365; // 1 year maximum
    const maxDelaySeconds = maxDelayDays * 24 * 60 * 60;
    if (delaySeconds > maxDelaySeconds) {
      Logger.warning(
          'Calculated delay is too far in future: ${delaySeconds}s (${delaySeconds / (24 * 60 * 60)} days), skipping notification');
      return;
    }

    // Translate action button text if payload contains taskId or habitId
    String? actionButtonText;
    if (payload != null && (payload.contains('taskId') || payload.contains('habitId'))) {
      actionButtonText = _translateText('shared.buttons.done', payload);
    }

    try {
      final success = await _scheduleNotification(
        id: notificationId,
        title: translatedTitle,
        body: translatedBody,
        delaySeconds: delaySeconds,
        payload: payload,
        reminderId: id, // Pass the original string ID for pattern matching
        actionButtonText: actionButtonText,
      );

      if (!success) {
        Logger.error('AndroidReminderService: Failed to schedule notification: $id');
      } else {
        Logger.debug(
            'Successfully scheduled notification: $id for ${DateTime.now().add(Duration(seconds: delaySeconds))}');
      }
    } catch (e) {
      Logger.error('AndroidReminderService: Error scheduling reminder $id: $e');
    }
  }

  /// Schedule a notification to be shown after a delay using native Android APIs
  Future<bool> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int delaySeconds,
    String? payload,
    String? reminderId,
    String? actionButtonText,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      // Enhance payload with reminderId for pattern-based cancellation
      String? enhancedPayload = payload;
      if (reminderId != null) {
        try {
          Map<String, dynamic> payloadData = {};

          // Parse existing payload if it's JSON
          if (payload != null && payload.isNotEmpty) {
            try {
              payloadData = jsonDecode(payload);
            } catch (e) {
              // If payload is not JSON, wrap it
              payloadData = {'originalPayload': payload};
            }
          }

          // Add reminderId for pattern matching
          payloadData['reminderId'] = reminderId;
          enhancedPayload = jsonEncode(payloadData);
        } catch (e) {
          // Failed to enhance payload, continue with original
        }
      }

      final result = await _notificationChannel.invokeMethod<bool>('scheduleDirectNotification', {
        'id': id,
        'title': title,
        'body': body,
        'payload': enhancedPayload,
        'delaySeconds': delaySeconds,
        'actionButtonText': actionButtonText,
      });

      return result ?? false;
    } catch (e) {
      Logger.error('Error scheduling notification: $e');
      return false;
    }
  }

  @override
  Future<void> scheduleRecurringReminder({
    required String id,
    required String title,
    required String body,
    required TimeOfDay time,
    required List<int> days,
    String? payload,
  }) async {
    if (!(await _notificationService.isEnabled())) {
      return;
    }

    // Check if we have any days to schedule
    if (days.isEmpty) {
      return;
    }

    // Check for exact alarm permission on Android 12+
    final hasPermission = await _checkExactAlarmPermission();
    if (!hasPermission) {
      Logger.warning('No exact alarm permission on Android 12+ - recurring notifications may not fire exactly on time');
      // Continue anyway to use fallback scheduling methods
    }

    // Translate title and body to current app language
    final translatedTitle = _translateText(title, payload);
    final translatedBody = _translateText(body, payload);

    // Translate action button text if payload contains taskId or habitId
    String? actionButtonText;
    if (payload != null && (payload.contains('taskId') || payload.contains('habitId'))) {
      actionButtonText = _translateText('shared.buttons.done', payload);
    }

    // Schedule a notification for each day of the week within the current week period
    for (final day in days) {
      // Create a unique ID for each day by combining base ID with day
      final daySpecificId = '${id}_day_$day';
      final notificationId = _getNotificationIdFromReminderId(daySpecificId);

      // Calculate the next occurrence of this day and time
      final scheduledDate = _getNextOccurrence(day, time);

      // Only schedule if the occurrence is within the current week period (next 7 days)
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));

      if (scheduledDate.isAfter(weekFromNow)) {
        continue; // Don't schedule beyond current week period
      }

      try {
        // Calculate seconds until the notification should be shown
        final int delaySeconds = scheduledDate.difference(now).inSeconds;

        // Use our own notification service for the first occurrence
        await _scheduleNotification(
          id: notificationId,
          title: translatedTitle,
          body: translatedBody,
          delaySeconds: delaySeconds,
          payload: payload,
          reminderId: daySpecificId, // Pass the day-specific ID for pattern matching
          actionButtonText: actionButtonText,
        );
      } catch (e) {
        Logger.error('Error scheduling recurring reminder: $e');
      }
    }
  }

  /// Calculate the next occurrence of a specific day of the week and time
  DateTime _getNextOccurrence(int day, TimeOfDay time) {
    // Get current time in local timezone
    final now = DateTimeHelper.toLocalDateTime(DateTime.now());

    // Create a DateTime in local time for the specified time today
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Calculate days to add to reach the target day
    int daysToAdd = day - scheduledDate.weekday;

    // If the target day is earlier in the week or the same day but time has passed,
    // move to next week
    if (daysToAdd < 0 || (daysToAdd == 0 && scheduledDate.isBefore(now))) {
      daysToAdd += 7;
    }

    // Add the days
    scheduledDate = scheduledDate.add(Duration(days: daysToAdd));

    return scheduledDate;
  }

  @override
  Future<void> cancelReminder(String id) async {
    if (!Platform.isAndroid) return;

    try {
      // Convert the string ID to a numeric ID if needed
      final int notificationId = _getNotificationIdFromReminderId(id);

      // Call the native method to cancel the notification with the given ID
      final result = await _notificationChannel.invokeMethod<bool>('cancelNotification', {
        'id': notificationId,
      });

      if (result == false) {
        Logger.error('AndroidReminderService: Failed to cancel notification with ID: $id');
      }
    } catch (e) {
      Logger.error('AndroidReminderService: Error canceling reminder $id: $e');
    }
  }

  /// Converts a string reminder ID to a notification ID
  /// If the ID is already numeric, it will be parsed
  /// Otherwise, a consistent hash code will be generated
  int _getNotificationIdFromReminderId(String id) {
    try {
      final numericId = int.parse(id);
      return numericId;
    } catch (e) {
      // If the ID is not a number, use a consistent hash code
      // This ensures the same string ID always maps to the same numeric ID
      final hashId = id.hashCode.abs() % 2147483647; // Keep within int32 range
      return hashId;
    }
  }

  @override
  Future<void> cancelReminders({
    bool Function(String id)? idFilter,
    String? startsWith,
    String? contains,
    String? equals,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      // Case 1: Cancel by exact ID match
      if (equals != null) {
        await cancelReminder(equals);
        return;
      }

      // Case 2: We need to handle pattern matching on the Android side
      if (startsWith != null || contains != null || idFilter != null) {
        // First try to cancel using the native Android API with pattern matching
        bool nativeHandled = false;

        try {
          final params = <String, dynamic>{};
          if (startsWith != null) params['startsWith'] = startsWith;
          if (contains != null) params['contains'] = contains;

          final result = await _notificationChannel.invokeMethod<bool>('cancelNotificationsWithPattern', params);
          nativeHandled = result ?? false;
        } catch (e) {
          // Native method not implemented or failed
          nativeHandled = false;
        }

        // If native handling worked, we're done
        if (nativeHandled) {
          return;
        }

        // If native handling didn't work, fall back to retrieving active notification IDs
        // and filtering them manually
        try {
          final activeNotificationIds = await _getActiveReminderIds();

          for (final id in activeNotificationIds) {
            bool shouldCancel = false;

            // Apply filters
            if (startsWith != null && id.startsWith(startsWith)) {
              shouldCancel = true;
            }
            if (contains != null && id.contains(contains)) {
              shouldCancel = true;
            }
            if (idFilter != null && idFilter(id)) {
              shouldCancel = true;
            }

            if (shouldCancel) {
              await cancelReminder(id);
            }
          }
        } catch (e) {
          Logger.error('Error in fallback pattern cancellation: $e');
        }
      }
    } catch (e) {
      Logger.error('Error canceling reminders by filter: $e');
    }
  }

  /// Retrieves a list of active reminder IDs
  /// This is a fallback mechanism when native pattern matching is not available
  Future<List<String>> _getActiveReminderIds() async {
    try {
      final result = await _notificationChannel.invokeMethod<List<dynamic>>('getActiveNotificationIds');
      if (result != null) {
        return result.map((id) => id.toString()).toList();
      }
    } catch (e) {
      Logger.error('Error retrieving active notification IDs: $e');
      // If we can't get the active IDs from the native side,
      // return an empty list as fallback
    }
    return [];
  }

  @override
  Future<void> cancelAllReminders() async {
    if (!Platform.isAndroid) return;

    try {
      // Call the native method to cancel all scheduled notifications
      final result = await _notificationChannel.invokeMethod<bool>('cancelAllNotifications');

      if (result == false) {
        Logger.error('Failed to cancel all notifications');
      }
    } catch (e) {
      Logger.error('Error canceling all reminders: $e');
    }
  }

  /// Method to handle boot completed event and potentially refresh reminders
  @override
  Future<void> onBootCompleted() async {
    try {
      // Check if notifications are enabled
      if (!(await _notificationService.isEnabled())) {
        return;
      }

      // Check for exact alarm permission on Android 12+
      final hasPermission = await _checkExactAlarmPermission();
      if (!hasPermission) {
        return;
      }
    } catch (e) {
      Logger.error('Error handling boot completed event: $e');
    }
  }

  /// Handle boot completed events from native Android code
  Future<void> _handleBootCompletedEvent(MethodCall call) async {
    switch (call.method) {
      case 'onBootCompleted':
        await onBootCompleted();
        break;
      default:
        Logger.warning('Unknown boot completed method: ${call.method}');
    }
  }

  /// Helper method to translate text with payload arguments
  String _translateText(String text, String? payload) {
    // Check if the text is already translated (i.e., doesn't look like a translation key)
    // If it doesn't contain dots and doesn't start with common key prefixes, it's likely already translated
    if (!text.contains('.') &&
        !text.startsWith('tasks.') &&
        !text.startsWith('habits.') &&
        !text.startsWith('shared.')) {
      return text;
    }

    try {
      // Check if we can extract named arguments from payload
      Map<String, String>? namedArgs;
      if (payload != null && payload.isNotEmpty) {
        try {
          final payloadData = jsonDecode(payload);
          if (payloadData is Map<String, dynamic>) {
            // Convert all values to strings for named arguments
            namedArgs = payloadData.map((key, value) => MapEntry(key, value.toString()));
          }
        } catch (e) {
          // Payload is not JSON, ignore
        }
      }

      final translatedText = _translationService.translate(text, namedArgs: namedArgs);
      return translatedText;
    } catch (e) {
      Logger.error('AndroidReminderService: Error translating text "$text": $e');
      return text; // Return original text if translation fails
    }
  }

  /// Check if the app has permission to schedule exact alarms on Android 12+
  Future<bool> _checkExactAlarmPermission() async {
    try {
      // Get Android version
      bool isAndroid12Plus = false;
      try {
        final deviceInfoPlugin = DeviceInfoPlugin();
        final androidInfo = await deviceInfoPlugin.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        isAndroid12Plus = sdkInt >= 31; // Android 12 is API level 31
        Logger.debug('Android API level: $sdkInt, requires exact alarm permission: $isAndroid12Plus');
      } catch (e) {
        Logger.error('Error checking Android version: $e');
      }

      // If not Android 12+, we don't need this permission
      if (!isAndroid12Plus) {
        Logger.debug('Android version < 12, exact alarm permission not required');
        return true;
      }

      // Check for exact alarm permission
      final platform = MethodChannel(AndroidAppConstants.channels.exactAlarm);
      final bool hasPermission = await platform.invokeMethod('canScheduleExactAlarms');

      Logger.debug('Exact alarm permission check result: $hasPermission');
      return hasPermission;
    } catch (e) {
      Logger.error('Error checking exact alarm permission: $e');
      // If we can't check, assume we don't have permission to use fallback methods
      return false;
    }
  }
}
