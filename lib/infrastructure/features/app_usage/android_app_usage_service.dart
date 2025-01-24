import 'dart:async';
import 'package:app_usage/app_usage.dart' as app_usage_package;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:whph/application/features/app_usages/services/abstraction/base_app_usage_service.dart';

class AndroidAppUsageService extends BaseAppUsageService {
  static const platform = MethodChannel('whph/background_service');

  AndroidAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
    super.settingRepository,
  );

  @override
  void startTracking() async {
    await _startBackgroundService();
    await _getAppUsages();

    periodicTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      await _getAppUsages();
    });
  }

  Future<void> _startBackgroundService() async {
    try {
      await platform.invokeMethod('startBackgroundService');
    } catch (e) {
      if (kDebugMode) print('ERROR: Failed to start background service: $e');
    }
  }

  Future<void> _getAppUsages() async {
    DateTime now = DateTime.now();
    // End date is the current time
    DateTime endDate = now;
    // Start date is the beginning of the current hour
    DateTime startDate = DateTime(now.year, now.month, now.day, now.hour);

    List<app_usage_package.AppUsageInfo> usageStats =
        await app_usage_package.AppUsage().getAppUsage(startDate, endDate);

    for (app_usage_package.AppUsageInfo usage in usageStats) {
      await saveTimeRecord(usage.appName, usage.usage.inSeconds, overwrite: true);
    }
  }
}
