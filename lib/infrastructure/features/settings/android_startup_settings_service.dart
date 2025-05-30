import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/presentation/shared/constants/setting_keys.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/application/shared/utils/key_helper.dart';

class AndroidStartupSettingsService implements IStartupSettingsService {
  final ISettingRepository _settingRepository;

  AndroidStartupSettingsService(this._settingRepository);

  @override
  Future<void> ensureStartupSettingSync() async {
    final setting = await _settingRepository.getByKey(SettingKeys.startAtStartup);
    final shouldStart = setting?.value == 'true';

    if (shouldStart) {
      // For Android, we can't programmatically enable auto-start
      // The user needs to manually enable it through system settings
      await _openAutoStartSettings();
    }
  }

  @override
  Future<bool> isEnabledAtStartup() async {
    final setting = await _settingRepository.getByKey(SettingKeys.startAtStartup);
    return setting?.value == 'true';
  }

  @override
  Future<void> enableStartAtStartup() async {
    // Open auto-start settings for user to manually enable
    await _openAutoStartSettings();
    await _saveSetting(true);
  }

  @override
  Future<void> disableStartAtStartup() async {
    await _saveSetting(false);
  }

  /// Opens Android auto-start/autorun settings using native intents
  /// Tries multiple approaches to handle different Android manufacturers
  Future<void> _openAutoStartSettings() async {
    try {
      // Try manufacturer-specific auto-start settings first
      await _tryManufacturerSpecificSettings();
    } catch (e) {
      if (kDebugMode) debugPrint('Manufacturer-specific auto-start settings failed: $e');

      try {
        // Fallback to general app settings
        await _openAppSettings();
      } catch (e2) {
        if (kDebugMode) debugPrint('App settings fallback failed: $e2');

        try {
          // Final fallback to device settings
          await _openDeviceSettings();
        } catch (e3) {
          if (kDebugMode) debugPrint('All auto-start settings attempts failed: $e3');
        }
      }
    }
  }

  /// Try manufacturer-specific auto-start settings
  Future<void> _tryManufacturerSpecificSettings() async {
    // List of common manufacturer auto-start intents
    final List<String> autoStartActions = [
      // MIUI (Xiaomi)
      'miui.intent.action.APP_PERM_EDITOR',
      // EMUI (Huawei)
      'huawei.intent.action.HSM_BOOTAPP_MANAGER',
      // ColorOS (OPPO)
      'com.coloros.safecenter.permission.startup',
      // FunTouch (Vivo)
      'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity',
      // Samsung
      'com.samsung.android.sm.ACTION_AUTO_START_APP_LIST',
      // OnePlus
      'com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity',
      // Generic auto-start
      'android.settings.AUTO_START_SETTINGS',
    ];

    // Try each auto-start action
    for (final action in autoStartActions) {
      try {
        final intent = AndroidIntent(
          action: action,
          arguments: <String, dynamic>{
            'packageName': AndroidAppConstants.packageName,
          },
        );
        await intent.launch();
        return; // Success, exit the method
      } catch (e) {
        // Continue to next action
        continue;
      }
    }

    // If all manufacturer-specific attempts failed, try with package data
    for (final action in autoStartActions) {
      try {
        final intent = AndroidIntent(
          action: action,
          data: 'package:${AndroidAppConstants.packageName}',
        );
        await intent.launch();
        return; // Success, exit the method
      } catch (e) {
        // Continue to next action
        continue;
      }
    }

    throw Exception('No manufacturer-specific auto-start settings found');
  }

  /// Fallback to general app settings
  Future<void> _openAppSettings() async {
    final intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:${AndroidAppConstants.packageName}',
    );
    await intent.launch();
  }

  /// Final fallback to device settings
  Future<void> _openDeviceSettings() async {
    final intent = AndroidIntent(
      action: 'android.settings.SETTINGS',
    );
    await intent.launch();
  }

  Future<void> _saveSetting(bool isActive) async {
    final existingSetting = await _settingRepository.getByKey(SettingKeys.startAtStartup);
    if (existingSetting != null) {
      existingSetting.value = isActive.toString();
      await _settingRepository.update(existingSetting);
    } else {
      await _settingRepository.add(Setting(
        id: KeyHelper.generateStringId(),
        key: SettingKeys.startAtStartup,
        value: isActive.toString(),
        valueType: SettingValueType.bool,
        createdDate: DateTimeHelper.toUtcDateTime(DateTime.now()),
      ));
    }
  }
}
