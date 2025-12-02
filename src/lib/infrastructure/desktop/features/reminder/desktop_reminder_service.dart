import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/infrastructure/shared/features/window/abstractions/i_window_manager.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Configuration for a recurring reminder
class _RecurringReminderConfig {
  final String id;
  final String title;
  final String body;
  final TimeOfDay time;
  final List<int> days;
  final String? payload;

  _RecurringReminderConfig({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.days,
    this.payload,
  });
}

/// Implementation of the reminder service for desktop platforms
class DesktopReminderService implements IReminderService {
  final IWindowManager _windowManager;
  final INotificationService _notificationService;

  // Store active timers for scheduled notifications
  final Map<String, Timer> _scheduledTimers = {};

  // Store active notification IDs
  final Map<String, int> _activeNotificationIds = {};

  // Store recurring reminder configurations for weekly refresh
  final Map<String, _RecurringReminderConfig> _recurringReminders = {};

  // Weekly refresh timer
  Timer? _weeklyRefreshTimer;

  DesktopReminderService(IWindowManager windowManager, INotificationService notificationService)
      : _windowManager = windowManager,
        _notificationService = notificationService;

  @override
  Future<void> init() async {
    // Start the weekly refresh mechanism
    _startWeeklyRefresh();
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

    // Cancel any existing timer for this ID
    _cancelTimer(id);

    // Calculate delay until the scheduled time
    final now = DateTime.now();
    final delay = scheduledDate.difference(now);

    // Only schedule if the time is in the future
    if (delay.isNegative) {
      Logger.debug('Scheduled date is in the past');
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

    // Store the recurring reminder configuration for future refreshes
    _recurringReminders[id] = _RecurringReminderConfig(
      id: id,
      title: title,
      body: body,
      time: time,
      days: days,
      payload: payload,
    );

    // Schedule the reminders for this week period
    await _scheduleReminderForCurrentWeek(id, title, body, time, days, payload);
  }

  /// Schedule reminders for the current week period only
  Future<void> _scheduleReminderForCurrentWeek(
    String id,
    String title,
    String body,
    TimeOfDay time,
    List<int> days,
    String? payload,
  ) async {
    // For each day, schedule only the next occurrence within the current week period
    for (final day in days) {
      final reminderKey = '${id}_day_$day';

      // Cancel any existing timer for this day
      _cancelTimer(reminderKey);

      try {
        // Calculate the next occurrence within the current week period
        final nextOccurrence = _getNextOccurrenceInCurrentWeek(day, time);

        // Only schedule if the occurrence is within the current week period
        if (nextOccurrence != null) {
          // Calculate delay until the next occurrence
          final now = DateTime.now();
          final delay = nextOccurrence.difference(now);

          // Schedule a timer to show the notification
          _scheduledTimers[reminderKey] = Timer(delay, () {
            _showNotification(reminderKey, title, body, payload);
            // Note: No automatic rescheduling - this will be handled by the weekly refresh mechanism
          });
        }
      } catch (e) {
        Logger.error('Error scheduling recurring reminder: $e');
      }
    }
  }

  /// Calculate the next occurrence of a specific day of the week and time within the current week period
  /// Returns null if no occurrence is available within the current week period
  DateTime? _getNextOccurrenceInCurrentWeek(int day, TimeOfDay time) {
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

    // Check if the scheduled date is within the current week period (next 7 days)
    final weekFromNow = now.add(const Duration(days: 7));
    if (scheduledDate.isAfter(weekFromNow)) {
      return null; // Don't schedule beyond current week period
    }

    return scheduledDate;
  }

  /// Start the weekly refresh mechanism
  void _startWeeklyRefresh() {
    // Cancel any existing weekly refresh timer
    _weeklyRefreshTimer?.cancel();

    // Calculate time until next Monday at 00:00
    final now = DateTime.now();
    final nextMonday = _getNextMonday(now);
    final delayUntilMonday = nextMonday.difference(now);

    // Schedule the first refresh at the start of next week
    _weeklyRefreshTimer = Timer(delayUntilMonday, () {
      _refreshAllRecurringReminders();

      // Set up a weekly periodic timer
      _weeklyRefreshTimer = Timer.periodic(const Duration(days: 7), (_) {
        _refreshAllRecurringReminders();
      });
    });
  }

  /// Get the next Monday at 00:00
  DateTime _getNextMonday(DateTime from) {
    final currentWeekday = from.weekday; // 1 = Monday, 7 = Sunday
    int daysUntilMonday = 8 - currentWeekday; // Days until next Monday
    if (daysUntilMonday == 8) daysUntilMonday = 7; // If today is Monday, next Monday is in 7 days

    final nextMonday = DateTime(from.year, from.month, from.day, 0, 0, 0, 0).add(Duration(days: daysUntilMonday));

    return nextMonday;
  }

  /// Refresh all recurring reminders for the new week
  void _refreshAllRecurringReminders() {
    Logger.debug('DesktopReminderService: Refreshing all recurring reminders for new week');

    for (final config in _recurringReminders.values) {
      _scheduleReminderForCurrentWeek(
        config.id,
        config.title,
        config.body,
        config.time,
        config.days,
        config.payload,
      );
    }
  }

  /// Show a notification using the notification service
  Future<void> _showNotification(String id, String title, String body, String? payload) async {
    if (!(await _notificationService.isEnabled())) {
      Logger.debug('Notifications are disabled, not showing notification');
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
      Logger.error('Error showing notification: $e');
    }
  }

  /// Ensure the app window is visible and focused for desktop platforms
  Future<void> _ensureWindowVisible() async {
    if (PlatformUtils.isDesktop) {
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

    // Also remove matching recurring reminder configurations
    final configKeysToRemove = <String>[];
    for (final configKey in _recurringReminders.keys) {
      bool shouldRemove = false;

      // Apply custom filter if provided
      if (idFilter != null && idFilter(configKey)) {
        shouldRemove = true;
      }

      // Check startsWith filter
      if (startsWith != null && configKey.startsWith(startsWith)) {
        shouldRemove = true;
      }

      // Check contains filter
      if (contains != null && configKey.contains(contains)) {
        shouldRemove = true;
      }

      // Check equals filter
      if (equals != null && configKey == equals) {
        shouldRemove = true;
      }

      if (shouldRemove) {
        configKeysToRemove.add(configKey);
      }
    }

    // Remove matching configurations
    for (final configKey in configKeysToRemove) {
      _recurringReminders.remove(configKey);
    }

    Logger.debug(
        ' DesktopReminderService: Cancelled ${keysToRemove.length} scheduled reminders and ${configKeysToRemove.length} recurring configurations');
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

    // Clear all recurring reminder configurations
    _recurringReminders.clear();

    // Cancel the weekly refresh timer
    _weeklyRefreshTimer?.cancel();
    _weeklyRefreshTimer = null;

    Logger.debug('DesktopReminderService: Cancelled all reminders and cleared all configurations');
  }

  @override
  Future<void> onBootCompleted() async {
    Logger.debug('DesktopReminderService: Boot completed event received (not applicable for desktop)');
    // Desktop platforms don't need special boot handling since timers are recreated on app start
  }
}
