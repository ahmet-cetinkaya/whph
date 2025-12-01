import 'package:whph/core/application/features/settings/constants/settings_translation_keys.dart' as application;

class SettingsTranslationKeys extends application.SettingsTranslationKeys {
  // Language Settings
  static const String languageTitle = 'settings.language.title';
  static const String languageChooseTitle = 'settings.language.choose_title';

  // Notifications
  static const String notificationsTitle = 'settings.notifications.title';
  static const String enableNotificationsError = 'settings.notifications.enable_error';
  static const String disableNotificationsError = 'settings.notifications.disable_error';

  // Sound Settings
  static const String soundTitle = 'settings.sound.title';
  static const String soundSubtitle = 'settings.sound.subtitle';
  static const String soundEnabled = 'settings.sound.enabled';
  static const String taskCompletionSound = 'settings.sound.task_completion';
  static const String habitCompletionSound = 'settings.sound.habit_completion';
  static const String timerControlSound = 'settings.sound.timer_control';
  static const String timerAlarmSound = 'settings.sound.timer_alarm';
  static const String enableSoundError = 'settings.sound.enable_error';
  static const String disableSoundError = 'settings.sound.disable_error';
  static const String soundsDisabled = 'settings.sound.sounds_disabled';
  static const String allSoundsEnabled = 'settings.sound.all_sounds_enabled';
  static const String someSoundsEnabled = 'settings.sound.some_sounds_enabled';

  // Startup Settings
  static const String startupTitle = 'settings.startup.title';
  static const String startupPermissionTitle = 'settings.permissions.startup.title';
  static const String startupSubtitle = 'settings.startup.subtitle';
  static const String startupDescription = 'settings.permissions.startup.description';
  static const String startupStep1 = 'settings.permissions.startup.steps.step1';
  static const String startupStep2 = 'settings.permissions.startup.steps.step2';
  static const String startupStep3 = 'settings.permissions.startup.steps.step3';
  static const String startupImportance = 'settings.permissions.startup.importance';
  static const String enableStartupError = 'settings.startup.enable_error';
  static const String disableStartupError = 'settings.startup.disable_error';

  // Settings Page
  static const String settingsTitle = 'settings.title';
  static const String syncDevicesTitle = 'settings.sync_devices.title';
  static const String aboutTitle = 'settings.about.title';
  static const String exportDataTitle = 'settings.export_data.title';
  static const String permissionsTitle = 'settings.permissions.title';

  // Export Data
  static const String exportSelectPath = 'settings.export.select_path';
  static const String exportSuccess = 'settings.export.success';
  static const String exportError = 'settings.export.error';
  static const String exportSelectType = 'settings.export.select_type';
  static const String exportSelectDirectory = 'settings.export.select_directory';
  static const String exportCanceled = 'settings.export.canceled';

  // Import/Export
  static const String exportCsvDescription = 'settings.export.csv_description';
  static const String exportJsonDescription = 'settings.export.json_description';
  static const String exportTitle = 'settings.export.title';
  static const String importError = 'settings.import.error';
  static const String importExportDescription = 'settings.import_export.description';
  static const String importExportSelectAction = 'settings.import_export.select_action';
  static const String importExportTitle = 'settings.import_export.title';
  static const String importSelectFile = 'settings.import.select_file';
  static const String importStrategyMerge = 'settings.import.strategy.merge';
  static const String importStrategyReplace = 'settings.import.strategy.replace';

  // Task Settings
  static const String taskSettingsTitle = 'settings.task.title';
  static const String taskPreferencesTitle = 'settings.task.preferences.title';
  static const String taskPreferencesDescription = 'settings.task.preferences.description';
  static const String taskDefaultEstimatedTimeTitle = 'settings.task.default_estimated_time.title';
  static const String taskDefaultEstimatedTimeDescription = 'settings.task.default_estimated_time.description';
  static const String taskDefaultEstimatedTimeDisabled = 'settings.task.default_estimated_time.disabled';
  static const String taskDefaultEstimatedTimeMinutes = 'settings.task.default_estimated_time.minutes';
  static const String taskDefaultEstimatedTimeLoadError = 'settings.task.default_estimated_time.load_error';
  static const String taskDefaultEstimatedTimeSaveError = 'settings.task.default_estimated_time.save_error';
  static const String taskDefaultEstimatedTimeKeyNotFound = 'settings.task.default_estimated_time.key_not_found';
  static const String importStrategyTitle = 'settings.import.strategy.title';
  static const String importSuccess = 'settings.import.success';
  static const String importTitle = 'settings.import.title';
  static const String importInProgress = 'settings.import.in_progress';
  static const String exportInProgress = 'settings.export.in_progress';

  // Permissions
  static const String permissionFixIt = 'settings.permissions.fix_it';
  static const String openSettings = 'settings.permissions.open_settings';
  static const String permissionGranted = 'settings.permissions.granted';
  static const String instructions = 'settings.permissions.instructions';

  // Firewall Permissions
  static const String firewallPermissionTitle = 'settings.permissions.firewall.title';
  static const String firewallPermissionDescription = 'settings.permissions.firewall.description';
  static const String firewallPermissionDialogDescription = 'settings.permissions.firewall.dialog_description';
  static const String firewallPermissionDialogInfoText = 'settings.permissions.firewall.dialog_info_text';
  static const String firewallLinuxManualConfirmationButton =
      'settings.permissions.firewall.linux_manual_confirmation_button';
  static const String firewallManualConfigureInstruction = 'settings.permissions.firewall.manual_configure_instruction';
  static const String firewallInstructionStepOpenTerminal =
      'settings.permissions.firewall.instructions.step_open_terminal';
  static const String firewallInstructionStepRunCommand = 'settings.permissions.firewall.instructions.step_run_command';
  static const String firewallInstructionStepOpenCommandPrompt =
      'settings.permissions.firewall.instructions.step_open_command_prompt';
  static const String firewallInstructionStepRunCommands =
      'settings.permissions.firewall.instructions.step_run_commands';
  static const String firewallInstructionStepClickConfirmation =
      'settings.permissions.firewall.instructions.step_click_confirmation';
  static const String firewallSaveConfirmationError = 'settings.permissions.firewall.save_confirmation_error';
  static const String firewallRuleAddedSuccess = 'settings.permissions.firewall.rule_added_success';
  static const String firewallRuleAddError = 'settings.permissions.firewall.rule_add_error';

  // Firewall Instructions - Linux
  static const String firewallInstructionLinuxStep1 = 'settings.permissions.firewall.instructions.linux.step1';
  static const String firewallInstructionLinuxStep2 = 'settings.permissions.firewall.instructions.linux.step2';
  static const String firewallInstructionLinuxStep3 = 'settings.permissions.firewall.instructions.linux.step3';
  static const String firewallInstructionLinuxStep4 = 'settings.permissions.firewall.instructions.linux.step4';

  // Firewall Instructions - Windows
  static const String firewallInstructionWindowsStep1 = 'settings.permissions.firewall.instructions.windows.step1';
  static const String firewallInstructionWindowsStep2 = 'settings.permissions.firewall.instructions.windows.step2';
  static const String firewallInstructionWindowsStep3 = 'settings.permissions.firewall.instructions.windows.step3';
  static const String firewallInstructionWindowsMethodGuiTitle =
      'settings.permissions.firewall.instructions.windows.method_gui_title';
  static const String firewallInstructionWindowsMethodCommandTitle =
      'settings.permissions.firewall.instructions.windows.method_command_title';
  static const String firewallInstructionLinuxMethodTerminalTitle =
      'settings.permissions.firewall.instructions.linux.method_terminal_title';
  static const String firewallInstructionWindowsAlternativeCommandPromptTitle =
      'settings.permissions.firewall.instructions.windows.alternative_command_prompt.title';
  static const String firewallInstructionWindowsAlternativeCommandPromptCmdStep1 =
      'settings.permissions.firewall.instructions.windows.alternative_command_prompt.steps.cmd_step1';
  static const String firewallInstructionWindowsAlternativeCommandPromptCmdStep2 =
      'settings.permissions.firewall.instructions.windows.alternative_command_prompt.steps.cmd_step2';
  static const String firewallInstructionWindowsStepOpenDefender =
      'settings.permissions.firewall.instructions.windows.step_open_defender';
  static const String firewallInstructionWindowsStepCreateInboundRule =
      'settings.permissions.firewall.instructions.windows.step_create_inbound_rule';
  static const String firewallInstructionWindowsStepCreateOutboundRule =
      'settings.permissions.firewall.instructions.windows.step_create_outbound_rule';

  // Firewall Automatic Actions - Windows
  static const String firewallAddRuleButtonText = 'settings.permissions.firewall.add_rule_button';
  static const String firewallWindowsAutoDescription = 'settings.permissions.firewall.windows_auto_description';

  // Battery Optimization
  static const String batteryOptimizationTitle = 'settings.permissions.battery_optimization.title';
  static const String batteryOptimizationDescription = 'settings.permissions.battery_optimization.description';
  static const String batteryOptimizationStep1 = 'settings.permissions.battery_optimization.steps.step1';
  static const String batteryOptimizationStep2 = 'settings.permissions.battery_optimization.steps.step2';
  static const String batteryOptimizationStep3 = 'settings.permissions.battery_optimization.steps.step3';
  static const String batteryOptimizationStep4 = 'settings.permissions.battery_optimization.steps.step4';
  static const String batteryOptimizationStep5 = 'settings.permissions.battery_optimization.steps.step5';
  static const String batteryOptimizationStep6 = 'settings.permissions.battery_optimization.steps.step6';
  static const String batteryOptimizationImportance = 'settings.permissions.battery_optimization.importance';

  // Notification Permission
  static const String notificationPermissionTitle = 'settings.permissions.notification.title';
  static const String notificationPermissionDescription = 'settings.permissions.notification.description';
  static const String notificationPermissionStepAndroid1 = 'settings.permissions.notification.steps.android.step1';
  static const String notificationPermissionStepAndroid2 = 'settings.permissions.notification.steps.android.step2';
  static const String notificationPermissionStepIOS1 = 'settings.permissions.notification.steps.ios.step1';
  static const String notificationPermissionStepIOS2 = 'settings.permissions.notification.steps.ios.step2';

  // Exact Alarm Permission
  static const String exactAlarmTitle = 'settings.permissions.exact_alarm.title';
  static const String exactAlarmDescription = 'settings.permissions.exact_alarm.description';
  static const String exactAlarmStep1 = 'settings.permissions.exact_alarm.steps.step1';
  static const String exactAlarmStepAndroid12Plus2 = 'settings.permissions.exact_alarm.steps.android12plus.step2';
  static const String exactAlarmStepAndroid12Plus3 = 'settings.permissions.exact_alarm.steps.android12plus.step3';
  static const String exactAlarmStep2 = 'settings.permissions.exact_alarm.steps.step2';

  // App Usage Permission
  static const String appUsageTitle = 'settings.permissions.app_usage.title';
  static const String appUsageDescription = 'settings.permissions.app_usage.description';
  static const String appUsageStep1 = 'settings.permissions.app_usage.steps.step1';
  static const String appUsageStep2 = 'settings.permissions.app_usage.steps.step2';
  static const String appUsageStep3 = 'settings.permissions.app_usage.steps.step3';
  static const String appUsageStep4 = 'settings.permissions.app_usage.steps.step4';

  // Backup
  static const String backupTitle = 'settings.backup.title';
  static const String backupDescription = 'settings.backup.description';
  static const String backupExportTitle = 'settings.backup.export.title';
  static const String backupImportTitle = 'settings.backup.import.title';
  static const String backupExportDescription = 'settings.backup.export.description';
  static const String backupImportDescription = 'settings.backup.import.description';
  static const String backupExportInProgress = 'settings.backup.export.in_progress';
  static const String backupImportInProgress = 'settings.backup.import.in_progress';
  static const String backupExportSuccess = 'settings.backup.export.success';
  static const String backupImportSuccess = 'settings.backup.import.success';
  static const String backupExportError = 'settings.backup.export.error';
  static const String backupImportError = 'settings.backup.import.error';
  static const String backupSelectFile = 'settings.backup.import.select_file';
  static const String backupSelectPath = 'settings.backup.export.select_path';
  static const String backupStrategyTitle = 'settings.backup.import.strategy.title';
  static const String backupStrategyReplace = 'settings.backup.import.strategy.replace';
  static const String backupStrategyMerge = 'settings.backup.import.strategy.merge';
  static const String backupCanceled = 'settings.backup.canceled';
  static const String backupInvalidFormatError = 'settings.backup.invalid_format_error';

  // Theme Settings
  static const String themeTitle = 'settings.theme.title';
  static const String themeDescription = 'settings.theme.description';
  static const String themeModeTitle = 'settings.theme.mode.title';
  static const String themeModeLight = 'settings.theme.mode.light';
  static const String themeModeDark = 'settings.theme.mode.dark';
  static const String themeModeAuto = 'settings.theme.mode.auto.title';
  static const String themeModeAutoDescription = 'settings.theme.mode.auto.description';
  static const String dynamicAccentColorTitle = 'settings.theme.dynamic_accent.title';
  static const String dynamicAccentColorDescription = 'settings.theme.dynamic_accent.description';
  static const String dynamicAccentColorFeature = 'settings.theme.dynamic_accent.feature';
  static const String customAccentColorTitle = 'settings.theme.custom_accent.title';
  static const String customAccentColorDescription = 'settings.theme.custom_accent.description';
  static const String customAccentColorFeature = 'settings.theme.custom_accent.feature';
  static const String themeSettingsError = 'settings.theme.error';

  // UI Density Settings
  static const String uiDensityTitle = 'settings.ui_density.title';
  static const String uiDensityDescription = 'settings.ui_density.description';
  static const String uiDensityCompact = 'settings.ui_density.compact';
  static const String uiDensityNormal = 'settings.ui_density.normal';
  static const String uiDensityLarge = 'settings.ui_density.large';
  static const String uiDensityLarger = 'settings.ui_density.larger';
  static const String uiDensitySettingsError = 'settings.ui_density.error';

  // Advanced Settings
  static const String advancedSettingsTitle = 'settings.advanced.title';
  static const String advancedSettingsDescription = 'settings.advanced.description';

  // Debug Logs Settings
  static const String debugLogsTitle = 'settings.debug_logs.title';
  static const String debugLogsDescription = 'settings.debug_logs.description';
  static const String viewLogsTitle = 'settings.debug_logs.view.title';
  static const String viewLogsDescription = 'settings.debug_logs.view.description';
  static const String debugLogsLoadSettingsError = 'settings.debug_logs.load_settings_error';
  static const String debugLogsUpdateSettingsError = 'settings.debug_logs.update_settings_error';

  // Debug Logs Page
  static const String debugLogsPageTitle = 'settings.debug_logs.page.title';
  static const String debugLogsPageDescription = 'settings.debug_logs.page.description';
  static const String debugLogsContent = 'settings.debug_logs.page.content';
  static const String debugLogsRefresh = 'settings.debug_logs.page.refresh';
  static const String debugLogsCopy = 'settings.debug_logs.page.copy';
  static const String debugLogsSaveAs = 'settings.debug_logs.page.save_as';
  static const String debugLogsCopied = 'settings.debug_logs.page.copied';
  static const String debugLogsLoadError = 'settings.debug_logs.page.load_error';
  static const String debugLogsNotEnabled = 'settings.debug_logs.page.not_enabled';
  static const String debugLogsNoFile = 'settings.debug_logs.page.no_file';
  static const String debugLogsEmpty = 'settings.debug_logs.page.empty';

  // Export Logs
  static const String exportLogsDialogTitle = 'settings.debug_logs.export.dialog_title';
  static const String exportLogsError = 'settings.debug_logs.export.error';
  static const String exportLogsSuccess = 'settings.debug_logs.export.success';
  static const String exportLogsNoLogsAvailable = 'settings.debug_logs.export.no_logs_available';
  static const String exportLogsFileNotExist = 'settings.debug_logs.export.file_not_exist';

  // Reset Database
  static const String resetDatabaseTitle = 'settings.advanced.reset_database.title';
  static const String resetDatabaseDescription = 'settings.advanced.reset_database.description';
  static const String resetDatabaseDialogTitle = 'settings.advanced.reset_database.dialog.title';
  static const String resetDatabaseDialogWarning = 'settings.advanced.reset_database.dialog.warning';
  static const String resetDatabaseDialogConfirmText = 'settings.advanced.reset_database.dialog.confirm_text';
  static const String resetDatabaseDialogResetting = 'settings.advanced.reset_database.dialog.resetting';
  static const String resetDatabaseErrorTitle = 'settings.advanced.reset_database.error.title';
  static const String resetDatabaseErrorMessage = 'settings.advanced.reset_database.error.message';
  static const String resetDatabaseErrorCancel = 'settings.advanced.reset_database.error.cancel';
  static const String resetDatabaseErrorRetry = 'settings.advanced.reset_database.error.retry';
  static const String resetDatabaseRestartScreenCompletedTitle = 'settings.advanced.reset_database.restart_screen.completed_title';
  static const String resetDatabaseRestartScreenDesktopMessage =
      'settings.advanced.reset_database.restart_screen.desktop_message';
  static const String resetDatabaseRestartScreenMobileMessage =
      'settings.advanced.reset_database.restart_screen.mobile_message';
  static const String resetDatabaseRestartNowButton =
      'settings.advanced.reset_database.restart_screen.restart_now_button';
}
