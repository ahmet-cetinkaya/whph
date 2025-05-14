import 'package:auto_start_flutter/auto_start_flutter.dart' as auto_start_flutter;
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/domain/features/settings/constants/settings.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/application/shared/utils/key_helper.dart';

class AndroidStartupSettingsService implements IStartupSettingsService {
  final ISettingRepository _settingRepository;

  AndroidStartupSettingsService(this._settingRepository);

  @override
  Future<void> ensureStartupSettingSync() async {
    final setting = await _settingRepository.getByKey(Settings.startAtStartup);
    final shouldStart = setting?.value == 'true';

    if (shouldStart) {
      final isAvailable = await auto_start_flutter.isAutoStartAvailable;
      if (isAvailable == true) {
        await auto_start_flutter.getAutoStartPermission();
      }
    }
  }

  @override
  Future<bool> isEnabledAtStartup() async {
    final setting = await _settingRepository.getByKey(Settings.startAtStartup);
    return setting?.value == 'true';
  }

  @override
  Future<void> enableStartAtStartup() async {
    final isAvailable = await auto_start_flutter.isAutoStartAvailable;
    if (isAvailable == true) {
      await auto_start_flutter.getAutoStartPermission();
    }
    await _saveSetting(true);
  }

  @override
  Future<void> disableStartAtStartup() async {
    await _saveSetting(false);
  }

  Future<void> _saveSetting(bool isActive) async {
    final existingSetting = await _settingRepository.getByKey(Settings.startAtStartup);
    if (existingSetting != null) {
      existingSetting.value = isActive.toString();
      await _settingRepository.update(existingSetting);
    } else {
      await _settingRepository.add(Setting(
        id: KeyHelper.generateStringId(),
        key: Settings.startAtStartup,
        value: isActive.toString(),
        valueType: SettingValueType.bool,
        createdDate: DateTime.now(),
      ));
    }
  }
}
