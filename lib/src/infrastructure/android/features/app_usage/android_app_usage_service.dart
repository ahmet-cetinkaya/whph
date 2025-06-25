import 'dart:async';
import 'package:app_usage/app_usage.dart' as app_usage_package;
import 'package:flutter/services.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/base_app_usage_service.dart';
import 'package:whph/src/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

class AndroidAppUsageService extends BaseAppUsageService {
  static final platform = MethodChannel(AndroidAppConstants.channels.backgroundService);
  static final appUsageStatsChannel = MethodChannel(AndroidAppConstants.channels.appUsageStats);
  final app_usage_package.AppUsage _appUsage = app_usage_package.AppUsage();

  AndroidAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
    super.appUsageIgnoreRuleRepository,
  );

  @override
  Future<void> startTracking() async {
    final hasPermission = await checkUsageStatsPermission();
    if (!hasPermission) {
      Logger.warning('Usage stats permission not granted. Cannot start tracking.');
      return;
    }

    await _startBackgroundService();

    // Initial fetch for the current partial hour to capture immediate usage.
    await _fetchAndSaveCurrentHourUsage();

    // Schedule the next fetch near the end of the current hour, and subsequent hours.
    _scheduleNextEndOfHourFetch();
  }

  void _scheduleNextEndOfHourFetch() {
    periodicTimer?.cancel(); // Cancel any existing timer.

    DateTime now = DateTime.now();
    // Target time for fetching: 59 minutes and 30 seconds past the hour.
    // This allows capturing most of the hour's data before it ends.
    DateTime targetFetchTimeThisHour = DateTime(now.year, now.month, now.day, now.hour, 59, 30);

    Duration delay;
    if (now.isBefore(targetFetchTimeThisHour)) {
      // If current time is before HH:59:30, schedule for HH:59:30 of current hour.
      delay = targetFetchTimeThisHour.difference(now);
    } else {
      // If current time is already past HH:59:30 (or exactly at/after it),
      // schedule for HH:59:30 of the *next* hour.
      DateTime targetFetchTimeNextHour = DateTime(now.year, now.month, now.day, now.hour + 1, 59, 30);
      delay = targetFetchTimeNextHour.difference(now);
    }

    // Ensure the delay is not negative or too short (e.g., if calculations took time).
    // Schedule at least a few seconds into the future.
    if (delay.isNegative || delay.inSeconds < 5) {
      delay = const Duration(seconds: 5);
      Logger.info('Calculated delay for end-of-hour fetch was too short or negative. Scheduling in 5 seconds.');
    }

    periodicTimer = Timer(delay, () async {
      final permissionCheck = await checkUsageStatsPermission();
      if (permissionCheck) {
        await _fetchAndSaveCurrentHourUsage();
        _scheduleNextEndOfHourFetch(); // Reschedule for the end of the next hour.
      } else {
        Logger.warning('Permission lost. Pausing app usage tracking. Timer will not reschedule.');
        // Do not reschedule if permission is lost.
      }
    });
    DateTime scheduledRunTime = now.add(delay);
    Logger.info('Next app usage fetch scheduled to run around: $scheduledRunTime');
  }

  /// Fetches app usage for the current calendar hour up to DateTime.now()
  /// and saves the records. This is called initially and by the recurring timer.
  Future<void> _fetchAndSaveCurrentHourUsage() async {
    // Permission should have been checked by the caller (startTracking or timer callback).
    try {
      DateTime now = DateTime.now();
      DateTime startDate = DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0, 0); // Start of current hour.
      DateTime endDate = now; // Up to the current moment.

      // Ensure startDate is before endDate to form a valid interval.
      if (!startDate.isBefore(endDate)) {
        Logger.info('Skipping app usage fetch: interval is zero or negative. Start: $startDate, End: $endDate.');
        return;
      }

      Logger.info('Fetching app usages from $startDate to $endDate');
      List<app_usage_package.AppUsageInfo> usageStats = await _appUsage.getAppUsage(startDate, endDate);

      if (usageStats.isEmpty) {
        Logger.info('No app usage stats found for the period $startDate - $endDate.');
      }

      for (app_usage_package.AppUsageInfo usage in usageStats) {
        if (usage.usage.inSeconds > 0) {
          // Assuming saveTimeRecord saves for the hour of DateTime.now().
          // Since 'now.hour' (used by saveTimeRecord implicitly) matches 'startDate.hour',
          // the data is attributed to the correct hour. 'overwrite: true' updates the record.
          await saveTimeRecord(usage.appName, usage.usage.inSeconds, overwrite: true);
        } else if (usage.usage.inSeconds < 0) {
          Logger.warning(
              'Negative app usage duration for ${usage.appName} (${usage.usage.inSeconds}s). Skipping record.');
        }
        // Usage with 0 seconds is implicitly ignored.
      }
    } catch (e) {
      // Log error with current time context as 'now' is local to this call.
      Logger.error('Error in _fetchAndSaveCurrentHourUsage around ${DateTime.now()}: $e');
    }
  }

  @override
  Future<void> stopTracking() async {
    periodicTimer?.cancel();
    periodicTimer = null; // Clear the timer instance.
    Logger.info('Android app usage tracking stopped and timer cancelled.');
    // If BaseAppUsageService has its own stopTracking, consider calling super.stopTracking().
    // e.g., await super.stopTracking();
  }

  /// Checks if the app has permission to access usage statistics
  /// Returns true if permission is granted, false otherwise
  @override
  Future<bool> checkUsageStatsPermission() async {
    try {
      // Check usage statistics permission from Kotlin side
      final hasPermission = await appUsageStatsChannel.invokeMethod<bool>('checkUsageStatsPermission');
      return hasPermission ?? false;
    } catch (e) {
      Logger.error('Error checking usage stats permission: $e');

      // Use backup check in case of method channel error
      try {
        // Try to fetch data for a small time range as backup
        await _appUsage.getAppUsage(
          DateTime.now().subtract(const Duration(minutes: 5)),
          DateTime.now(),
        );
        return true;
      } catch (backupError) {
        Logger.error('Backup permission check failed: $backupError');
        return false;
      }
    }
  }

  /// Opens the settings page to request usage statistics permission
  /// This should be called when user interaction is appropriate (e.g., after a user clicks a button)
  @override
  Future<void> requestUsageStatsPermission() async {
    try {
      // Open usage access settings page
      await appUsageStatsChannel.invokeMethod('openUsageAccessSettings');
    } catch (e) {
      Logger.error('Error requesting usage stats permission: $e');
    }
  }

  Future<void> _startBackgroundService() async {
    try {
      await platform.invokeMethod('startBackgroundService');
    } catch (e) {
      Logger.error('Failed to start background service: $e');
    }
  }
}
