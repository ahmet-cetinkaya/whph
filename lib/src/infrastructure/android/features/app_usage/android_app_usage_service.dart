import 'dart:async';
import 'package:flutter/services.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/base_app_usage_service.dart';
import 'package:whph/src/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

class AndroidAppUsageService extends BaseAppUsageService {
  static final appUsageStatsChannel = MethodChannel(AndroidAppConstants.channels.appUsageStats);
  static final workManagerChannel = MethodChannel(AndroidAppConstants.channels.workManager);

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

    // Run a diagnostic comparison for the last hour to help debug accuracy issues
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    await compareUsageMethods(oneHourAgo, now);

    // Initial fetch - use direct today collection instead of hour-by-hour
    await collectTodayUsageDirectly();

    // Start WorkManager periodic work for background collection
    await _startWorkManagerTracking();

    // Set up method channel listener for WorkManager triggers
    _setupWorkManagerListener();
  }

  /// Starts WorkManager periodic work for background app usage collection
  Future<void> _startWorkManagerTracking() async {
    try {
      await workManagerChannel.invokeMethod('startPeriodicAppUsageWork');
      // Default interval: 60 minutes (1 hour)
      Logger.info('WorkManager periodic app usage tracking started');
    } catch (e) {
      Logger.error('Failed to start WorkManager tracking: $e');
    }
  }

  /// Sets up method channel listener for WorkManager triggers
  void _setupWorkManagerListener() {
    appUsageStatsChannel.setMethodCallHandler((call) async {
      if (call.method == 'triggerCollection') {
        Logger.info('WorkManager triggered app usage collection - using DIRECT today method');
        await collectTodayUsageDirectly();
      }
    });
  }




  /// Gets accurate foreground usage data using the native Android UsageStatsManager.
  /// This method filters for foreground activity only and matches Digital Wellbeing accuracy.
  Future<Map<String, dynamic>> _getAccurateForegroundUsage(int startTimeMs, int endTimeMs) async {
    try {
      final result = await appUsageStatsChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getAccurateForegroundUsage',
        {
          'startTime': startTimeMs,
          'endTime': endTimeMs,
        },
      );

      if (result == null) {
        Logger.warning('No accurate usage data returned from native method');
        return {};
      }

      // Convert to proper type
      final Map<String, dynamic> typedResult = {};
      result.forEach((key, value) {
        if (key is String && value is Map) {
          typedResult[key] = Map<String, dynamic>.from(value);
        }
      });

      Logger.info('Retrieved accurate usage data for ${typedResult.length} apps');
      return typedResult;
    } catch (e) {
      Logger.error('Error getting accurate foreground usage: $e');
      return {};
    }
  }

  /// Gets TODAY'S usage directly from Android without hour-by-hour collection.
  /// This bypasses the accumulation issue and matches Digital Wellbeing's approach.
  Future<Map<String, dynamic>> _getTodayUsageDirectly() async {
    try {
      Logger.info('Getting TODAY\'S usage directly from Android (bypassing hour collection)');
      
      final result = await appUsageStatsChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getTodayForegroundUsage',
      );

      if (result == null) {
        Logger.warning('No today usage data returned from native method');
        return {};
      }

      // Convert to proper type
      final Map<String, dynamic> typedResult = {};
      result.forEach((key, value) {
        if (key is String && value is Map) {
          typedResult[key] = Map<String, dynamic>.from(value);
        }
      });

      Logger.info('Retrieved TODAY\'S usage data for ${typedResult.length} apps (direct method)');
      return typedResult;
    } catch (e) {
      Logger.error('Error getting today\'s usage directly: $e');
      return {};
    }
  }

  @override
  Future<void> stopTracking() async {
    try {
      await workManagerChannel.invokeMethod('stopPeriodicAppUsageWork');
      Logger.info('WorkManager app usage tracking stopped');
    } catch (e) {
      Logger.error('Failed to stop WorkManager tracking: $e');
    }

    periodicTimer?.cancel();
    periodicTimer = null; // Clear any remaining timer instance.
    Logger.info('Android app usage tracking stopped');
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
      return false;
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



  /// Diagnostic method to log usage calculation results.
  /// This helps identify and debug the accuracy of the event-based method.
  Future<void> compareUsageMethods(DateTime startTime, DateTime endTime) async {
    try {
      Logger.info('=== USAGE DIAGNOSTIC ===');
      Logger.info('Time range: $startTime to $endTime');

      // Use the event-based method to get usage data
      final usageMap =
          await _getAccurateForegroundUsage(startTime.millisecondsSinceEpoch, endTime.millisecondsSinceEpoch);
      Logger.info('--- EVENT-BASED FOREGROUND METHOD ---');
      for (final entry in usageMap.entries) {
        final usageData = entry.value as Map<String, dynamic>;
        final usageTimeSeconds = usageData['usageTimeSeconds'] as int;
        final appName = usageData['appName'] as String;
        Logger.info('$appName: ${usageTimeSeconds}s (${(usageTimeSeconds / 60).toStringAsFixed(1)}m)');
      }

      Logger.info('=== END DIAGNOSTIC ===');
    } catch (e) {
      Logger.error('Error in usage diagnostic: $e');
    }
  }

  /// Gets TODAY'S usage without any hour-by-hour accumulation.
  /// This method directly queries Android for today's data and stores it as a single record.
  Future<void> collectTodayUsageDirectly() async {
    try {
      Logger.info('=== COLLECTING TODAY\'S USAGE DIRECTLY (NO HOUR ACCUMULATION) ===');
      
      // Get today's usage directly from Android
      final todayUsageMap = await _getTodayUsageDirectly();

      if (todayUsageMap.isEmpty) {
        Logger.info('No usage data found for today (direct method)');
        return;
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0, 0, 0);

      // Clear any existing records for today to prevent accumulation
      await _clearTodayRecords(todayStart);

      int recordsSaved = 0;

      // Save each app's TOTAL usage for today as a single record
      for (final entry in todayUsageMap.entries) {
        final usageData = entry.value as Map<String, dynamic>;
        final usageTimeSeconds = usageData['usageTimeSeconds'] as int;
        final appName = usageData['appName'] as String;

        if (usageTimeSeconds <= 0) {
          continue;
        }

        // Apply reasonable daily cap (12 hours max)
        final cappedSeconds = usageTimeSeconds > (12 * 60 * 60) ? (12 * 60 * 60) : usageTimeSeconds;

        // Save as a single record for today
        await saveTimeRecord(
          appName,
          cappedSeconds,
          overwrite: true,
          customDateTime: todayStart,
        );

        recordsSaved++;
        Logger.info('Saved TODAY\'S usage: $appName = ${cappedSeconds}s (${(cappedSeconds/60).toInt()}m) - DIRECT');
      }

      Logger.info('=== COMPLETED: Saved $recordsSaved direct today records ===');
    } catch (e) {
      Logger.error('Error collecting today\'s usage directly: $e');
    }
  }

  /// Clears existing records for today to prevent accumulation
  Future<void> _clearTodayRecords(DateTime todayStart) async {
    try {
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      final existingRecords = await appUsageTimeRecordRepository.getAll(
        customWhereFilter: CustomWhereFilter(
          'usage_date >= ? AND usage_date < ? AND deleted_date IS NULL',
          [todayStart.toUtc(), todayEnd.toUtc()],
        ),
      );

      if (existingRecords.isNotEmpty) {
        Logger.info('Clearing ${existingRecords.length} existing records for today before direct collection');
        
        for (final record in existingRecords) {
          record.deletedDate = DateTime.now().toUtc();
          await appUsageTimeRecordRepository.update(record);
        }
      }
    } catch (e) {
      Logger.error('Error clearing today\'s records: $e');
    }
  }

  /// Public method to test accuracy of usage calculation for debugging purposes.
  /// This can be called from the Flutter UI to test the event-based method for specific time ranges.
  Future<Map<String, dynamic>> testUsageAccuracy({DateTime? startTime, DateTime? endTime}) async {
    final now = DateTime.now();
    final start = startTime ?? now.subtract(const Duration(hours: 1));
    final end = endTime ?? now;

    try {
      // Get usage from the event-based method only
      final usageMap = await _getAccurateForegroundUsage(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);

      return {
        'timeRange': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
          'durationHours': end.difference(start).inHours,
        },
        'newMethod': usageMap, // Keep the old key name for compatibility
        'eventBasedMethod': usageMap, // Also provide the new key name
        'totalApps': usageMap.length,
      };
    } catch (e) {
      Logger.error('Error in testUsageAccuracy: $e');
      return {
        'error': e.toString(),
        'timeRange': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
      };
    }
  }
}
