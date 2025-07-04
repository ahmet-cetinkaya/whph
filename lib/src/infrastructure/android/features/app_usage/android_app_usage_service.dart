import 'dart:async';
import 'package:app_usage/app_usage.dart' as app_usage_package;
import 'package:flutter/services.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/base_app_usage_service.dart';
import 'package:whph/src/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart' as app_key_helper;
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';

class AndroidAppUsageService extends BaseAppUsageService {
  static final appUsageStatsChannel = MethodChannel(AndroidAppConstants.channels.appUsageStats);
  static final workManagerChannel = MethodChannel(AndroidAppConstants.channels.workManager);
  final app_usage_package.AppUsage _appUsage = app_usage_package.AppUsage();
  final ISettingRepository _settingRepository;

  AndroidAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
    super.appUsageIgnoreRuleRepository,
    this._settingRepository,
  );

  @override
  Future<void> startTracking() async {
    final hasPermission = await checkUsageStatsPermission();
    if (!hasPermission) {
      Logger.warning('Usage stats permission not granted. Cannot start tracking.');
      return;
    }

    // Initial fetch for the current partial hour to capture immediate usage.
    await _fetchAndSaveCurrentHourUsage();

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
        Logger.info('WorkManager triggered app usage collection');
        await _fetchAndSaveCurrentHourUsage();
      }
    });
  }

  /// Fetches app usage for individual hours using incremental collection to avoid data duplication.
  /// Uses improved time zone handling and incremental collection approach for accurate statistics.
  Future<void> _fetchAndSaveCurrentHourUsage() async {
    // Permission should have been checked by the caller (startTracking or timer callback).
    try {
      // Use local time for collection but ensure consistent time zone handling
      DateTime now = DateTime.now();
      DateTime? lastCollection = await _getLastCollectionTimestamp();

      // If this is the first time running, collect today's usage data
      if (lastCollection == null) {
        Logger.info('First time collection - collecting today\'s usage data');
        await _collectTodaysUsageData(now);
        await _saveLastCollectionTimestamp(now);
        return;
      }

      // Calculate which hours need to be processed since last collection
      List<DateTime> hoursToProcess = _getHoursToProcess(lastCollection, now);

      if (hoursToProcess.isEmpty) {
        Logger.info('No new hours to process since last collection: $lastCollection');
        return;
      }

      Logger.info('Processing ${hoursToProcess.length} hours since last collection');

      // Process each hour individually using incremental method
      for (DateTime hourStart in hoursToProcess) {
        await _collectUsageForSingleHour(hourStart);

        // Add a small delay between collections to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Update the last collection timestamp
      await _saveLastCollectionTimestamp(now);
      Logger.info('Successfully processed ${hoursToProcess.length} hours');
    } catch (e) {
      Logger.error('Error in _fetchAndSaveCurrentHourUsage: $e');
    }
  }

  /// Determines which hours need to be processed since the last collection.
  /// Returns a list of hour start times that need data collection.
  List<DateTime> _getHoursToProcess(DateTime lastCollection, DateTime now) {
    List<DateTime> hoursToProcess = [];

    // Start from the hour after the last collection
    DateTime lastCollectionHour = DateTime(
      lastCollection.year,
      lastCollection.month,
      lastCollection.day,
      lastCollection.hour,
      0, 0, 0, 0
    );

    // Always start from the next hour after last collection
    DateTime startHour = lastCollectionHour.add(const Duration(hours: 1));

    DateTime currentHour = DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0, 0);

    // Add all complete hours between start and current hour (exclusive of current if incomplete)
    DateTime processingHour = startHour;
    while (processingHour.isBefore(currentHour)) {
      hoursToProcess.add(processingHour);
      processingHour = processingHour.add(const Duration(hours: 1));
    }

    // Only include current hour if it's complete (we're in the next hour)
    if (processingHour.isAtSameMomentAs(currentHour) && now.minute >= 59) {
      hoursToProcess.add(processingHour);
    }

    return hoursToProcess;
  }

  /// Collects usage data using fixed incremental approach that properly handles cumulative data.
  /// This method calculates the actual usage during the specific hour.
  Future<void> _collectUsageForSingleHour(DateTime hourStart) async {
    try {
      // Get usage data using fixed incremental approach
      Map<String, int> hourlyUsage = await _getIncrementalUsageForHour(hourStart);

      if (hourlyUsage.isEmpty) {
        return;
      }

      // Save each app's incremental usage for this hour
      for (MapEntry<String, int> entry in hourlyUsage.entries) {
        String appName = entry.key;
        int incrementalSeconds = entry.value;

        if (incrementalSeconds <= 0) {
          continue; // Skip zero or negative values
        }

        // Save the incremental usage for this hour
        await saveTimeRecord(
          appName,
          incrementalSeconds,
          overwrite: true, // Overwrite any existing data for this hour
          customDateTime: hourStart,
        );
      }

    } catch (e) {
      Logger.error('Error collecting usage for hour $hourStart: $e');
    }
  }

  /// Calculates incremental usage for a specific hour using proper cumulative data handling.
  /// Since app_usage package returns cumulative data, we always use incremental calculation.
  Future<Map<String, int>> _getIncrementalUsageForHour(DateTime hourStart) async {
    try {
      DateTime hourEnd = hourStart.add(const Duration(hours: 1));

      // Since the package returns cumulative data, we need to get usage at two points:
      // 1. Cumulative usage up to the START of our target hour
      // 2. Cumulative usage up to the END of our target hour
      // The difference is the actual usage during our target hour

      List<app_usage_package.AppUsageInfo> usageAtHourStart =
          await _appUsage.getAppUsage(DateTime(2000), hourStart); // From epoch to hour start

      List<app_usage_package.AppUsageInfo> usageAtHourEnd =
          await _appUsage.getAppUsage(DateTime(2000), hourEnd); // From epoch to hour end

      // Create maps for easier comparison
      Map<String, int> usageAtStart = {};
      Map<String, int> usageAtEnd = {};

      for (var app in usageAtHourStart) {
        usageAtStart[app.appName] = app.usage.inSeconds;
      }

      for (var app in usageAtHourEnd) {
        usageAtEnd[app.appName] = app.usage.inSeconds;
      }

      // Calculate incremental differences (usage during the target hour)
      Map<String, int> incrementalUsage = {};

      // Check all apps that have usage at the end of the hour
      for (String appName in usageAtEnd.keys) {
        int endSeconds = usageAtEnd[appName] ?? 0;
        int startSeconds = usageAtStart[appName] ?? 0;
        int incrementalSeconds = endSeconds - startSeconds;

        if (incrementalSeconds > 0) {
          incrementalUsage[appName] = incrementalSeconds;
        } else if (incrementalSeconds < 0) {
          // This shouldn't happen with cumulative data, but log if it does
          Logger.warning('Unexpected negative incremental usage for $appName: start=${startSeconds}s, end=${endSeconds}s, diff=${incrementalSeconds}s');
        }
      }

      return incrementalUsage;

    } catch (e) {
      Logger.error('Error in fixed incremental calculation: $e');

      // If this fails, we have a serious problem - return empty map
      Logger.error('Cannot calculate incremental usage - returning empty map to prevent cumulative data storage');
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

  /// Collects today's usage data for first-time app launch
  /// This ensures users see existing usage data when they first open the app
  Future<void> _collectTodaysUsageData(DateTime now) async {
    try {
      Logger.info('=== COLLECTING TODAY\'S USAGE DATA (FIRST TIME) ===');

      DateTime todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      DateTime currentHour = DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0, 0);

      Logger.info('Collecting usage from $todayStart to $currentHour');

      // Get cumulative usage for today up to current hour
      List<app_usage_package.AppUsageInfo> todayUsage =
          await _appUsage.getAppUsage(todayStart, currentHour);

      Logger.info('Found ${todayUsage.length} apps with usage today');

      if (todayUsage.isEmpty) {
        Logger.info('No usage data found for today');
        return;
      }

      // Calculate how many hours have passed today
      int hoursToday = currentHour.hour;
      if (hoursToday == 0) hoursToday = 1; // At least 1 hour to avoid division by zero

      Logger.info('Distributing today\'s usage across $hoursToday hours');

      int totalSaved = 0;
      int recordsSaved = 0;

      for (var app in todayUsage) {
        if (app.usage.inSeconds > 0) {
          // Distribute the usage across the hours of today
          int usagePerHour = (app.usage.inSeconds / hoursToday).round();

          // Save usage for each hour of today
          for (int hour = 0; hour < hoursToday; hour++) {
            DateTime hourStart = DateTime(now.year, now.month, now.day, hour, 0, 0, 0, 0);

            await saveTimeRecord(
              app.appName,
              usagePerHour,
              overwrite: true,
              customDateTime: hourStart,
            );
          }

          totalSaved += app.usage.inSeconds;
          recordsSaved++;
        }
      }

      Logger.info('=== TODAY\'S DATA COLLECTION COMPLETE ===');
      Logger.info('Distributed $recordsSaved apps across $hoursToday hours, total: ${totalSaved}s (${(totalSaved/60).toStringAsFixed(1)}min)');

    } catch (e) {
      Logger.error('Error collecting today\'s usage data: $e');
    }
  }

  /// Collects usage data for the current hour (including incomplete hour)
  /// This is used for manual refresh to capture real-time usage updates
  @override
  Future<void> collectCurrentHourData() async {
    try {
      DateTime now = DateTime.now();
      DateTime currentHourStart = DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0, 0);

      // Force collection of current hour even if incomplete
      await _collectUsageForSingleHour(currentHourStart);

      // Update last collection timestamp to current time
      await _saveLastCollectionTimestamp(now);

    } catch (e) {
      Logger.error('Error collecting current hour data: $e');
    }
  }

  /// Test method to show current cumulative usage data for debugging
  Future<void> showCurrentUsageData() async {
    try {
      Logger.info('=== CURRENT USAGE DATA TEST ===');

      DateTime now = DateTime.now();
      DateTime todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);

      Logger.info('Getting cumulative usage from today start ($todayStart) to now ($now)');

      List<app_usage_package.AppUsageInfo> todayUsage =
          await _appUsage.getAppUsage(todayStart, now);

      Logger.info('Found ${todayUsage.length} apps with usage today');

      for (var app in todayUsage) {
        if (app.usage.inSeconds > 0) {
          double minutes = app.usage.inSeconds / 60.0;
          Logger.info('${app.appName}: ${app.usage.inSeconds}s (${minutes.toStringAsFixed(1)}min)');
        }
      }

      int totalSeconds = todayUsage.fold(0, (sum, app) => sum + app.usage.inSeconds);
      Logger.info('Total usage today: ${totalSeconds}s (${(totalSeconds/60).toStringAsFixed(1)}min)');

      Logger.info('=== USAGE DATA TEST COMPLETE ===');

    } catch (e) {
      Logger.error('Error showing current usage data: $e');
    }
  }



  /// Gets the last collection timestamp from settings
  /// Returns null if no previous collection timestamp exists
  Future<DateTime?> _getLastCollectionTimestamp() async {
    try {
      final setting = await _settingRepository.getByKey(SettingKeys.appUsageLastCollectionTimestamp);
      if (setting != null) {
        final timestamp = int.tryParse(setting.value);
        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
        }
      }
    } catch (e) {
      Logger.error('Error getting last collection timestamp: $e');
    }
    return null;
  }

  /// Saves the last collection timestamp to settings
  Future<void> _saveLastCollectionTimestamp(DateTime timestamp) async {
    try {
      final timestampValue = timestamp.toUtc().millisecondsSinceEpoch.toString();

      final existingSetting = await _settingRepository.getByKey(SettingKeys.appUsageLastCollectionTimestamp);
      if (existingSetting != null) {
        existingSetting.value = timestampValue;
        existingSetting.modifiedDate = DateTime.now().toUtc();
        await _settingRepository.update(existingSetting);
      } else {
        final newSetting = Setting(
          id: app_key_helper.KeyHelper.generateStringId(),
          key: SettingKeys.appUsageLastCollectionTimestamp,
          value: timestampValue,
          valueType: SettingValueType.string,
          createdDate: DateTime.now().toUtc(),
        );
        await _settingRepository.add(newSetting);
      }
    } catch (e) {
      Logger.error('Error saving last collection timestamp: $e');
    }
  }
}
