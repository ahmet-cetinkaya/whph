import 'dart:async';
import 'dart:io';
import 'package:app_usage/app_usage.dart' as app_usage_package;
import 'package:whph/application/features/app_usages/services/abstraction/base_app_usage_service.dart';

class AndroidAppUsageService extends BaseAppUsageService {
  AndroidAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
  );

  @override
  void startTracking() {
    periodicTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      if (Platform.isAndroid) {
        DateTime endDate = DateTime.now();
        DateTime startDate = endDate.subtract(const Duration(hours: 1));
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
