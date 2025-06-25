import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whph/src/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/src/presentation/ui/app.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/services/app_bootstrap_service.dart';
import 'package:whph/src/presentation/ui/shared/services/global_error_handler_service.dart';
import 'package:whph/src/presentation/ui/shared/services/notification_payload_service.dart';
import 'package:whph/src/presentation/ui/shared/services/platform_initialization_service.dart';
import 'package:acore/acore.dart';

/// Global navigator key for accessing context throughout the application
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global DI container instance
late final IContainer container;

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Set up global error handling
    GlobalErrorHandlerService.setupErrorHandling(navigatorKey);

    // Initialize the application
    container = await AppBootstrapService.initializeApp();

    // Initialize platform-specific features
    await PlatformInitializationService.initializeDesktop(container);

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
  }, (error, stack) {
    // Global error handling for uncaught exceptions
    GlobalErrorHandlerService.handleZoneError(error, stack, navigatorKey);
  });
}
