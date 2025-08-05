import 'dart:io';
import 'package:whph/src/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/src/infrastructure/shared/features/window/abstractions/i_window_manager.dart';
import 'package:whph/src/presentation/api/api.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_args.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/src/infrastructure/android/features/sync/android_sync_service.dart';
import 'package:whph/src/infrastructure/android/features/sync/android_server_sync_service.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/src/core/application/features/sync/services/v2/sync_registry_initializer.dart';
import 'package:whph/src/core/application/features/sync/services/v3/bidirectional_sync_initializer.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';

/// Service responsible for platform-specific initialization
/// Handles desktop and mobile platform setup
class PlatformInitializationService {
  /// Runs desktop-specific initialization if on a desktop platform
  static Future<void> initializeDesktop(IContainer container) async {
    print('🔧 DEBUG: PlatformInitializationService.initializeDesktop() called');
    if (!(PlatformUtils.isDesktop)) {
      print('🔧 DEBUG: Not a desktop platform, skipping desktop initialization');
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

    // Configure auto-start behavior
    await _configureStartupSettings(container);

    // Handle startup visibility based on launch arguments
    await _handleStartupVisibility(container);

    // Initialize WebSocket server for inter-process communication
    Logger.info('PlatformInitializationService: Starting WebSocket server on $platformName for sync communication...');
    startWebSocketServer();

    // Initialize new sync registry system
    try {
      Logger.info('PlatformInitializationService: Initializing sync registry...');
      await SyncRegistryInitializer.initialize(container);
      Logger.info('PlatformInitializationService: Sync registry initialized successfully');
    } catch (e, stackTrace) {
      Logger.error('PlatformInitializationService: Failed to initialize sync registry: $e');
      Logger.error('StackTrace: $stackTrace');
    }

    // Initialize bidirectional sync system (v3)
    try {
      print('🔧 DEBUG: About to initialize bidirectional sync system (v3)...');
      Logger.info('PlatformInitializationService: Initializing bidirectional sync system...');
      await BidirectionalSyncInitializer.initialize(container);
      print('🔧 DEBUG: Bidirectional sync initialized successfully!');
      Logger.info('PlatformInitializationService: Bidirectional sync initialized successfully');
      
      // Run quick test
      final testResult = await BidirectionalSyncInitializer.runTest();
      if (testResult['success'] == true) {
        Logger.info('PlatformInitializationService: Bidirectional sync test passed ✅');
      } else {
        Logger.warning('PlatformInitializationService: Bidirectional sync test failed ❌');
      }
    } catch (e, stackTrace) {
      Logger.error('PlatformInitializationService: Failed to initialize bidirectional sync: $e');
      Logger.error('StackTrace: $stackTrace');
    }

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

    Logger.debug('PlatformInitializationService: Window manager initialized');
  }

  /// Initializes system tray functionality
  static Future<void> _initializeSystemTray(IContainer container) async {
    Logger.debug('PlatformInitializationService: Initializing system tray...');

    final systemTrayService = container.resolve<ISystemTrayService>();
    await systemTrayService.init();

    Logger.debug('PlatformInitializationService: System tray initialized');
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
    final args = Platform.executableArguments;

    if (args.contains(AppArgs.systemTray)) {
      await windowManager.hide();
      Logger.debug('PlatformInitializationService: Window hidden (started with system tray flag)');
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
        Logger.info('✅ PlatformInitializationService: Android server mode started successfully for background sync');
      } else {
        Logger.warning('❌ PlatformInitializationService: Failed to start Android server mode');
      }
    } catch (e) {
      Logger.error('PlatformInitializationService: Error initializing Android server mode: $e');
    }
  }
}
