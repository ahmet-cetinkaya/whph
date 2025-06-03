/// Constants related to Android implementation that mirror the Kotlin Constants.kt file
class AndroidAppConstants {
  static const String packageName = "me.ahmetcetinkaya.whph";

  /// Method channel names
  static final channels = _Channels();

  /// Notification channel constants
  static final notificationChannels = _NotificationChannels();

  /// Intent action constants
  static final intentActions = _IntentActions();

  /// Intent extra constants
  static final intentExtras = _IntentExtras();
}

/// Method channel names
class _Channels {
  const _Channels();

  String get appInfo => "${AndroidAppConstants.packageName}/app_info";
  String get backgroundService => "${AndroidAppConstants.packageName}/background_service";
  String get appInstaller => "${AndroidAppConstants.packageName}/app_installer";
  String get batteryOptimization => "${AndroidAppConstants.packageName}/battery_optimization";
  String get exactAlarm => "${AndroidAppConstants.packageName}/exact_alarm";
  String get notification => "${AndroidAppConstants.packageName}/notification";
  String get appUsageStats => "${AndroidAppConstants.packageName}/app_usage_stats";
}

/// Notification channel constants
class _NotificationChannels {
  const _NotificationChannels();

  // Task Reminders
  String get taskChannelId => "whph_task_reminders";
  String get taskChannelName => "Task Reminders";

  // Habit Reminders
  String get habitChannelId => "whph_habit_reminders";
  String get habitChannelName => "Habit Reminders";

  // Background Service
  String get serviceChannelId => "whph_background_service";
  String get serviceChannelName => "System Tray";
}

/// Intent action constants
class _IntentActions {
  const _IntentActions();

  String get notificationClicked => "${AndroidAppConstants.packageName}.NOTIFICATION_CLICKED";
  String get alarmTriggered => "${AndroidAppConstants.packageName}.ALARM_TRIGGERED";
}

/// Intent extra constants
class _IntentExtras {
  const _IntentExtras();

  String get notificationId => "notification_id";
  String get notificationPayload => "notification_payload";
  String get payload => "payload";
  String get title => "title";
  String get body => "body";
}
