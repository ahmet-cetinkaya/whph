import 'package:android_intent_plus/android_intent.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/shared/utils/logger.dart';

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
      Logger.error('Manufacturer-specific auto-start settings failed: $e');

      try {
        // Fallback to general app settings
        await _openAppSettings();
      } catch (e2) {
        Logger.error('App settings fallback failed: $e2');

        try {
          // Final fallback to device settings
          await _openDeviceSettings();
        } catch (e3) {
          Logger.error('All auto-start settings attempts failed: $e3');
        }
      }
    }
  }

  /// Try manufacturer-specific auto-start settings
  Future<void> _tryManufacturerSpecificSettings() async {
    // List of common manufacturer auto-start intents with component names
    final List<Map<String, String>> autoStartIntents = [
      // MIUI (Xiaomi) - Auto-start permissions
      {
        'action': 'miui.intent.action.APP_PERM_EDITOR',
        'component': 'com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity',
      },
      // EMUI (Huawei) - Startup manager
      {
        'action': 'huawei.intent.action.HSM_BOOTAPP_MANAGER',
        'component': 'com.huawei.systemmanager/.startupmgr.ui.StartupNormalAppListActivity',
      },
      // ColorOS (OPPO) - Auto-start management
      {
        'action': 'com.coloros.safecenter.permission.startup',
        'component': 'com.coloros.safecenter/.permission.startup.StartupAppListActivity',
      },
      // FunTouch OS (Vivo) - Auto-start management
      {
        'action': 'com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
        'component': 'com.vivo.permissionmanager/.activity.BgStartUpManagerActivity',
      },
      // Samsung - Auto-start apps
      {
        'action': 'com.samsung.android.sm.ACTION_AUTO_START_APP_LIST',
        'component': 'com.samsung.android.sm/.ui.battery.BatteryActivity',
      },
      // OnePlus - Auto-launch management
      {
        'action': 'com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity',
        'component': 'com.oneplus.security/.chainlaunch.view.ChainLaunchAppListActivity',
      },
      // Realme - Auto-start management
      {
        'action': 'com.android.settings.APPLICATION_DETAILS_SETTINGS',
        'component': 'com.android.settings/.applications.appinfo.AppInfoDashboardFragment',
      },
    ];

    // Try each manufacturer-specific intent with component
    for (final intentData in autoStartIntents) {
      try {
        final intent = AndroidIntent(
          action: intentData['action']!,
          componentName: intentData['component'],
          arguments: <String, dynamic>{
            'packageName': AndroidAppConstants.packageName,
          },
        );
        await intent.launch();
        return; // Success, exit the method
      } catch (e) {
        Logger.error('Failed intent: ${intentData['action']} - ${e.toString()}');
        continue;
      }
    }

    // Try simple action intents without component names
    final List<String> fallbackActions = [
      'miui.intent.action.APP_PERM_EDITOR',
      'huawei.intent.action.HSM_BOOTAPP_MANAGER',
      'com.coloros.safecenter.permission.startup',
      'android.settings.AUTO_START_SETTINGS',
    ];

    for (final action in fallbackActions) {
      try {
        final intent = AndroidIntent(
          action: action,
          data: 'package:${AndroidAppConstants.packageName}',
        );
        await intent.launch();
        return; // Success, exit the method
      } catch (e) {
        continue;
      }
    }

    throw Exception('No manufacturer-specific auto-start settings found');
  }

  /// Fallback to general app settings
  Future<void> _openAppSettings() async {
    try {
      // Try to open specific power/battery management settings first
      final intent = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      await intent.launch();
    } catch (e) {
      try {
        // Fallback to app details settings
        final intent = AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:${AndroidAppConstants.packageName}',
        );
        await intent.launch();
      } catch (e2) {
        // Final fallback to power usage summary
        final intent = AndroidIntent(
          action: 'android.settings.POWER_USAGE_SUMMARY',
        );
        await intent.launch();
      }
    }
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
        createdDate: DateTime.now().toUtc(),
      ));
    }
  }
}
