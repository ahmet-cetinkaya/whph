/// Constants related to Linux implementation for native method channels
class LinuxAppConstants {
  static const String packageName = "me.ahmetcetinkaya.whph";

  /// Method channel names for Linux platform
  static final channels = _Channels();
}

/// Method channel names for Linux
class _Channels {
  const _Channels();

  /// App usage detection channel
  String get appUsage => "${LinuxAppConstants.packageName}/app_usage";
}
