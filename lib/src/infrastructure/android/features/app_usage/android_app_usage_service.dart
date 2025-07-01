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

  /// Fetches app usage for individual hours to avoid data duplication and over-reporting.
  /// Uses incremental collection approach to ensure accurate usage statistics.
  Future<void> _fetchAndSaveCurrentHourUsage() async {
    // Permission should have been checked by the caller (startTracking or timer callback).
    try {
      DateTime now = DateTime.now();
      DateTime? lastCollection = await _getLastCollectionTimestamp();
      
      // If this is the first time running, start from the beginning of current hour
      if (lastCollection == null) {
        DateTime currentHourStart = DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0, 0);
        await _collectUsageForSingleHour(currentHourStart);
        await _saveLastCollectionTimestamp(now);
        return;
      }

      // Calculate which hours need to be processed since last collection
      List<DateTime> hoursToProcess = _getHoursToProcess(lastCollection, now);
      
      if (hoursToProcess.isEmpty) {
        Logger.info('No new hours to process since last collection: $lastCollection');
        return;
      }

      Logger.info('Processing ${hoursToProcess.length} hours since last collection: $lastCollection');

      // Process each hour individually to get accurate data
      for (DateTime hourStart in hoursToProcess) {
        await _collectUsageForSingleHour(hourStart);
      }

      // Update the last collection timestamp
      await _saveLastCollectionTimestamp(now);
      Logger.info('Successfully processed ${hoursToProcess.length} hours, updated last collection to: $now');
    } catch (e) {
      Logger.error('Error in _fetchAndSaveCurrentHourUsage: $e');
    }
  }

  /// Determines which hours need to be processed since the last collection.
  /// Returns a list of hour start times that need data collection.
  List<DateTime> _getHoursToProcess(DateTime lastCollection, DateTime now) {
    List<DateTime> hoursToProcess = [];
    
    // Start from the hour after the last collection
    DateTime startHour = DateTime(
      lastCollection.year, 
      lastCollection.month, 
      lastCollection.day, 
      lastCollection.hour, 
      0, 0, 0, 0
    );
    
    // If we're in the same hour as last collection, move to next hour
    if (startHour.isAtSameMomentAs(DateTime(
      lastCollection.year, lastCollection.month, lastCollection.day, lastCollection.hour, 0, 0, 0, 0))) {
      startHour = startHour.add(const Duration(hours: 1));
    }
    
    DateTime currentHour = DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0, 0);
    
    // Add all complete hours between last collection and now
    DateTime processingHour = startHour;
    while (processingHour.isBefore(currentHour) || processingHour.isAtSameMomentAs(currentHour)) {
      hoursToProcess.add(processingHour);
      processingHour = processingHour.add(const Duration(hours: 1));
    }
    
    return hoursToProcess;
  }

  /// Collects usage data for a specific hour and saves it as a single record.
  /// This method fetches usage for exactly one hour to avoid data duplication.
  Future<void> _collectUsageForSingleHour(DateTime hourStart) async {
    try {
      DateTime hourEnd = hourStart.add(const Duration(hours: 1));
      
      Logger.info('Collecting usage data for hour: $hourStart to $hourEnd');
      
      // Fetch usage data for this specific hour only
      List<app_usage_package.AppUsageInfo> hourUsageStats = 
          await _appUsage.getAppUsage(hourStart, hourEnd);
      
      if (hourUsageStats.isEmpty) {
        Logger.info('No app usage stats found for hour $hourStart - $hourEnd');
        return;
      }
      
      int recordsSaved = 0;
      
      // Save each app's usage for this hour directly (no distribution needed)
      for (app_usage_package.AppUsageInfo usageInfo in hourUsageStats) {
        if (usageInfo.usage.inSeconds <= 0) {
          if (usageInfo.usage.inSeconds < 0) {
            Logger.warning(
                'Negative app usage duration for ${usageInfo.appName} (${usageInfo.usage.inSeconds}s). Skipping app.');
          }
          continue;
        }
        
        // Save the usage directly for this hour (the app_usage package already gives us the correct usage for this time period)
        await saveTimeRecord(
          usageInfo.appName,
          usageInfo.usage.inSeconds,
          overwrite: true, // Overwrite any existing data for this hour
          customDateTime: hourStart,
        );
        
        recordsSaved++;
        Logger.info('Saved ${usageInfo.usage.inSeconds}s usage for ${usageInfo.appName} at hour $hourStart');
      }
      
      Logger.info('Saved $recordsSaved app usage records for hour starting at $hourStart');
    } catch (e) {
      Logger.error('Error collecting usage for hour $hourStart: $e');
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
