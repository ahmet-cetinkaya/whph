/// Constants related to Linux implementation for native method channels
class LinuxAppConstants {
  static const String packageName = "me.ahmetcetinkaya.whph";
  static const bool isFlathub = bool.fromEnvironment('FLATHUB', defaultValue: false);

  /// Method channel names for Linux platform
  static final channels = _Channels();
}

/// Method channel names for Linux
class _Channels {
  const _Channels();

  /// App usage detection channel
  String get appUsage => "${LinuxAppConstants.packageName}/app_usage";

  /// Window management channel
  String get windowManagement => "${LinuxAppConstants.packageName}/window_management";
}
