/// Constants related to Windows implementation that mirror Windows-specific functionality.
class WindowsAppConstants {
  /// Application GUID for Windows notifications (required format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  /// This GUID must be unique for each application and is used by Windows notification system
  static const String notificationGuid = "3c5b8f12-7a4e-4d8f-9e2a-6b1c8d5e9f3a";

  /// Windows-specific configuration
  static final config = _Config();
}

/// Windows configuration constants
class _Config {
  const _Config();

  /// Application User Model ID for Windows taskbar and notifications
  String get appUserModelId => "AhmetCetinkaya.WorkHardPlayHard";
}
