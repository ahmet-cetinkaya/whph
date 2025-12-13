import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_filter_service.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/app_usages/services/app_usage_filter_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/infrastructure/android/features/settings/android_startup_settings_service.dart';
import 'package:whph/infrastructure/desktop/features/notification/desktop_notification_service.dart';
import 'package:whph/infrastructure/desktop/features/reminder/desktop_reminder_service.dart';
import 'package:whph/infrastructure/desktop/settings/desktop_startup_settings_service.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_sync_service.dart';
import 'package:whph/infrastructure/linux/features/setup/linux_setup_service.dart';
import 'package:whph/infrastructure/android/features/app_usage/android_app_usage_service.dart';
import 'package:whph/infrastructure/android/features/sync/android_sync_service.dart';
import 'package:whph/infrastructure/android/features/sync/android_server_sync_service.dart';
import 'package:whph/infrastructure/linux/features/app_usages/linux_app_usage_service.dart';
import 'package:whph/infrastructure/linux/features/window/linux_window_manager.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/infrastructure/shared/features/window/abstractions/i_window_manager.dart';
import 'package:whph/infrastructure/shared/features/window/window_manager.dart';
import 'package:whph/infrastructure/windows/features/app_usages/windows_app_usage_service.dart';
import 'package:whph/infrastructure/android/features/reminder/android_reminder_service.dart';
import 'package:whph/infrastructure/mobile/features/system_tray/mobile_system_tray_service.dart';
import 'package:whph/infrastructure/shared/features/wakelock/abstractions/i_wakelock_service.dart';
import 'package:whph/infrastructure/shared/features/wakelock/wakelock_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_elevation_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_firewall_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_shortcut_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_update_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/windows_elevation_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/windows_firewall_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/windows_shortcut_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/windows_update_service.dart';
import 'package:whph/infrastructure/windows/features/setup/windows_setup_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/infrastructure/desktop/features/system_tray/desktop_system_tray_service.dart';
import 'package:whph/infrastructure/mobile/features/notification/mobile_notification_service.dart';
import 'package:whph/infrastructure/android/features/setup/android_setup_service.dart';
import 'package:whph/infrastructure/android/features/file_system/android_file_service.dart';
import 'package:whph/infrastructure/android/features/file_system/android_application_directory_service.dart';
import 'package:whph/infrastructure/desktop/features/file_system/desktop_file_service.dart';
import 'package:whph/infrastructure/desktop/features/single_instance/desktop_single_instance_service.dart';
import 'package:whph/infrastructure/linux/features/file_system/linux_application_directory_service.dart';
import 'package:whph/infrastructure/windows/features/file_system/windows_application_directory_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/device_id_service.dart';

void registerInfrastructure(IContainer container) {
  // Register Logger Service
  container.registerSingleton<ILogger>((_) => const ConsoleLogger());

  final settingRepository = container.resolve<ISettingRepository>();
  final appUsageIgnoreRuleRepository = container.resolve<IAppUsageIgnoreRuleRepository>();

  final appUsageFilterService = AppUsageFilterService(appUsageIgnoreRuleRepository);
  container.registerSingleton<IAppUsageFilterService>((_) => appUsageFilterService);

  // Register platform-specific application directory service
  container.registerSingleton<IApplicationDirectoryService>((_) {
    if (Platform.isAndroid) {
      return AndroidApplicationDirectoryService();
    }
    if (Platform.isWindows) {
      return WindowsApplicationDirectoryService();
    }
    if (Platform.isLinux) {
      return LinuxApplicationDirectoryService();
    }
    throw Exception('Unsupported platform for application directory service.');
  });

  // Register DeviceIdService after IApplicationDirectoryService is registered
  container.registerSingleton<IDeviceIdService>((_) => DeviceIdService(
        applicationDirectoryService: container.resolve<IApplicationDirectoryService>(),
      ));

  // Register DeviceInfoPlugin for device-specific information
  container.registerSingleton<DeviceInfoPlugin>((_) => DeviceInfoPlugin());

  // Register WindowManagerInterface
  container.registerSingleton<IWindowManager>((_) {
    if (Platform.isLinux) return LinuxWindowManager();
    return WindowManager();
  });

  container.registerSingleton<ISystemTrayService>(
      (_) => (PlatformUtils.isMobile) ? MobileSystemTrayService() : DesktopSystemTrayService());

  // Register single instance service (desktop only)
  if (PlatformUtils.isDesktop) {
    container.registerSingleton<ISingleInstanceService>((_) => DesktopSingleInstanceService());
  }

  container.registerSingleton<INotificationService>((_) {
    final mediator = container.resolve<Mediator>();
    final payloadHandler = container.resolve<INotificationPayloadHandler>();

    if (PlatformUtils.isDesktop) {
      final windowManager = container.resolve<IWindowManager>();
      return DesktopNotificationService(mediator, windowManager, payloadHandler);
    }
    if (PlatformUtils.isMobile) {
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
          appUsageTagRepository, appUsageFilterService);
    }
    if (Platform.isWindows) {
      return WindowsAppUsageService(appUsageRepository, appUsageTimeRecordRepository, appUsageTagRuleRepository,
          appUsageTagRepository, appUsageFilterService);
    }

    if (Platform.isAndroid) {
      return AndroidAppUsageService(appUsageRepository, appUsageTimeRecordRepository, appUsageTagRuleRepository,
          appUsageTagRepository, appUsageFilterService);
    }

    throw Exception('Unsupported platform for app usage service.');
  });

  container.registerSingleton<IStartupSettingsService>((_) {
    if (PlatformUtils.isDesktop) {
      return DesktopStartupSettingsService(settingRepository);
    }

    if (Platform.isAndroid) {
      return AndroidStartupSettingsService(settingRepository);
    }

    throw Exception('Unsupported platform for startup settings service.');
  });

  // Register Windows-specific setup services
  if (Platform.isWindows) {
    container.registerSingleton<IWindowsElevationService>((_) => WindowsElevationService());
    container.registerSingleton<IWindowsFirewallService>(
      (_) => WindowsFirewallService(
        elevationService: container.resolve<IWindowsElevationService>(),
      ),
    );
    container.registerSingleton<IWindowsShortcutService>((_) => WindowsShortcutService());
    container.registerSingleton<IWindowsUpdateService>((_) => WindowsUpdateService());
  }

  container.registerSingleton<ISetupService>((_) {
    if (Platform.isLinux) return LinuxSetupService();
    if (Platform.isWindows) {
      return WindowsSetupService(
        firewallService: container.resolve<IWindowsFirewallService>(),
        shortcutService: container.resolve<IWindowsShortcutService>(),
        updateService: container.resolve<IWindowsUpdateService>(),
      );
    }
    if (Platform.isAndroid) return AndroidSetupService();
    throw Exception('Unsupported platform for setup service.');
  });
  container.registerSingleton<IFileService>((_) {
    if (Platform.isAndroid) {
      return AndroidFileService();
    }

    if (PlatformUtils.isDesktop) {
      return DesktopFileService();
    }

    throw Exception('Unsupported platform for file service');
  });

  container.registerSingleton<IWakelockService>((_) => WakelockService(container.resolve<ILogger>()));

  container.registerSingleton<IReminderService>((_) {
    final windowManager = container.resolve<IWindowManager>();
    final notificationService = container.resolve<INotificationService>();

    if (PlatformUtils.isDesktop) {
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

  // Register ISyncService with platform-specific implementations
  container.registerSingleton<ISyncService>((_) {
    final mediator = container.resolve<Mediator>();

    if (PlatformUtils.isDesktop) {
      final deviceIdService = container.resolve<IDeviceIdService>();
      return DesktopSyncService(mediator, deviceIdService);
    }

    if (Platform.isAndroid) {
      return AndroidSyncService(mediator);
    }

    throw Exception('Unsupported platform for sync service.');
  });

  // Register AndroidServerSyncService as a separate service for mobile server mode
  container.registerSingleton<AndroidServerSyncService>((_) {
    final mediator = container.resolve<Mediator>();
    final deviceIdService = container.resolve<IDeviceIdService>();
    final deviceInfoPlugin = container.resolve<DeviceInfoPlugin>();
    return AndroidServerSyncService(mediator, deviceIdService, deviceInfoPlugin);
  });
}
