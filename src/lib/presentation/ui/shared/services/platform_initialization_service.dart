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

/// Service responsible for platform-specific initialization
/// Handles desktop and mobile platform setup
class PlatformInitializationService {
  /// Runs desktop-specific initialization if on a desktop platform
  static Future<void> initializeDesktop(IContainer container) async {
    if (!(PlatformUtils.isDesktop)) {
      Logger.debug('PlatformInitializationService: Not a desktop platform, skipping desktop initialization');
      return;
    }

    final platformName = Platform.isWindows
        ? 'Windows'
        : Platform.isLinux
            ? 'Linux'
            : 'macOS';
    Logger.debug('PlatformInitializationService: Starting desktop initialization on $platformName...');

    // Configure desktop environment
    final setupService = container.resolve<ISetupService>();
    await setupService.setupEnvironment();

    // Initialize window manager and configure basic window properties
    await _initializeWindowManager(container);

    // Set up system tray integration
    await _initializeSystemTray(container);

    // Set up single instance focus handling
    await _initializeSingleInstanceFocusHandling(container);

    // Configure auto-start behavior
    await _configureStartupSettings(container);

    // Handle startup visibility based on launch arguments
    await _handleStartupVisibility(container);

    // Initialize WebSocket server for inter-process communication
    Logger.info('PlatformInitializationService: Starting WebSocket server on $platformName for sync communication...');
    startWebSocketServer();

    // Initialize sync scheduler (Desktop)
    try {
      Logger.info('PlatformInitializationService: Starting Desktop sync service...');
      final syncService = container.resolve<ISyncService>();
      // Fire and forget - don't await since interface returns void
      syncService.startSync();
      Logger.info('PlatformInitializationService: Desktop sync service started successfully');
    } catch (e, stackTrace) {
      Logger.error('PlatformInitializationService: Failed to start Desktop sync service: $e');
      Logger.error('StackTrace: $stackTrace');
    }

    Logger.debug('PlatformInitializationService: Desktop initialization completed on $platformName');
  }

  /// Runs mobile-specific initialization if on a mobile platform
  static Future<void> initializeMobile(IContainer container) async {
    if (!(PlatformUtils.isMobile)) {
      Logger.debug('PlatformInitializationService: Not a mobile platform, skipping mobile initialization');
      return;
    }

    final platformName = PlatformUtils.isMobile ? 'Android' : 'iOS';
    Logger.info('PlatformInitializationService: Starting mobile initialization on $platformName...');

    // Configure mobile environment
    final setupService = container.resolve<ISetupService>();
    await setupService.setupEnvironment();

    // Initialize sync scheduler (Android only)
    if (Platform.isAndroid) {
      Logger.info('PlatformInitializationService: Starting Android WorkManager sync service...');
      final mediator = container.resolve<Mediator>();
      final androidSyncService = AndroidSyncService(mediator);
      await androidSyncService.startSync();

      // Always start server mode for Android devices
      await _initializeAndroidServerMode(container);
    }

    Logger.info('PlatformInitializationService: Mobile initialization completed on $platformName');
  }

  /// Initializes and configures the window manager
  static Future<void> _initializeWindowManager(IContainer container) async {
    Logger.debug('PlatformInitializationService: Initializing window manager...');

    final windowManager = container.resolve<IWindowManager>();
    await windowManager.initialize();
    await windowManager.setPreventClose(true);
    await windowManager.setTitle(AppInfo.name);

    // Fix for missing taskbar icon on Linux (KDE/X11) by matching .desktop file StartupWMClass
    if (Platform.isLinux) {
      await windowManager.setWindowClass('whph');
    }

    Logger.debug('PlatformInitializationService: Window manager initialized');
  }

  /// Initializes system tray functionality
  static Future<void> _initializeSystemTray(IContainer container) async {
    Logger.debug('PlatformInitializationService: Initializing system tray...');

    final systemTrayService = container.resolve<ISystemTrayService>();
    await systemTrayService.init();

    Logger.debug('PlatformInitializationService: System tray initialized');
  }

  /// Initializes single instance focus handling
  static Future<void> _initializeSingleInstanceFocusHandling(IContainer container) async {
    Logger.debug('PlatformInitializationService: Setting up single instance focus handling...');

    try {
      final singleInstanceService = container.resolve<ISingleInstanceService>();
      final windowManager = container.resolve<IWindowManager>();

      // Set up listener for IPC commands (Focus, Sync, etc.)
      await singleInstanceService.startListeningForCommands((command) async {
        Logger.info('IPC command received: $command');

        if (command == 'SYNC') {
          // Handle remote sync trigger
          Logger.info('Triggering manual sync from IPC command');
          await singleInstanceService.broadcastMessage('Initializing remote sync...');

          StreamSubscription<SyncStatus>? statusSub;
          StreamSubscription<SyncProgress>? progressSub;
          try {
            final syncService = container.resolve<ISyncService>();

            // Listen to sync status changes (fire-and-forget)
            statusSub = syncService.syncStatusStream.listen((status) {
              // Unawaited broadcast - status updates are fire-and-forget
              singleInstanceService.broadcastMessage('[Status] ${status.state.name}').catchError((e) {
                Logger.error('Failed to broadcast status: $e');
                return false;
              });
            });

            // Listen to detailed progress (fire-and-forget)
            progressSub = syncService.progressStream.listen((progress) {
              final percentage = '${progress.progressPercentage.toStringAsFixed(0)}%';
              final msg = '${progress.operation} ${progress.currentEntity}'.trim();
              if (msg.isNotEmpty || percentage != '0%') {
                // Unawaited broadcast - progress updates are fire-and-forget
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
            // Cancel each subscription independently to ensure both are attempted
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
          // Default behavior: Focus the window (for 'FOCUS' or unknown commands)
          try {
            // Show and focus the window
            await windowManager.show();
            await windowManager.focus();
          } catch (e) {
            Logger.error('Failed to focus window: $e');
          }
        }
      });

      Logger.debug('PlatformInitializationService: Single instance focus handling initialized');
    } catch (e) {
      Logger.debug('Single instance service not available, skipping focus handling setup: $e');
    }
  }

  /// Configures auto-start behavior
  static Future<void> _configureStartupSettings(IContainer container) async {
    Logger.debug('PlatformInitializationService: Configuring startup settings...');

    final startupService = container.resolve<IStartupSettingsService>();
    await startupService.ensureStartupSettingSync();

    Logger.debug('PlatformInitializationService: Startup settings configured');
  }

  /// Handles startup visibility based on launch arguments
  static Future<void> _handleStartupVisibility(IContainer container) async {
    // Skip visibility handling during testing
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    Logger.debug('PlatformInitializationService: Handling startup visibility...');

    final windowManager = container.resolve<IWindowManager>();

    // Check if minimized startup argument is present
    final hasMinimizedArg = DesktopStartupService.shouldStartMinimized;

    Logger.debug('PlatformInitializationService: shouldStartMinimized: ${DesktopStartupService.shouldStartMinimized}');

    if (hasMinimizedArg) {
      await windowManager.hide();
      Logger.debug('PlatformInitializationService: Window hidden (started with minimized startup flag)');
    } else {
      await windowManager.show();
      Logger.debug('PlatformInitializationService: Window shown');
    }
  }

  /// Initialize server mode for Android devices (only if enabled by user preference)
  static Future<void> _initializeAndroidServerMode(IContainer container) async {
    const String serverModeSettingKey = 'sync_server_mode_enabled';

    try {
      // Check if user has enabled server mode preference
      final settingRepository = container.resolve<ISettingRepository>();
      final setting = await settingRepository.getByKey(serverModeSettingKey);
      final isServerModeEnabled = setting?.getValue<bool>() ?? false;

      if (!isServerModeEnabled) {
        Logger.debug('PlatformInitializationService: Server mode not enabled by user, skipping auto-start');
        return;
      }

      Logger.info(
          'PlatformInitializationService: Starting server mode for Android device (enabled by user preference)...');

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
