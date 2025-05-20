import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/infrastructure/features/window/abstractions/i_window_manager.dart';
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_reminder_service.dart';

/// Implementation of the reminder service for desktop platforms
class DesktopReminderService implements IReminderService {
  final IWindowManager _windowManager;
  final INotificationService _notificationService;

  // Store active timers for scheduled notifications
  final Map<String, Timer> _scheduledTimers = {};

  // Store active notification IDs
  final Map<String, int> _activeNotificationIds = {};

  DesktopReminderService(IWindowManager windowManager, INotificationService notificationService)
      : _windowManager = windowManager,
        _notificationService = notificationService;

  @override
  Future<void> init() async {}

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

    // Cancel any existing timer for this ID
    _cancelTimer(id);

    // Calculate delay until the scheduled time
    final now = DateTime.now();
    final delay = scheduledDate.difference(now);

    // Only schedule if the time is in the future
    if (delay.isNegative) {
      if (kDebugMode) debugPrint('Scheduled date is in the past');
      return;
    }

    // Schedule a timer to show the notification at the specified time
    _scheduledTimers[id] = Timer(delay, () {
      _showNotification(id, title, body, payload);
    });
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
      // If no days are provided, use all days
      days = List.generate(7, (index) => index + 1); // 1-7 (Monday-Sunday)
    }

    // For each day, schedule the next occurrence
    for (final day in days) {
      final reminderKey = '${id}_day_$day';

      // Cancel any existing timer for this day
      _cancelTimer(reminderKey);

      try {
        // Calculate the next occurrence
        final nextOccurrence = _getNextOccurrence(day, time);

        // Calculate delay until the next occurrence
        final now = DateTime.now();
        final delay = nextOccurrence.difference(now);

        // Schedule a timer to show the notification
        _scheduledTimers[reminderKey] = Timer(delay, () {
          _showNotification(reminderKey, title, body, payload);

          // Reschedule for next week
          scheduleRecurringReminder(
            id: id,
            title: title,
            body: body,
            time: time,
            days: [day], // Only reschedule this specific day
            payload: payload,
          );
        });
      } catch (e) {
        if (kDebugMode) debugPrint('Error scheduling recurring reminder: $e');
      }
    }
  }

  /// Calculate the next occurrence of a specific day of the week and time
  DateTime _getNextOccurrence(int day, TimeOfDay time) {
    // Use local time for scheduling
    final now = DateTime.now();

    // Create a DateTime for the specified time today in local time
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

  /// Show a notification using the notification service
  Future<void> _showNotification(String id, String title, String body, String? payload) async {
    if (!(await _notificationService.isEnabled())) {
      if (kDebugMode) debugPrint('Notifications are disabled, not showing notification');
      return;
    }

    try {
      // Generate a unique notification ID
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      // Store the active notification ID for future reference
      _activeNotificationIds[id] = notificationId;

      // Show the notification using the notification service
      await _notificationService.show(title: title, body: body, payload: payload, id: notificationId);

      // Ensure the window is visible for desktop platforms
      await _ensureWindowVisible();
    } catch (e) {
      if (kDebugMode) debugPrint('Error showing notification: $e');
    }
  }

  /// Ensure the app window is visible and focused for desktop platforms
  Future<void> _ensureWindowVisible() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      if (!await _windowManager.isVisible()) {
        await _windowManager.show();
      }
      await _windowManager.focus();
    }
  }

  /// Cancel an active timer
  void _cancelTimer(String id) {
    final timer = _scheduledTimers[id];
    if (timer != null && timer.isActive) {
      timer.cancel();
      _scheduledTimers.remove(id);
    }
  }

  @override
  Future<void> cancelReminder(String id) async {
    // Cancel the timer if it exists
    _cancelTimer(id);

    // Cancel the notification if it's active
    final notificationId = _activeNotificationIds[id];
    if (notificationId != null) {
      // Remove from active IDs
      _activeNotificationIds.remove(id);
    }
  }

  @override
  Future<void> cancelReminders({
    bool Function(String id)? idFilter,
    String? startsWith,
    String? contains,
    String? equals,
  }) async {
    // Build a list of keys to remove based on the provided filters
    final keysToRemove = <String>[];

    for (final key in _scheduledTimers.keys) {
      bool shouldRemove = false;

      // Apply custom filter if provided
      if (idFilter != null && idFilter(key)) {
        shouldRemove = true;
      }

      // Check startsWith filter
      if (startsWith != null && key.startsWith(startsWith)) {
        shouldRemove = true;
      }

      // Check contains filter
      if (contains != null && key.contains(contains)) {
        shouldRemove = true;
      }

      // Check equals filter
      if (equals != null && key == equals) {
        shouldRemove = true;
      }

      if (shouldRemove) {
        keysToRemove.add(key);
      }
    }

    // Cancel all matching reminders
    for (final key in keysToRemove) {
      await cancelReminder(key);
    }
  }

  @override
  Future<void> cancelAllReminders() async {
    // Cancel all timers
    for (final timer in _scheduledTimers.values) {
      if (timer.isActive) {
        timer.cancel();
      }
    }
    _scheduledTimers.clear();
    _activeNotificationIds.clear();
  }
}
