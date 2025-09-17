abstract class IAppUsageFilterService {
  /// Determines if an app should be excluded from tracking
  /// This includes both user-defined ignore rules and system app filtering
  Future<bool> shouldExcludeApp(String appName);

  /// Checks if an app is a system app that should be filtered
  bool isSystemApp(String appName);

  /// Gets the list of system apps for the current platform
  List<String> getSystemAppExclusions();
}
