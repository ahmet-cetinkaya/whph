import 'dart:async';
import 'package:app_usage/app_usage.dart' as app_usage_package;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:whph/application/features/app_usages/services/abstraction/base_app_usage_service.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';

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
    // Check permission before starting tracking
    final hasPermission = await checkUsageStatsPermission();
    if (!hasPermission) {
      if (kDebugMode) debugPrint('Usage stats permission not granted. Cannot start tracking.');
      return;
    }

    await _startBackgroundService();
    await _getAppUsages();

    periodicTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      final permissionCheck = await checkUsageStatsPermission();
      if (permissionCheck) {
        await _getAppUsages();
      } else {
        if (kDebugMode) debugPrint('Permission lost. Pausing app usage tracking.');
        // Optionally notify the user that tracking has been paused
      }
    });
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
      if (kDebugMode) debugPrint('Error checking usage stats permission: $e');

      // Use backup check in case of method channel error
      try {
        // Try to fetch data for a small time range as backup
        await _appUsage.getAppUsage(
          DateTime.now().subtract(const Duration(minutes: 5)),
          DateTime.now(),
        );
        return true;
      } catch (backupError) {
        if (kDebugMode) debugPrint('Backup permission check failed: $backupError');
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
      if (kDebugMode) debugPrint('Error requesting usage stats permission: $e');
    }
  }

  Future<void> _startBackgroundService() async {
    try {
      await platform.invokeMethod('startBackgroundService');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to start background service: $e');
    }
  }

  Future<void> _getAppUsages() async {
    if (!(await checkUsageStatsPermission())) {
      if (kDebugMode) debugPrint('Permission not granted. Cannot get app usages.');
      return;
    }

    try {
      DateTime now = DateTime.now();
      // End date is the current time
      DateTime endDate = now;
      // Start date is the beginning of the current hour
      DateTime startDate = DateTime(now.year, now.month, now.day, now.hour);

      List<app_usage_package.AppUsageInfo> usageStats = await _appUsage.getAppUsage(startDate, endDate);

      for (app_usage_package.AppUsageInfo usage in usageStats) {
        await saveTimeRecord(usage.appName, usage.usage.inSeconds, overwrite: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting app usages: $e');
    }
  }

  @override
  Future<void> getInitialAppUsages() async {
    if (!(await checkUsageStatsPermission())) {
      if (kDebugMode) debugPrint('Permission not granted. Cannot get initial app usages.');
      return;
    }

    try {
      DateTime now = DateTime.now();
      // Get data from the start of the current day to now for initial collection
      DateTime startDate = DateTime(now.year, now.month, now.day);
      DateTime endDate = now;

      if (kDebugMode) debugPrint('Getting initial app usages from $startDate to $endDate');

      List<app_usage_package.AppUsageInfo> usageStats = await _appUsage.getAppUsage(startDate, endDate);

      for (app_usage_package.AppUsageInfo usage in usageStats) {
        // Don't overwrite existing records for initial collection
        await saveTimeRecord(usage.appName, usage.usage.inSeconds, overwrite: false);
      }

      if (kDebugMode) debugPrint('Initial app usage collection completed. Processed ${usageStats.length} apps.');
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting initial app usages: $e');
    }
  }
}
