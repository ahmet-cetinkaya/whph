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

  /// Fetches app usage from the last collection timestamp to now and saves the records.
  /// This ensures no data gaps between collections and saves separate records for each hour.
  Future<void> _fetchAndSaveCurrentHourUsage() async {
    // Permission should have been checked by the caller (startTracking or timer callback).
    try {
      DateTime now = DateTime.now();
      DateTime startDate = await _getLastCollectionTimestamp() ??
          DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0, 0); // Fallback to start of current hour
      DateTime endDate = now; // Up to the current moment.

      // Ensure startDate is before endDate to form a valid interval.
      if (!startDate.isBefore(endDate)) {
        Logger.info('Skipping app usage fetch: interval is zero or negative. Start: $startDate, End: $endDate.');
        return;
      }

      Logger.info('Fetching app usages from $startDate to $endDate');

      // Process each hour separately to ensure proper hourly records
      await _processUsageByHours(startDate, endDate);

      // Update the last collection timestamp to prevent data gaps
      await _saveLastCollectionTimestamp(endDate);
      Logger.info('Last collection timestamp updated to: $endDate');
    } catch (e) {
      // Log error with current time context as 'now' is local to this call.
      Logger.error('Error in _fetchAndSaveCurrentHourUsage around ${DateTime.now()}: $e');
    }
  }

  /// Processes app usage data by breaking it down into hourly segments
  /// and saving separate records for each hour.
  ///
  /// IMPORTANT: This method calls getAppUsage() once for the entire period to avoid
  /// data duplication, then calculates incremental usage for each hour.
  Future<void> _processUsageByHours(DateTime startDate, DateTime endDate) async {
    try {
      // Get usage data for the entire period ONCE to avoid duplication
      Logger.info('Fetching app usage data for entire period: $startDate to $endDate');
      List<app_usage_package.AppUsageInfo> totalUsageStats = await _appUsage.getAppUsage(startDate, endDate);

      if (totalUsageStats.isEmpty) {
        Logger.info('No app usage stats found for the entire period $startDate - $endDate.');
        return;
      }

      // Get all hours that need to be processed
      List<DateTime> hourlySegments = _generateHourlySegments(startDate, endDate);
      Logger.info('Processing ${totalUsageStats.length} apps across ${hourlySegments.length} hour segments');

      int totalRecordsSaved = 0;

      // Process each app separately to distribute its usage across hours
      for (app_usage_package.AppUsageInfo totalUsage in totalUsageStats) {
        if (totalUsage.usage.inSeconds <= 0) {
          if (totalUsage.usage.inSeconds < 0) {
            Logger.warning(
                'Negative app usage duration for ${totalUsage.appName} (${totalUsage.usage.inSeconds}s). Skipping app.');
          }
          continue;
        }

        // Distribute this app's total usage across the hour segments
        int recordsForThisApp = await _distributeAppUsageAcrossHours(
            totalUsage.appName, totalUsage.usage.inSeconds, hourlySegments, startDate, endDate);

        totalRecordsSaved += recordsForThisApp;
        Logger.info(
            'App ${totalUsage.appName}: ${totalUsage.usage.inSeconds}s total usage distributed across $recordsForThisApp hour records');
      }

      Logger.info("Total $totalRecordsSaved app usage records saved across ${hourlySegments.length} hour segments.");
    } catch (e) {
      Logger.error('Error in _processUsageByHours: $e');
    }
  }

  /// Distributes an app's total usage time across hourly segments proportionally
  /// based on the time spent in each hour segment.
  Future<int> _distributeAppUsageAcrossHours(
    String appName,
    int totalUsageSeconds,
    List<DateTime> hourlySegments,
    DateTime actualStartDate,
    DateTime actualEndDate,
  ) async {
    int recordsSaved = 0;
    int remainingUsage = totalUsageSeconds;

    // Calculate total time span in seconds
    int totalTimeSpanSeconds = actualEndDate.difference(actualStartDate).inSeconds;

    if (totalTimeSpanSeconds <= 0) {
      Logger.warning('Invalid time span for app $appName. Start: $actualStartDate, End: $actualEndDate');
      return 0;
    }

    Logger.info(
        'Distributing ${totalUsageSeconds}s usage for $appName across ${hourlySegments.length} hours (total span: ${totalTimeSpanSeconds}s)');

    for (int i = 0; i < hourlySegments.length; i++) {
      DateTime segmentStart = hourlySegments[i];
      DateTime segmentEnd = i < hourlySegments.length - 1 ? hourlySegments[i + 1] : actualEndDate;

      // Calculate the actual time this segment covers within our collection period
      DateTime effectiveStart = segmentStart.isAfter(actualStartDate) ? segmentStart : actualStartDate;
      DateTime effectiveEnd = segmentEnd.isBefore(actualEndDate) ? segmentEnd : actualEndDate;

      if (!effectiveStart.isBefore(effectiveEnd)) {
        continue; // Skip invalid segments
      }

      int segmentTimeSeconds = effectiveEnd.difference(effectiveStart).inSeconds;

      // Calculate proportional usage for this segment
      int segmentUsage;
      if (i == hourlySegments.length - 1) {
        // Last segment gets all remaining usage to avoid rounding errors
        segmentUsage = remainingUsage;
      } else {
        // Proportional distribution based on time spent in this segment
        segmentUsage = (totalUsageSeconds * segmentTimeSeconds / totalTimeSpanSeconds).round();
        remainingUsage -= segmentUsage;
      }

      if (segmentUsage > 0) {
        await saveTimeRecord(
          appName,
          segmentUsage,
          overwrite: true,
          customDateTime: segmentStart,
        );
        recordsSaved++;

        Logger.info(
            'Hour ${segmentStart.hour}:00 - ${segmentUsage}s usage for $appName (${segmentTimeSeconds}s segment time)');
      }
    }

    return recordsSaved;
  }

  /// Generates a list of hourly segment start times between startDate and endDate
  List<DateTime> _generateHourlySegments(DateTime startDate, DateTime endDate) {
    List<DateTime> segments = [];

    // Start from the beginning of the hour containing startDate
    DateTime currentHour = DateTime(startDate.year, startDate.month, startDate.day, startDate.hour, 0, 0, 0, 0);

    while (currentHour.isBefore(endDate)) {
      segments.add(currentHour);
      currentHour = currentHour.add(const Duration(hours: 1));
    }

    // If segments is empty, add at least the start hour
    if (segments.isEmpty) {
      segments.add(DateTime(startDate.year, startDate.month, startDate.day, startDate.hour, 0, 0, 0, 0));
    }

    Logger.info('Generated ${segments.length} hourly segments from $startDate to $endDate');
    return segments;
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
