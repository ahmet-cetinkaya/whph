import 'dart:async';
import 'dart:io';
import 'package:whph/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/shared/features/window/abstractions/i_window_manager.dart';
import 'package:whph/presentation/api/api.dart';
import 'package:whph/infrastructure/shared/services/desktop_startup_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:whph/infrastructure/android/features/sync/android_sync_service.dart';
import 'package:whph/infrastructure/android/features/sync/android_server_sync_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/infrastructure/linux/constants/linux_app_constants.dart';

class PlatformInitializationService {
  static Future<void> initializeDesktop(IContainer container) async {
    if (!(PlatformUtils.isDesktop)) return;

    final setupService = container.resolve<ISetupService>();
    await setupService.setupEnvironment();

    await _initializeWindowManager(container);
    await _initializeSystemTray(container);
    await _initializeSingleInstanceFocusHandling(container);
    await _configureStartupSettings(container);
    await _handleStartupVisibility(container);

    startWebSocketServer();

    try {
      final syncService = container.resolve<ISyncService>();
      syncService.startSync();
    } catch (e, stackTrace) {
      Logger.error('PlatformInitializationService: Failed to start Desktop sync service: $e');
      Logger.error('StackTrace: $stackTrace');
    }
  }

  static Future<void> initializeMobile(IContainer container) async {
    if (!(PlatformUtils.isMobile)) return;

    final setupService = container.resolve<ISetupService>();
    await setupService.setupEnvironment();

    if (Platform.isAndroid) {
      final mediator = container.resolve<Mediator>();
      final androidSyncService = AndroidSyncService(mediator);
      await androidSyncService.startSync();

      await _initializeAndroidServerMode(container);
    }

    // Initialize system tray for creating notification channels on Android
    await _initializeSystemTray(container);
  }

  static Future<void> _initializeWindowManager(IContainer container) async {
    final windowManager = container.resolve<IWindowManager>();
    await windowManager.initialize();
    await windowManager.setPreventClose(true);
    await windowManager.setTitle(AppInfo.name);

    if (Platform.isLinux) {
      await windowManager.setWindowClass(LinuxAppConstants.packageName);
    }
  }

  static Future<void> _initializeSystemTray(IContainer container) async {
    final systemTrayService = container.resolve<ISystemTrayService>();
    await systemTrayService.init();
  }

  static Future<void> _initializeSingleInstanceFocusHandling(IContainer container) async {
    try {
      final singleInstanceService = container.resolve<ISingleInstanceService>();
      final windowManager = container.resolve<IWindowManager>();

      // Set up listener for IPC commands (Focus, Sync, etc.)
      await singleInstanceService.startListeningForCommands((command) async {
        Logger.info('IPC command received: $command');

        if (command == 'SYNC') {
          Logger.info('Triggering manual sync from IPC command');
          await singleInstanceService.broadcastMessage('Initializing remote sync...');

          StreamSubscription<SyncStatus>? statusSub;
          StreamSubscription<SyncProgress>? progressSub;
          try {
            final syncService = container.resolve<ISyncService>();

            statusSub = syncService.syncStatusStream.listen((status) {
              singleInstanceService.broadcastMessage('[Status] ${status.state.name}').catchError((e) {
                Logger.error('Failed to broadcast status: $e');
                return false;
              });
            });

            progressSub = syncService.progressStream.listen((progress) {
              final percentage = '${progress.progressPercentage.toStringAsFixed(0)}%';
              final msg = '${progress.operation} ${progress.currentEntity}'.trim();
              if (msg.isNotEmpty || percentage != '0%') {
                singleInstanceService.broadcastMessage('[Progress] $msg $percentage'.trim()).catchError((e) {
                  Logger.error('Failed to broadcast progress: $e');
                  return false;
                });
              }
            });

            await syncService.runSync(isManual: true);

            await singleInstanceService.broadcastMessage('Sync operation completed.');
          } catch (e) {
            Logger.error('Failed to run sync from IPC: $e');
            try {
              await singleInstanceService.broadcastMessage('Error: Sync failed - $e');
            } catch (broadcastError) {
              Logger.error('Failed to broadcast error message: $broadcastError');
            }
          } finally {
            final errors = <Exception>[];

            if (statusSub != null) {
              try {
                await statusSub.cancel();
              } catch (e) {
                errors.add(Exception('Failed to cancel status subscription: $e'));
              }
            }

            if (progressSub != null) {
              try {
                await progressSub.cancel();
              } catch (e) {
                errors.add(Exception('Failed to cancel progress subscription: $e'));
              }
            }

            if (errors.isNotEmpty) {
              Logger.error('Errors during stream cleanup: ${errors.map((e) => e.toString()).join(', ')}');
            }

            try {
              await singleInstanceService.broadcastMessage('DONE');
            } catch (e) {
              Logger.error('Failed to send DONE message: $e');
            }
          }
        } else {
          try {
            await windowManager.show();
            await windowManager.focus();
          } catch (e) {
            Logger.error('Failed to focus window: $e');
          }
        }
      });
    } catch (e) {
      Logger.debug('Single instance service not available, skipping focus handling setup: $e');
    }
  }

  static Future<void> _configureStartupSettings(IContainer container) async {
    final startupService = container.resolve<IStartupSettingsService>();
    await startupService.ensureStartupSettingSync();
  }

  static Future<void> _handleStartupVisibility(IContainer container) async {
    // Skip during tests
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    final windowManager = container.resolve<IWindowManager>();
    final hasMinimizedArg = DesktopStartupService.shouldStartMinimized;

    if (hasMinimizedArg) {
      await windowManager.hide();
    } else {
      await windowManager.show();
    }
  }

  static Future<void> _initializeAndroidServerMode(IContainer container) async {
    const String serverModeSettingKey = 'sync_server_mode_enabled';

    try {
      final settingRepository = container.resolve<ISettingRepository>();
      final setting = await settingRepository.getByKey(serverModeSettingKey);
      final isServerModeEnabled = setting?.getValue<bool>() ?? false;

      if (!isServerModeEnabled) return;

      final serverSyncService = container.resolve<AndroidServerSyncService>();
      final success = await serverSyncService.startAsServer();

      if (success) {
        Logger.info('PlatformInitializationService: Android server mode started successfully for background sync');
      } else {
        Logger.warning('PlatformInitializationService: Failed to start Android server mode');
      }
    } catch (e) {
      Logger.error('PlatformInitializationService: Error initializing Android server mode: $e');
    }
  }
}
