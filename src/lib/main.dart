import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/infrastructure/shared/services/desktop_startup_service.dart';
import 'package:whph/presentation/ui/app.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/app_bootstrap_service.dart';
import 'package:whph/presentation/ui/shared/services/global_error_handler_service.dart';
import 'package:whph/presentation/ui/shared/services/notification_payload_service.dart';
import 'package:whph/presentation/ui/shared/services/platform_initialization_service.dart';
import 'package:whph/presentation/ui/shared/state/app_startup_error_state.dart';
import 'package:whph/core/application/features/widget/services/widget_service/widget_service.dart';
import 'package:whph/core/application/features/widget/services/widget_update_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/infrastructure/android/features/share/android_share_service.dart';
import 'package:whph/infrastructure/android/features/share/share_to_create_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

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

    // Create startup error state tracker
    final startupErrorState = AppStartupErrorState();

    // Initialize the application container with migration error handling
    IContainer? tempContainer;
    try {
      container = await AppBootstrapService.initializeApp();
      tempContainer = container;

      // Configure responsive dialog helper with WHPH theme settings
      ResponsiveDialogHelper.configure(
        ResponsiveDialogConfig(
          screenMediumBreakpoint: AppTheme.screenMedium,
          containerBorderRadius: AppTheme.containerBorderRadius,
          isDesktopScreen: (context) => AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium),
        ),
      );
    } catch (e) {
      debugPrint('Critical error during container initialization: $e');
      debugPrint('Cannot proceed with app initialization. Exiting...');
      rethrow; // Cannot recover from container initialization failure
    }

    // Check for single instance (desktop only)
    if (PlatformUtils.isDesktop) {
      try {
        final singleInstanceService = container.resolve<ISingleInstanceService>();

        if (await singleInstanceService.isAnotherInstanceRunning()) {
          // Check if we just want to trigger a sync
          if (DesktopStartupService.shouldStartSync) {
            debugPrint('Triggering remote sync...');
            bool success = false;
            String? errorMessage;

            await singleInstanceService.sendCommandAndStreamOutput(
              'SYNC',
              onOutput: (message) {
                try {
                  stdout.writeln(message);
                  if (message.contains('Sync operation completed')) {
                    success = true;
                  }
                } catch (e) {
                  errorMessage = 'Failed to write output: $e';
                }
              },
            );

            if (errorMessage != null) {
              stderr.writeln('Error: $errorMessage');
              exit(1);
            }

            if (!success) {
              stderr.writeln('Error: Sync did not complete successfully');
              exit(1);
            }

            exit(0);
          }

          // Try to focus the existing instance
          await singleInstanceService.sendCommandToExistingInstance('FOCUS');

          // Exit gracefully without showing any windows
          exit(0);
        }

        // If no other instance is running, we proceed to lock and start normally.
        // Starting normally effectively performs a sync, so no special handling needed if --sync passed.

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
    try {
      await AppBootstrapService.initializeCoreServices(tempContainer);

      // Initialize platform-specific features
      await PlatformInitializationService.initializeDesktop(tempContainer);
      await PlatformInitializationService.initializeMobile(tempContainer);
    } catch (e, stackTrace) {
      debugPrint('Startup error during service initialization: $e');
      startupErrorState.setStartupError(e, stackTrace);

      // Launch app with error screen showing the startup error
      final translationService = tempContainer.resolve<ITranslationService>();
      runApp(
        translationService.wrapWithTranslations(
          App(
            navigatorKey: navigatorKey,
            container: tempContainer,
            startupErrorState: startupErrorState,
          ),
        ),
      );
      return;
    }

    // Set up notification handling
    final payloadHandler = tempContainer.resolve<INotificationPayloadHandler>();
    final notificationService = tempContainer.resolve<INotificationService>();
    NotificationPayloadService.setupNotificationListener(
      payloadHandler,
      onTaskCompletion: notificationService.handleNotificationTaskCompletion,
    );

    // Process any pending task completions from notifications that arrived while app was closed
    await NotificationPayloadService.processPendingTaskCompletions(
      notificationService.handleNotificationTaskCompletion,
    );

    // Get translation service for app wrapper
    final translationService = tempContainer.resolve<ITranslationService>();

    // Set up share intent handling for Android (must be AFTER initializeCoreServices)
    AndroidShareService.setupShareListener(
      onSharedText: (text, subject) async {
        try {
          Logger.debug('ShareService: Received shared text: text="$text", subject="$subject"');

          final context = await _waitForContext();
          if (context == null || !context.mounted) {
            Logger.warning('ShareService: No valid context available');
            return;
          }

          final translationService = container.resolve<ITranslationService>();
          final shareService = ShareToCreateService(container);

          await shareService.handleShareFlow(
            sharedText: text,
            sharedSubject: subject,
            context: context,
            translationService: translationService,
          );
        } catch (e, stackTrace) {
          Logger.error('ShareService: Error in share handler: $e', stackTrace: stackTrace);
        }
      },
    );

    // Launch the application
    runApp(
      translationService.wrapWithTranslations(
        App(
          navigatorKey: navigatorKey,
          container: tempContainer,
          startupErrorState: startupErrorState,
        ),
      ),
    );

    // Handle initial notification payload after app launch
    NotificationPayloadService.handleInitialNotificationPayload(payloadHandler);

    // Initialize widget service
    if (Platform.isAndroid || Platform.isIOS) {
      final widgetService = tempContainer.resolve<WidgetService>();
      final widgetUpdateService = tempContainer.resolve<WidgetUpdateService>();

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

/// Waits for the app context to be available with a polling mechanism
/// Returns null if context is not available within the timeout period
Future<BuildContext?> _waitForContext({Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  const checkInterval = Duration(milliseconds: 100);

  while (DateTime.now().isBefore(deadline)) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      return context;
    }
    await Future.delayed(checkInterval);
  }

  return null;
}
