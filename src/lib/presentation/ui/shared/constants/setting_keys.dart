class SettingKeys {
  // Onboarding State
  static const String onboardingCompleted = 'ONBOARDING_COMPLETED';
  static const String tourCompleted = 'TOUR_COMPLETED';
  static const String tourSkipped = 'TOUR_SKIPPED';

  // Notification settings
  static const String notifications = 'NOTIFICATIONS_ENABLED';

  // Startup settings
  static const String startAtStartup = 'START_AT_STARTUP';

  // Pomodoro Timer settings
  static const String workTime = 'WORK_TIME';
  static const String breakTime = 'BREAK_TIME';
  static const String longBreakTime = 'LONG_BREAK_TIME';
  static const String sessionsBeforeLongBreak = 'SESSIONS_BEFORE_LONG_BREAK';
  static const String autoStartBreak = 'AUTO_START_BREAK';
  static const String autoStartWork = 'AUTO_START_WORK';
  static const String tickingEnabled = 'TICKING_ENABLED';
  static const String tickingVolume = 'TICKING_VOLUME';
  static const String tickingSpeed = 'TICKING_SPEED';
  static const String keepScreenAwake = 'KEEP_SCREEN_AWAKE';
  static const String defaultTimerMode = 'DEFAULT_TIMER_MODE';

  // Filter and sort settings
  static const String tasksListOptionsSettings = 'TASKS_LIST_OPTIONS_SETTINGS';
  static const String habitsListOptionsSettings = 'HABITS_LIST_OPTIONS_SETTINGS';
  static const String tagsListOptionsSettings = 'TAGS_LIST_OPTIONS_SETTINGS';
  static const String notesListOptionsSettings = 'NOTES_LIST_OPTIONS_SETTINGS';
  static const String tagTimeChartOptionsSettings = 'TAG_TIME_CHART_OPTIONS_SETTINGS';
  static const String todayPageListOptionsSettings = 'TODAY_PAGE_LIST_OPTIONS_SETTINGS';
  static const String appUsagesFilterSettings = 'APP_USAGES_FILTER_SETTINGS';
  static const String appUsageStatisticsFilterSettings = 'APP_USAGE_STATISTICS_FILTER_SETTINGS';

  // App Usage Collection (Only for Android)
  static const String appUsageLastCollectionTimestamp = 'APP_USAGE_LAST_COLLECTION_TIMESTAMP';

  // Support State
  static const String supportDialogShown = 'SUPPORT_DIALOG_SHOWN';
  static const String supportDialogLastShownUsage = 'SUPPORT_DIALOG_LAST_SHOWN_USAGE';

  // Locale Persistence for Notifications
  static const String currentLocale = 'CURRENT_LOCALE';

  // Theme Settings
  static const String themeMode = 'THEME_MODE';
  static const String dynamicAccentColor = 'DYNAMIC_ACCENT_COLOR';
  static const String customAccentColor = 'CUSTOM_ACCENT_COLOR';
  static const String uiDensity = 'UI_DENSITY';

  // Sound Settings
  static const String soundEnabled = 'SOUND_ENABLED';
  static const String taskCompletionSoundEnabled = 'TASK_COMPLETION_SOUND_ENABLED';
  static const String habitCompletionSoundEnabled = 'HABIT_COMPLETION_SOUND_ENABLED';
  static const String timerControlSoundEnabled = 'TIMER_CONTROL_SOUND_ENABLED';
  static const String timerAlarmSoundEnabled = 'TIMER_ALARM_SOUND_ENABLED';

  // Debug Settings
  static const String debugLogsEnabled = 'DEBUG_LOGS_ENABLED';

  // Task Settings
  static const String taskDefaultEstimatedTime = "TASK_DEFAULT_ESTIMATED_TIME";
  static const String taskDefaultPlannedDateReminder = "TASK_DEFAULT_PLANNED_DATE_REMINDER";
  static const String taskDefaultPlannedDateReminderCustomOffset = "TASK_DEFAULT_PLANNED_DATE_REMINDER_CUSTOM_OFFSET";

  // Habit Settings
  static const String habitThreeStateEnabled = "HABIT_THREE_STATE_ENABLED";
  static const String habitReverseDayOrder = "HABIT_REVERSE_DAY_ORDER";

  // Changelog Settings
  static const String lastShownChangelogVersion = 'LAST_SHOWN_CHANGELOG_VERSION';
}
