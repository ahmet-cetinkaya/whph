import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/api/api.dart';
import 'package:whph/application/application_container.dart';
import 'package:whph/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/presentation/features/notifications/services/reminder_service.dart';
import 'package:whph/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/dependency_injection/container.dart' as acore;
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/infrastructure/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/infrastructure/infrastructure_container.dart';
import 'package:whph/persistence/persistence_container.dart';
import 'package:whph/presentation/app.dart';
import 'package:whph/presentation/presentation_container.dart';
import 'package:whph/presentation/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/infrastructure/features/window/abstractions/i_window_manager.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'main.mapper.g.dart' show initializeJsonMapper;
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/presentation/shared/constants/app_args.dart';
import 'package:flutter/services.dart';

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
            padding: const EdgeInsets.all(AppTheme.sizeLarge),
            child: Text(
              ' ${details.exception}',
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

    // Initialize reminder service
    final reminderService = container.resolve<ReminderService>();
    await reminderService.initialize();

    // Start platform-specific background processes
    await runDesktopWorkers();
    await runBackgroundWorkers();

    // Create notification payload handler
    final payloadHandler = container.resolve<INotificationPayloadHandler>();

    // Set up notification click listener for Android
    if (Platform.isAndroid) {
      final platform = MethodChannel(AndroidAppConstants.channels.notification);
      platform.setMethodCallHandler((call) async {
        if (call.method == 'onNotificationClicked') {
          final payload = call.arguments as String?;
          if (payload != null) {
            try {
              // Delay to ensure the app is fully initialized before handling the payload
              await Future.delayed(const Duration(milliseconds: 500));
              await payloadHandler.handlePayload(payload);
              // Acknowledge receipt of payload to native side
              await platform.invokeMethod('acknowledgePayload', payload);
            } catch (e) {
              if (kDebugMode) debugPrint('Error handling notification payload: $e');
            }
          }
        }
        return null;
      });
    }

    // Launch the application with translation support
    runApp(
      translationService.wrapWithTranslations(
        App(navigatorKey: navigatorKey),
      ),
    );

    // Check for and handle initial notification payload after app is launched
    _handleInitialNotificationPayload(payloadHandler);
  }, (error, stack) {
    // Global error handling for uncaught exceptions
    if (navigatorKey.currentContext != null) {
      try {
        // Check if overlay is available before trying to show error notifications
        final context = navigatorKey.currentContext!;
        final overlay = Overlay.maybeOf(context);

        if (overlay != null) {
          // Overlay is available, show the error normally
          if (error is BusinessException) {
            ErrorHelper.showError(context, error);
          } else {
            ErrorHelper.showUnexpectedError(
              context,
              error,
              stack,
            );
          }
        } else {
          // Overlay not available, log the error or show fallback
          if (kDebugMode) {
            debugPrint('Error occurred but overlay not available: $error');
            debugPrint('Stack trace: $stack');
          }
        }
      } catch (e) {
        // If error handling itself fails, just log it
        if (kDebugMode) {
          debugPrint('Error in error handler: $e');
          debugPrint('Original error: $error');
          debugPrint('Original stack: $stack');
        }
      }
    } else {
      // No context available, just log the error
      if (kDebugMode) {
        debugPrint('Error occurred with no context available: $error');
        debugPrint('Stack trace: $stack');
      }
    }
    // Error logging removed
  });
}

/// Set up desktop-specific features and services
Future<void> runDesktopWorkers() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

  // Configure desktop environment
  final setupService = container.resolve<ISetupService>();
  await setupService.setupEnvironment();

  // Initialize window manager and configure basic window properties
  final windowManager = container.resolve<IWindowManager>();
  await windowManager.initialize();
  await windowManager.setPreventClose(true);
  await windowManager.setTitle(AppInfo.name);
  if (!kDebugMode) await windowManager.setSize(const Size(800, 600));

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

/// Handles the initial notification payload when the app is launched from a notification
Future<void> _handleInitialNotificationPayload(INotificationPayloadHandler payloadHandler) async {
  // Track if we've already handled a notification payload
  bool hasHandledPayload = false;

  // Try multiple times to get the initial notification payload
  // This helps with race conditions when the app is cold-started from a notification
  const int maxRetries = 3;
  for (int i = 0; i < maxRetries; i++) {
    try {
      // Skip if we've already handled a payload
      if (hasHandledPayload) break;

      final notificationPayload = await _getInitialNotificationPayload();

      if (notificationPayload != null && notificationPayload.isNotEmpty) {
        // Wait for app to be fully initialized before handling the payload
        await Future.delayed(const Duration(milliseconds: 1500));

        // Check again if a payload has been handled during this delay
        // (could happen via the method channel handler)
        if (hasHandledPayload) break;

        await payloadHandler.handlePayload(notificationPayload);

        // Acknowledge receipt of payload to native side
        final platform = MethodChannel(AndroidAppConstants.channels.notification);
        await platform.invokeMethod('acknowledgePayload', notificationPayload);

        hasHandledPayload = true;
        break; // Exit the retry loop if successful
      }

      // If no payload found, wait before trying again
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (kDebugMode) debugPrint('Error handling initial notification payload: $e');
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}

/// Get the initial notification payload if the app was launched from a notification
Future<String?> _getInitialNotificationPayload() async {
  try {
    if (Platform.isAndroid) {
      // Get the initial notification payload from the platform channel
      final platform = MethodChannel(AndroidAppConstants.channels.notification);
      final payload = await platform.invokeMethod<String>('getInitialNotificationPayload');
      return payload;
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Error getting initial notification payload: $e');
  }
  return null;
}
