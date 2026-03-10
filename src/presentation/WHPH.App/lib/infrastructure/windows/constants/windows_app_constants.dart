/// Constants related to Windows implementation that mirror Windows-specific functionality.
class WindowsAppConstants {
  static const String packageName = "me.ahmetcetinkaya.whph";

  /// Method channel names for Windows platform
  static final channels = _Channels();

  /// Notification constants for Windows platform
  static final notifications = _Notifications();
}

/// Method channel names for Windows
class _Channels {
  const _Channels();

  /// App usage detection channel
  String get appUsage => "${WindowsAppConstants.packageName}/app_usage";
}

/// Notification constants for Windows
class _Notifications {
  const _Notifications();

  /// Notification GUID for Windows notifications
  String get guid => "3c5b8f12-7a4e-4d8f-9e2a-6b1c8d5e9f3a";

  /// App User Model ID for Windows notifications
  String get appUserModelId => "AhmetCetinkaya.WorkHardPlayHard";
}
