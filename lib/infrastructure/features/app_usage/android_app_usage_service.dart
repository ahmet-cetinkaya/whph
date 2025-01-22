import 'dart:async';
import 'dart:io';
import 'package:app_usage/app_usage.dart' as app_usage_package;
import 'package:flutter/foundation.dart';
import 'package:whph/application/features/app_usages/services/abstraction/base_app_usage_service.dart';

class AndroidAppUsageService extends BaseAppUsageService {
  AndroidAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
  );

  Future<void> _initializeHistoricalData() async {
    if (!Platform.isAndroid) return;

    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    DateTime currentStart = startDate;
    while (currentStart.isBefore(endDate)) {
      DateTime currentEnd = currentStart.add(const Duration(hours: 1));
      if (currentEnd.isAfter(endDate)) {
        currentEnd = endDate;
      }

      try {
        List<app_usage_package.AppUsageInfo> usageStats =
            await app_usage_package.AppUsage().getAppUsage(currentStart, currentEnd);

        if (usageStats.isNotEmpty) {
          for (app_usage_package.AppUsageInfo usage in usageStats) {
            if (usage.usage.inSeconds > 0) {
              await saveTimeRecord(usage.appName, usage.usage.inSeconds, overwrite: true);
            }
          }
        }

        // Add small delay to prevent overwhelming the system
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        if (kDebugMode) {
          print(
              'Error fetching historical data for period ${currentStart.toIso8601String()} - ${currentEnd.toIso8601String()}: $e');
        }
        // Continue with next period even if current one fails
        await Future.delayed(const Duration(seconds: 1));
      }

      currentStart = currentEnd;
    }
  }

  @override
  void startTracking() async {
    await _initializeHistoricalData();

    periodicTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      if (Platform.isAndroid) {
        DateTime now = DateTime.now();
        DateTime endDate = now;
        int remainingMinutes = endDate.minute % 60;
        DateTime startDate = endDate.subtract(Duration(minutes: remainingMinutes));
        List<app_usage_package.AppUsageInfo> usageStats =
            await app_usage_package.AppUsage().getAppUsage(startDate, endDate);

        if (usageStats.isEmpty) return;

        for (app_usage_package.AppUsageInfo usage in usageStats) {
          await saveTimeRecord(usage.appName, usage.usage.inSeconds, overwrite: true);
        }
      }
    });
  }
}
