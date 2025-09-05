import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/infrastructure/shared/services/desktop_startup_service.dart';
import 'package:whph/presentation/ui/app.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/app_bootstrap_service.dart';
import 'package:whph/presentation/ui/shared/services/global_error_handler_service.dart';
import 'package:whph/presentation/ui/shared/services/notification_payload_service.dart';
import 'package:whph/presentation/ui/shared/services/platform_initialization_service.dart';
import 'package:whph/core/application/features/widget/services/widget_service.dart';
import 'package:whph/core/application/features/widget/services/widget_update_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:acore/acore.dart';

/// Global navigator key for accessing context throughout the application
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global DI container instance
late final IContainer container;

void main(List<String> args) async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize desktop startup service to handle command line arguments
    if (PlatformUtils.isDesktop) {
      DesktopStartupService.initializeWithArgs(args);
      debugPrint('Desktop startup mode: ${DesktopStartupService.getStartupModeDescription()}');
      debugPrint('Received args: ${args.join(', ')}');
    }

    // Set up global error handling
    GlobalErrorHandlerService.setupErrorHandling(navigatorKey);

    // Initialize the application container first
    container = await AppBootstrapService.initializeApp();

    // Check for single instance (desktop only)
    if (PlatformUtils.isDesktop) {
      try {
        final singleInstanceService = container.resolve<ISingleInstanceService>();

        if (await singleInstanceService.isAnotherInstanceRunning()) {
          // Try to focus the existing instance
          await singleInstanceService.sendFocusToExistingInstance();

          // Exit gracefully without showing any windows
          exit(0);
        }

        // Lock this instance
        if (!await singleInstanceService.lockInstance()) {
          // Failed to acquire lock, another instance might have started
          exit(1);
        }
      } catch (e) {
        // Single instance service not available, continue normally
        debugPrint('Single instance service not available: $e');
      }
    }

    // Initialize core services after container is globally available
    await AppBootstrapService.initializeCoreServices(container);

    // Initialize platform-specific features
    await PlatformInitializationService.initializeDesktop(container);
    await PlatformInitializationService.initializeMobile(container);

    // Set up notification handling
    final payloadHandler = container.resolve<INotificationPayloadHandler>();
    NotificationPayloadService.setupNotificationListener(payloadHandler);

    // Get translation service for app wrapper
    final translationService = container.resolve<ITranslationService>();

    // Launch the application
    runApp(
      translationService.wrapWithTranslations(
        App(
          navigatorKey: navigatorKey,
          container: container,
        ),
      ),
    );

    // Handle initial notification payload after app launch
    NotificationPayloadService.handleInitialNotificationPayload(payloadHandler);

    // Initialize widget service
    if (Platform.isAndroid || Platform.isIOS) {
      final widgetService = container.resolve<WidgetService>();
      final widgetUpdateService = container.resolve<WidgetUpdateService>();

      await widgetService.initialize();
      await widgetService.updateWidget();

      widgetUpdateService.setupAppLifecycleListener();
      widgetUpdateService.startPeriodicUpdates();
    }

    // Set up cleanup on exit for desktop platforms
    if (PlatformUtils.isDesktop) {
      for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
        signal.watch().listen((_) async {
          await _cleanupOnExit();
          exit(0);
        });
      }
    }
  }, (error, stack) {
    // Global error handling for uncaught exceptions
    GlobalErrorHandlerService.handleZoneError(error, stack, navigatorKey);

    // Log the error to the console
    debugPrint('Uncaught error on app startup: \n$error\n$stack');
  });
}

/// Cleanup resources before app exit
Future<void> _cleanupOnExit() async {
  try {
    if (PlatformUtils.isDesktop) {
      final singleInstanceService = container.resolve<ISingleInstanceService>();
      await singleInstanceService.releaseInstance();
    }
  } catch (e) {
    debugPrint('Error during cleanup: $e');
  }
}
