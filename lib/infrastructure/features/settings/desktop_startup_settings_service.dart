import 'dart:io';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/constants/app_args.dart';
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/domain/features/settings/constants/settings.dart';
import 'package:whph/domain/features/settings/setting.dart';

class DesktopStartupSettingsService implements IStartupSettingsService {
  final ISettingRepository _settingRepository;

  DesktopStartupSettingsService(this._settingRepository) {
    launchAtStartup.setup(
      appPath: Platform.resolvedExecutable,
      appName: AppInfo.name,
      args: [AppArgs.systemTray],
    );
  }

  @override
  Future<void> ensureStartupSettingSync() async {
    final setting = await _settingRepository.getByKey(Settings.startAtStartup);
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
    final setting = await _settingRepository.getByKey(Settings.startAtStartup);
    return setting?.value == 'true';
  }

  @override
  Future<void> enableStartAtStartup() async {
    await launchAtStartup.enable();
    await _saveSetting(true);
  }

  Future<void> _saveSetting(bool isActive) async {
    final existingSetting = await _settingRepository.getByKey(Settings.startAtStartup);
    if (existingSetting != null) {
      existingSetting.value = isActive.toString();
      await _settingRepository.update(existingSetting);
    } else {
      await _settingRepository.add(Setting(
        id: nanoid(),
        key: Settings.startAtStartup,
        value: isActive.toString(),
        valueType: SettingValueType.bool,
        createdDate: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> disableStartAtStartup() async {
    await launchAtStartup.disable();
    await _saveSetting(false);
  }
}
