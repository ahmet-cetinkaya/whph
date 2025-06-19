import 'dart:io';
import 'package:whph/src/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/src/infrastructure/features/window/abstractions/i_window_manager.dart';
import 'package:whph/src/presentation/api/api.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_args.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:whph/corePackages/acore/dependency_injection/abstraction/i_container.dart';

/// Service responsible for platform-specific initialization
/// Handles desktop and mobile platform setup
class PlatformInitializationService {
  /// Runs desktop-specific initialization if on a desktop platform
  static Future<void> initializeDesktop(IContainer container) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      Logger.debug('PlatformInitializationService: Not a desktop platform, skipping desktop initialization');
      return;
    }

    Logger.debug('PlatformInitializationService: Starting desktop initialization...');

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
    startWebSocketServer();

    Logger.debug('PlatformInitializationService: Desktop initialization completed');
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
}
