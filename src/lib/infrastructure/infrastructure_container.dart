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
import 'package:whph/core/application/shared/services/abstraction/i_application_shutdown_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/infrastructure/android/features/app_usage/android_app_usage_service.dart';
import 'package:whph/infrastructure/android/features/reminder/android_reminder_service.dart';
import 'package:whph/infrastructure/android/features/settings/android_startup_settings_service.dart';
import 'package:whph/infrastructure/android/features/sync/android_server_sync_service.dart';
import 'package:whph/infrastructure/android/features/sync/android_sync_service.dart';
import 'package:whph/infrastructure/desktop/features/notification/desktop_notification_service.dart';
import 'package:whph/infrastructure/desktop/features/reminder/desktop_reminder_service.dart';
import 'package:whph/infrastructure/desktop/features/system_tray/desktop_system_tray_service.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_sync_service.dart';
import 'package:whph/infrastructure/desktop/settings/desktop_startup_settings_service.dart';
import 'package:whph/infrastructure/linux/features/app_usages/linux_app_usage_service.dart';
import 'package:whph/infrastructure/linux/features/notification/flatpak_notification_service.dart';
import 'package:whph/infrastructure/linux/features/setup/linux_setup_service.dart';
import 'package:whph/infrastructure/linux/features/setup/services/abstraction/i_linux_desktop_service.dart';
import 'package:whph/infrastructure/linux/features/setup/services/abstraction/i_linux_firewall_service.dart';
import 'package:whph/infrastructure/linux/features/setup/services/abstraction/i_linux_kde_service.dart';
import 'package:whph/infrastructure/linux/features/setup/services/abstraction/i_linux_update_service.dart';
import 'package:whph/infrastructure/linux/features/setup/services/linux_desktop_service.dart';
import 'package:whph/infrastructure/linux/features/setup/services/linux_firewall_service.dart';
import 'package:whph/infrastructure/linux/features/setup/services/linux_kde_service.dart';
import 'package:whph/infrastructure/linux/features/setup/services/linux_update_service.dart';
import 'package:whph/infrastructure/linux/features/system_tray/flatpak_system_tray_service.dart';
import 'package:whph/infrastructure/linux/features/window/linux_window_manager.dart';
import 'package:whph/infrastructure/mobile/features/notification/mobile_notification_service.dart';
import 'package:whph/infrastructure/mobile/features/system_tray/mobile_system_tray_service.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/infrastructure/shared/features/notification/habit_notification_handler.dart';
import 'package:whph/infrastructure/shared/features/notification/task_notification_handler.dart';
import 'package:whph/infrastructure/shared/features/wakelock/abstractions/i_wakelock_service.dart';
import 'package:whph/infrastructure/shared/features/wakelock/wakelock_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_store.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_operation_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_operation_store.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_transfer_file_store.dart';
import 'package:whph/infrastructure/shared/features/window/abstractions/i_window_manager.dart';
import 'package:whph/infrastructure/shared/features/window/window_manager.dart';
import 'package:whph/infrastructure/windows/features/app_usages/windows_app_usage_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_elevation_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_firewall_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_shortcut_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_update_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/windows_elevation_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/windows_firewall_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/windows_shortcut_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/windows_update_service.dart';
import 'package:whph/infrastructure/windows/features/setup/windows_setup_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_habit_notification_handler.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_task_notification_handler.dart';
import 'package:whph/infrastructure/android/features/setup/android_setup_service.dart';
import 'package:whph/infrastructure/android/features/file_system/android_file_service.dart';
import 'package:whph/infrastructure/android/features/file_system/android_application_directory_service.dart';
import 'package:whph/infrastructure/desktop/features/file_system/desktop_file_service.dart';
import 'package:whph/infrastructure/desktop/features/single_instance/desktop_single_instance_service.dart';
import 'package:whph/infrastructure/linux/features/file_system/linux_application_directory_service.dart';
import 'package:whph/infrastructure/windows/features/file_system/windows_application_directory_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/device_id_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';

void registerInfrastructure(
  IContainer container, {
  IApplicationDirectoryService? applicationDirectoryService,
}) {
  container.registerSingleton<ILogger>((_) => const ConsoleLogger());

  final settingRepository = container.resolve<ISettingRepository>();
  final appUsageIgnoreRuleRepository = container.resolve<IAppUsageIgnoreRuleRepository>();

  final appUsageFilterService = AppUsageFilterService(appUsageIgnoreRuleRepository);
  container.registerSingleton<IAppUsageFilterService>((_) => appUsageFilterService);

  container.registerSingleton<IApplicationDirectoryService>((_) {
    if (applicationDirectoryService != null) {
      return applicationDirectoryService;
    }
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

  container.registerSingleton<McpAccessStore>(
    (_) => McpAccessStore(
      applicationDirectoryService: container.resolve<IApplicationDirectoryService>(),
    ),
  );
  container.registerSingleton<IMcpAccessService>(
    (_) => McpAccessService(store: container.resolve<McpAccessStore>()),
  );
  container.registerSingleton<McpOperationStore>(
    (_) => McpOperationStore(
      applicationDirectoryService: container.resolve<IApplicationDirectoryService>(),
    ),
  );
  container.registerSingleton<IMcpOperationService>(
    (_) => McpOperationService(
      store: container.resolve<McpOperationStore>(),
      accessService: container.resolve<IMcpAccessService>(),
    ),
  );
  container.registerSingleton<McpTransferFileStore>(
    (_) => McpTransferFileStore(
      applicationDirectoryService: container.resolve<IApplicationDirectoryService>(),
      accessService: container.resolve<IMcpAccessService>(),
    ),
  );

  container.registerSingleton<IDeviceIdService>((_) => DeviceIdService(
        applicationDirectoryService: container.resolve<IApplicationDirectoryService>(),
      ));

  container.registerSingleton<DeviceInfoPlugin>((_) => DeviceInfoPlugin());

  container.registerSingleton<IWindowManager>((_) {
    if (Platform.isLinux) return LinuxWindowManager();
    return WindowManager();
  });

  container.registerSingleton<INotificationService>((_) {
    final mediator = container.resolve<Mediator>();
    final payloadHandler = container.resolve<INotificationPayloadHandler>();

    if (PlatformUtils.isDesktop) {
      final windowManager = container.resolve<IWindowManager>();

      if (Platform.isLinux && Platform.environment.containsKey('FLATPAK_ID')) {
        return FlatpakNotificationService(mediator, windowManager, payloadHandler);
      }

      final taskHandler = container.resolve<ITaskNotificationHandler>();
      return DesktopNotificationService(mediator, windowManager, payloadHandler, taskHandler);
    }
    if (PlatformUtils.isMobile) {
      return MobileNotificationService(mediator);
    }

    throw Exception('Unsupported platform for notification service.');
  });

  container.registerSingleton<ITaskNotificationHandler>((_) {
    final mediator = container.resolve<Mediator>();
    return TaskNotificationHandler(mediator);
  });

  container.registerSingleton<IHabitNotificationHandler>((_) {
    final mediator = container.resolve<Mediator>();
    return HabitNotificationHandler(mediator);
  });

  container.registerSingleton<ISystemTrayService>((_) {
    if (PlatformUtils.isMobile) {
      // Reuse MobileNotificationService plugin to prevent second .initialize() call
      final notificationService = container.resolve<INotificationService>() as MobileNotificationService;
      return MobileSystemTrayService(notificationService.plugin);
    }

    if (Platform.isLinux && Platform.environment.containsKey('FLATPAK_ID')) {
      return FlatpakSystemTrayService(
        shutdownApplication: () => container.resolve<IApplicationShutdownService>().shutdown(),
      );
    }

    return DesktopSystemTrayService(
      shutdownApplication: () => container.resolve<IApplicationShutdownService>().shutdown(),
    );
  });

  if (PlatformUtils.isDesktop) {
    container.registerSingleton<ISingleInstanceService>((_) => DesktopSingleInstanceService());
  }
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

  if (Platform.isLinux) {
    container.registerSingleton<ILinuxFirewallService>((_) => LinuxFirewallService());

    final linuxUpdateService = LinuxUpdateService();
    container.registerSingleton<ILinuxUpdateService>((_) => linuxUpdateService);

    container.registerSingleton<ILinuxDesktopService>(
      (_) => LinuxDesktopService(
        getExecutablePath: linuxUpdateService.getExecutablePath,
        getAppVersion: linuxUpdateService.getAppVersion,
      ),
    );

    container.registerSingleton<ILinuxKdeService>(
      (_) => LinuxKdeService(
        getExecutablePath: linuxUpdateService.getExecutablePath,
      ),
    );
  }

  container.registerSingleton<ISetupService>((_) {
    if (Platform.isLinux) {
      return LinuxSetupService(
        firewallService: container.resolve<ILinuxFirewallService>(),
        desktopService: container.resolve<ILinuxDesktopService>(),
        kdeService: container.resolve<ILinuxKdeService>(),
        updateService: container.resolve<ILinuxUpdateService>(),
      );
    }
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

  // Registered explicitly for AppBootstrapService cleanup resolution
  if (PlatformUtils.isDesktop) {
    container.registerSingleton<DesktopSyncService>((_) {
      final mediator = container.resolve<Mediator>();
      final deviceIdService = container.resolve<IDeviceIdService>();
      return DesktopSyncService(
        mediator,
        deviceIdService,
        restoreBarrier: container.resolve<IRestoreBarrier>(),
      );
    });
  }

  container.registerSingleton<ISyncService>((_) {
    final mediator = container.resolve<Mediator>();

    if (PlatformUtils.isDesktop) {
      return container.resolve<DesktopSyncService>();
    }

    if (Platform.isAndroid) {
      return AndroidSyncService(
        mediator,
        restoreBarrier: container.resolve<IRestoreBarrier>(),
      );
    }

    throw Exception('Unsupported platform for sync service.');
  });

  container.registerSingleton<AndroidServerSyncService>((_) {
    final mediator = container.resolve<Mediator>();
    final deviceIdService = container.resolve<IDeviceIdService>();
    final deviceInfoPlugin = container.resolve<DeviceInfoPlugin>();
    return AndroidServerSyncService(
      mediator,
      deviceIdService,
      deviceInfoPlugin,
      restoreBarrier: container.resolve<IRestoreBarrier>(),
    );
  });
}
