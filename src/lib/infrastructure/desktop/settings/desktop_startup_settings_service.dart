import 'dart:io';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/ui/shared/constants/app_args.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/features/settings/setting.dart';

class DesktopStartupSettingsService implements IStartupSettingsService {
  final ISettingRepository _settingRepository;

  DesktopStartupSettingsService(this._settingRepository);

  Future<void> _ensureSetup() async {
    if (!Platform.isWindows) return;

    try {
      launchAtStartup.setup(
        appPath: Platform.resolvedExecutable,
        appName: AppInfo.name,
        args: [AppArgs.minimized],
      );
    } catch (e) {
      // Ignore setup errors, startup functionality will be unavailable but app won't crash
    }
  }

  @override
  Future<void> ensureStartupSettingSync() async {
    await _ensureSetup();
    final setting =
        await _settingRepository.getByKey(SettingKeys.startAtStartup);
    final shouldStart = setting?.value == 'true';
    final isEnabled = await launchAtStartup.isEnabled();

    if (shouldStart && !isEnabled) {
      await launchAtStartup.enable();
    } else if (!shouldStart && isEnabled) {
      await launchAtStartup.disable();
    }
  }

  @override
  Future<bool> isEnabledAtStartup() async {
    final setting =
        await _settingRepository.getByKey(SettingKeys.startAtStartup);
    return setting?.value == 'true';
  }

  @override
  Future<void> enableStartAtStartup() async {
    await _ensureSetup();
    await launchAtStartup.enable();
    await _saveSetting(true);
  }

  Future<void> _saveSetting(bool isActive) async {
    final existingSetting =
        await _settingRepository.getByKey(SettingKeys.startAtStartup);
    if (existingSetting != null) {
      existingSetting.value = isActive.toString();
      await _settingRepository.update(existingSetting);
    } else {
      await _settingRepository.add(Setting(
        id: KeyHelper.generateStringId(),
        key: SettingKeys.startAtStartup,
        value: isActive.toString(),
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
      ));
    }
  }

  @override
  Future<void> disableStartAtStartup() async {
    await _ensureSetup();
    await launchAtStartup.disable();
    await _saveSetting(false);
  }
}
