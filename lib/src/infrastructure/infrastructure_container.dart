import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/infrastructure/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/src/infrastructure/features/setup/services/linux_setup_service.dart';
import 'package:whph/src/infrastructure/features/app_usage/android_app_usage_service.dart';
import 'package:whph/src/infrastructure/features/app_usage/linux_app_usage_service.dart';
import 'package:whph/src/infrastructure/features/app_usage/windows_app_usage_service.dart';
import 'package:whph/src/infrastructure/features/notification/desktop_notification_service.dart';
import 'package:whph/src/infrastructure/features/reminder/desktop_reminder_service.dart';
import 'package:whph/src/infrastructure/features/reminder/android_reminder_service.dart';
import 'package:whph/src/infrastructure/features/settings/android_startup_settings_service.dart';
import 'package:whph/src/infrastructure/features/settings/desktop_startup_settings_service.dart';
import 'package:whph/src/infrastructure/features/system_tray/mobile_system_tray_service.dart';
import 'package:whph/src/infrastructure/features/window/abstractions/i_window_manager.dart';
import 'package:whph/src/infrastructure/features/window/linux_window_manager.dart';
import 'package:whph/src/infrastructure/features/window/window_manager.dart';
import 'package:whph/src/infrastructure/features/wakelock/abstractions/i_wakelock_service.dart';
import 'package:whph/src/infrastructure/features/wakelock/wakelock_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/src/infrastructure/features/system_tray/system_tray_service.dart';
import 'package:whph/src/infrastructure/features/notification/mobile_notification_service.dart';
import 'package:whph/src/infrastructure/features/setup/services/windows_setup_service.dart';
import 'package:whph/src/infrastructure/features/setup/services/android_setup_service.dart';
import 'package:whph/src/infrastructure/features/file/android_file_service.dart';
import 'package:whph/src/infrastructure/features/file/desktop_file_service.dart';

void registerInfrastructure(IContainer container) {
  // Register Logger Service
  container.registerSingleton<ILogger>((_) => const ConsoleLogger());

  final settingRepository = container.resolve<ISettingRepository>();
  final appUsageIgnoreRuleRepository = container.resolve<IAppUsageIgnoreRuleRepository>();

  // Register DeviceInfoPlugin for device-specific information
  container.registerSingleton<DeviceInfoPlugin>((_) => DeviceInfoPlugin());

  // Register WindowManagerInterface
  container.registerSingleton<IWindowManager>((_) {
    if (Platform.isLinux) return LinuxWindowManager();
    return WindowManager();
  });

  container.registerSingleton<ISystemTrayService>(
      (_) => (Platform.isAndroid || Platform.isIOS) ? MobileSystemTrayService() : SystemTrayService());

  container.registerSingleton<INotificationService>((_) {
    final mediator = container.resolve<Mediator>();
    final payloadHandler = container.resolve<INotificationPayloadHandler>();

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      final windowManager = container.resolve<IWindowManager>();
      return DesktopNotificationService(mediator, windowManager, payloadHandler);
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return MobileNotificationService(mediator);
    }

    throw Exception('Unsupported platform for notification service.');
  });
  container.registerSingleton<IAppUsageService>((_) {
    final appUsageRepository = container.resolve<IAppUsageRepository>();
    final appUsageTimeRecordRepository = container.resolve<IAppUsageTimeRecordRepository>();
    final appUsageTagRuleRepository = container.resolve<IAppUsageTagRuleRepository>();
    final appUsageTagRepository = container.resolve<IAppUsageTagRepository>();

    if (Platform.isLinux) {
      return LinuxAppUsageService(appUsageRepository, appUsageTimeRecordRepository, appUsageTagRuleRepository,
          appUsageTagRepository, appUsageIgnoreRuleRepository);
    }

    if (Platform.isWindows) {
      return WindowsAppUsageService(appUsageRepository, appUsageTimeRecordRepository, appUsageTagRuleRepository,
          appUsageTagRepository, appUsageIgnoreRuleRepository);
    }

    if (Platform.isAndroid) {
      return AndroidAppUsageService(appUsageRepository, appUsageTimeRecordRepository, appUsageTagRuleRepository,
          appUsageTagRepository, appUsageIgnoreRuleRepository);
    }

    throw Exception('Unsupported platform for app usage service.');
  });

  container.registerSingleton<IStartupSettingsService>((_) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return DesktopStartupSettingsService(settingRepository);
    }

    if (Platform.isAndroid) {
      return AndroidStartupSettingsService(settingRepository);
    }

    throw Exception('Unsupported platform for startup settings service.');
  });

  container.registerSingleton<ISetupService>((_) {
    if (Platform.isLinux) return LinuxSetupService();
    if (Platform.isWindows) return WindowsSetupService();
    if (Platform.isAndroid) return AndroidSetupService();
    throw Exception('Unsupported platform for setup service.');
  });
  container.registerSingleton<IFileService>((_) {
    if (Platform.isAndroid) {
      return AndroidFileService();
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return DesktopFileService();
    }

    throw Exception('Unsupported platform for file service');
  });

  container.registerSingleton<IWakelockService>((_) => WakelockService(container.resolve<ILogger>()));

  container.registerSingleton<IReminderService>((_) {
    final windowManager = container.resolve<IWindowManager>();
    final notificationService = container.resolve<INotificationService>();

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return DesktopReminderService(windowManager, notificationService);
    }

    if (Platform.isAndroid) {
      return AndroidReminderService(notificationService);
    }

    if (Platform.isIOS) {
      // For iOS, we could create a dedicated iOS reminder service in the future
      // For now, we'll throw an exception
      throw Exception('iOS platform not supported for reminder service yet.');
    }

    throw Exception('Unsupported platform for reminder service.');
  });
}
