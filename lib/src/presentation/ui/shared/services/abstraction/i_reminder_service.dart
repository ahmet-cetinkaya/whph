import 'package:flutter/material.dart';

/// Interface for the reminder service
abstract class IReminderService {
  /// Initialize the reminder service
  Future<void> init();

  /// Schedule a reminder for a future date and time
  ///
  /// [id] - Unique identifier for the reminder
  /// [title] - Title of the notification
  /// [body] - Body text of the notification
  /// [scheduledDate] - When the notification should be shown
  /// [payload] - Optional data to pass with the notification
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  });

  /// Schedule a recurring reminder for specific days of the week
  ///
  /// [id] - Unique identifier for the reminder
  /// [title] - Title of the notification
  /// [body] - Body text of the notification
  /// [time] - Time of day when the notification should be shown
  /// [days] - Days of the week when the notification should be shown (1-7, where 1 is Monday)
  /// [payload] - Optional data to pass with the notification
  Future<void> scheduleRecurringReminder({
    required String id,
    required String title,
    required String body,
    required TimeOfDay time,
    required List<int> days,
    String? payload,
  });

  /// Cancel a specific reminder
  ///
  /// [id] - Identifier of the reminder to cancel
  Future<void> cancelReminder(String id);

  /// Cancel reminders based on ID pattern
  ///
  /// [idFilter] - Optional filter function to match reminder IDs
  /// [startsWith] - Optional prefix to match reminder IDs that start with this string
  /// [contains] - Optional substring to match reminder IDs that contain this string
  /// [equals] - Optional exact match for reminder IDs
  ///
  /// At least one of the filter parameters should be provided
  Future<void> cancelReminders({
    bool Function(String id)? idFilter,
    String? startsWith,
    String? contains,
    String? equals,
  });

  /// Cancel all scheduled notifications
  Future<void> cancelAllReminders();

  /// Handle boot completed event - reschedule or refresh reminders if needed
  Future<void> onBootCompleted();
}
