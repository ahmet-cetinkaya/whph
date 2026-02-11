abstract class IAppUsageService {
  Future<void> startTracking();
  Future<void> stopTracking();
  Future<void> saveTimeRecord(String appName, int duration, {bool overwrite = false, DateTime? customDateTime});
  Future<bool> checkUsageStatsPermission();
  Future<void> requestUsageStatsPermission();
}
