import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/api/api.dart';
import 'package:whph/application/application_container.dart';
import 'package:whph/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/dependency_injection/container.dart' as acore;
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/infrastructure/infrastructure_container.dart';
import 'package:whph/persistence/persistence_container.dart';
import 'package:whph/presentation/app.dart';
import 'package:whph/presentation/presentation_container.dart';
import 'package:whph/presentation/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:window_manager/window_manager.dart';
import 'main.mapper.g.dart' show initializeJsonMapper;
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/presentation/shared/constants/app_args.dart';

/// Global navigator key for accessing context throughout the application
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global DI container instance
late final IContainer container;

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    /// Configure custom error widget for Flutter rendering errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: Colors.red,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error: ${details.exception}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    };

    // Initialize dependency injection container and register modules
    container = acore.Container();
    initializeJsonMapper();
    registerPersistence(container);
    registerInfrastructure(container);
    registerApplication(container);
    registerPresentation(container);

    // Initialize core services
    final translationService = container.resolve<ITranslationService>();
    await translationService.init();
    ErrorHelper.initialize(translationService);

    final notificationService = container.resolve<INotificationService>();
    await notificationService.init();

    // Start platform-specific background processes
    await runDesktopWorkers();
    await runBackgroundWorkers();

    // Launch the application with translation support
    runApp(
      translationService.wrapWithTranslations(
        App(navigatorKey: navigatorKey),
      ),
    );
  }, (error, stack) {
    // Global error handling for uncaught exceptions
    if (navigatorKey.currentContext != null) {
      if (error is BusinessException) {
        ErrorHelper.showError(navigatorKey.currentContext!, error);
      } else {
        ErrorHelper.showUnexpectedError(
          navigatorKey.currentContext!,
          error,
          stack,
        );
      }
    }
    if (kDebugMode) {
      debugPrint('Caught error: $error');
      debugPrint('Stack trace: $stack');
    }
  });
}

/// Set up desktop-specific features and services
Future<void> runDesktopWorkers() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

  // Configure desktop environment
  final setupService = container.resolve<ISetupService>();
  await setupService.setupEnvironment();

  // Initialize window manager and configure basic window properties
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  if (!kDebugMode) await windowManager.setMinimumSize(const Size(800, 600));

  // Set up system tray integration
  final systemTrayService = container.resolve<ISystemTrayService>();
  await systemTrayService.init();

  // Configure auto-start behavior
  final startupService = container.resolve<IStartupSettingsService>();
  await startupService.ensureStartupSettingSync();

  // Handle startup visibility based on launch arguments
  if (Platform.environment.containsKey('FLUTTER_TEST') == false) {
    final args = Platform.executableArguments;
    if (args.contains(AppArgs.systemTray)) {
      await windowManager.hide();
    } else {
      await windowManager.show();
    }
  }

  // Initialize WebSocket server for inter-process communication
  startWebSocketServer();
}

/// Initialize background processes that run on all platforms
Future<void> runBackgroundWorkers() async {
  final mediator = container.resolve<Mediator>();

  if (Platform.isAndroid || Platform.isIOS) {
    // Start mobile-specific background services
    mediator.send(StartSyncCommand());
  }

  // Start app usage tracking for activity monitoring
  await mediator.send(StartTrackAppUsagesCommand());
}
