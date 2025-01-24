import 'dart:io';

import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/infrastructure/features/app_usage/android_app_usage_service.dart';
import 'package:whph/infrastructure/features/app_usage/linux_app_usage_service.dart';
import 'package:whph/infrastructure/features/app_usage/windows_app_usage_service.dart';
import 'package:whph/infrastructure/features/settings/desktop_startup_settings_service.dart';
import 'package:whph/infrastructure/features/system_tray/mobile_system_tray_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/infrastructure/features/system_tray/system_tray_service.dart';
import 'package:whph/infrastructure/features/notification/mobile_notification_service.dart';

void registerInfrastructure(IContainer container) {
  final settingRepository = container.resolve<ISettingRepository>();

  container.registerSingleton<ISystemTrayService>(
      (_) => (Platform.isAndroid || Platform.isIOS) ? MobileSystemTrayService() : SystemTrayService());

  container.registerSingleton<INotificationService>(
      (_) => (Platform.isAndroid || Platform.isIOS) ? MobileNotificationService() : NotificationService());

  container.registerSingleton<IAppUsageService>((_) {
    final appUsageRepository = container.resolve<IAppUsageRepository>();
    final appUsageTimeRecordRepository = container.resolve<IAppUsageTimeRecordRepository>();
    final appUsageTagRuleRepository = container.resolve<IAppUsageTagRuleRepository>();
    final appUsageTagRepository = container.resolve<IAppUsageTagRepository>();
    final settingRepository = container.resolve<ISettingRepository>();

    if (Platform.isLinux) {
      return LinuxAppUsageService(appUsageRepository, appUsageTimeRecordRepository, appUsageTagRuleRepository,
          appUsageTagRepository, settingRepository);
    }

    if (Platform.isWindows) {
      return WindowsAppUsageService(appUsageRepository, appUsageTimeRecordRepository, appUsageTagRuleRepository,
          appUsageTagRepository, settingRepository);
    }

    if (Platform.isAndroid) {
      return AndroidAppUsageService(appUsageRepository, appUsageTimeRecordRepository, appUsageTagRuleRepository,
          appUsageTagRepository, settingRepository);
    }

    throw Exception('Unsupported platform for app usage service.');
  });

  container.registerSingleton<IStartupSettingsService>((_) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return DesktopStartupSettingsService(settingRepository);
    }

    throw Exception('Unsupported platform for startup settings service.');
  });
}
