import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/application/shared/utils/key_helper.dart' as application;

/// Implementation of the reminder service for Android platforms using native APIs
class AndroidReminderService implements IReminderService {
  final INotificationService _notificationService;

  // Method channel for native communication
  static final MethodChannel _notificationChannel = MethodChannel(AndroidAppConstants.channels.notification);

  AndroidReminderService(this._notificationService);

  @override
  Future<void> init() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    // Ensure we use the local timezone
    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      if (kDebugMode) debugPrint('Error setting timezone: $e');
      // Even if we can't determine the timezone name, we'll use local time
    }
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
      if (kDebugMode) debugPrint('Notifications are disabled');
      return;
    }

    // Check for exact alarm permission on Android 12+
    final hasPermission = await _checkExactAlarmPermission();
    if (!hasPermission) {
      if (kDebugMode) debugPrint('No exact alarm permission on Android 12+');
      return;
    }

    // Ensure the scheduled date is in local time
    final localScheduledDate = DateTimeHelper.toLocalDateTime(scheduledDate);

    // Compare with local time
    final now = DateTime.now();
    if (localScheduledDate.isBefore(now)) {
      if (kDebugMode) debugPrint('Scheduled date is in the past');
      return;
    }

    final notificationId = application.KeyHelper.generateNumericId();

    // Calculate seconds until the notification should be shown using local time
    final int delaySeconds = localScheduledDate.difference(DateTime.now()).inSeconds;

    try {
      final success = await _scheduleNotification(
        id: notificationId,
        title: title,
        body: body,
        delaySeconds: delaySeconds,
        payload: payload,
      );

      if (!success) {
        if (kDebugMode) debugPrint('Failed to schedule notification');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error scheduling reminder: $e');
    }
  }

  /// Schedule a notification to be shown after a delay using native Android APIs
  Future<bool> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int delaySeconds,
    String? payload,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      // Format payload as JSON if needed

      final result = await _notificationChannel.invokeMethod<bool>('scheduleDirectNotification', {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
        'delaySeconds': delaySeconds,
      });

      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('Error scheduling notification: $e');
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
    await _checkExactAlarmPermission();

    // Schedule a notification for each day of the week
    for (final day in days) {
      final notificationId = application.KeyHelper.generateNumericId();

      // Calculate the next occurrence of this day and time
      final scheduledDate = _getNextOccurrence(day, time);

      try {
        // Calculate seconds until the notification should be shown
        final now = DateTime.now();
        final int delaySeconds = scheduledDate.difference(now).inSeconds;

        // Use our own notification service for the first occurrence
        await _scheduleNotification(
          id: notificationId,
          title: title,
          body: body,
          delaySeconds: delaySeconds,
          payload: payload,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Error scheduling recurring reminder: $e');
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
        if (kDebugMode) debugPrint('Failed to cancel notification with ID: $id');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error canceling reminder: $e');
    }
  }

  /// Converts a string reminder ID to a notification ID
  /// If the ID is already numeric, it will be parsed
  /// Otherwise, a hash code will be generated
  int _getNotificationIdFromReminderId(String id) {
    try {
      return int.parse(id);
    } catch (e) {
      // If the ID is not a number, use its hash code
      return application.KeyHelper.generateNumericId();
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
          if (kDebugMode) debugPrint('Error using native pattern cancellation: $e');
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
          if (kDebugMode) debugPrint('Error in fallback pattern cancellation: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error canceling reminders by filter: $e');
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
      if (kDebugMode) debugPrint('Error retrieving active notification IDs: $e');
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
        if (kDebugMode) debugPrint('Failed to cancel all notifications');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error canceling all reminders: $e');
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
      } catch (e) {
        if (kDebugMode) debugPrint('Error checking Android version: $e');
      }

      // If not Android 12+, we don't need this permission
      if (!isAndroid12Plus) {
        return true;
      }

      // Check for exact alarm permission
      final platform = MethodChannel(AndroidAppConstants.channels.exactAlarm);
      final bool hasPermission = await platform.invokeMethod('canScheduleExactAlarms');

      return hasPermission;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking exact alarm permission: $e');
      // If we can't check, assume we have permission to avoid blocking functionality
      return true;
    }
  }
}
