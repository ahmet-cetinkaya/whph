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
    // Check permission before starting tracking
    final hasPermission = await checkUsageStatsPermission();
    if (!hasPermission) {
      Logger.warning('Usage stats permission not granted. Cannot start tracking.');
      return;
    }

    await _startBackgroundService();
    await _getAppUsages();

    periodicTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      final permissionCheck = await checkUsageStatsPermission();
      if (permissionCheck) {
        await _getAppUsages();
      } else {
        Logger.warning('Permission lost. Pausing app usage tracking.');
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

  Future<void> _getAppUsages() async {
    if (!(await checkUsageStatsPermission())) {
      Logger.warning('Permission not granted. Cannot get app usages.');
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
      Logger.error('Error getting app usages: $e');
    }
  }
}
