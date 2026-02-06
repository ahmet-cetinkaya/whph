class SettingsTranslationKeys {
  static const String settingNotFoundError = 'settings.errors.setting_not_found';
  static const String versionMismatchError = 'settings.import.version_mismatch';
  static const String importFailedError = 'settings.import.error';
  static const String exportFailedError = 'settings.export.error';
  static const String migrationFailedError = 'settings.import.migration_failed';
  static const String unsupportedVersionError = 'settings.import.unsupported_version';
  static const String versionParseError = 'settings.import.version_parse_error';

  // Backup-specific errors
  static const String backupExportFailedError = 'settings.backup.export_failed';
  static const String backupImportFailedError = 'settings.backup.import_failed';
  static const String backupInvalidFormatError = 'settings.backup.invalid_format';
  static const String backupCorruptedError = 'settings.backup.corrupted';
  static const String backupCreateError = 'settings.backup.create_error';
  static const String integrityCheckError = 'settings.import.integrity_check_error';
  static const String importDataIntegrityError = 'settings.import.data_integrity_error';

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
}
