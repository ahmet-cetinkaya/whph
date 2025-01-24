abstract class IStartupSettingsService {
  Future<bool> isEnabledAtStartup();
  Future<void> enableStartAtStartup();
  Future<void> disableStartAtStartup();
  Future<void> ensureStartupSettingSync();
}
