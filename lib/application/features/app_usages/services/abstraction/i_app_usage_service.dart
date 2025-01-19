abstract class IAppUsageService {
  void startTracking();
  void stopTracking();
  Future<void> saveTimeRecord(String appName, int duration, {bool overwrite = false});
}
