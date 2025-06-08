import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/application_container.dart';
import 'package:whph/src/core/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/src/core/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/src/infrastructure/infrastructure_container.dart';
import 'package:whph/src/infrastructure/persistence/persistence_container.dart';
import 'package:whph/src/presentation/ui/features/notifications/services/reminder_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/error_helper.dart';
import 'package:whph/src/presentation/ui/ui_presentation_container.dart';
import 'package:whph/corePackages/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/corePackages/acore/dependency_injection/container.dart' as acore;
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;

/// Service responsible for bootstrapping the application
/// Handles dependency injection setup and core service initialization
class AppBootstrapService {
  /// Initializes the dependency injection container and core services
  ///
  /// Returns the configured [IContainer] instance
  static Future<IContainer> initializeApp() async {
    if (kDebugMode) {
      debugPrint('AppBootstrapService: Starting app initialization...');
    }

    // Initialize dependency injection container and register modules
    final container = acore.Container();
    initializeJsonMapper();

    if (kDebugMode) {
      debugPrint('AppBootstrapService: Registering dependency modules...');
    }

    registerPersistence(container);
    registerInfrastructure(container);
    registerApplication(container);
    registerUIPresentation(container);

    // Initialize core services
    await _initializeCoreServices(container);

    // Start background workers
    await _startBackgroundWorkers(container);

    if (kDebugMode) {
      debugPrint('AppBootstrapService: App initialization completed successfully');
    }

    return container;
  }

  /// Initializes essential core services required for app functionality
  static Future<void> _initializeCoreServices(IContainer container) async {
    if (kDebugMode) {
      debugPrint('AppBootstrapService: Initializing core services...');
    }

    // Initialize translation service
    final translationService = container.resolve<ITranslationService>();
    await translationService.init();
    ErrorHelper.initialize(translationService);

    // Initialize notification service
    final notificationService = container.resolve<INotificationService>();
    await notificationService.init();

    // Initialize reminder service
    final reminderService = container.resolve<ReminderService>();
    await reminderService.initialize();

    if (kDebugMode) {
      debugPrint('AppBootstrapService: Core services initialized successfully');
    }
  }

  /// Starts background workers and processes for all platforms
  static Future<void> _startBackgroundWorkers(IContainer container) async {
    if (kDebugMode) {
      debugPrint('AppBootstrapService: Starting background workers...');
    }

    final mediator = container.resolve<Mediator>();

    if (Platform.isAndroid || Platform.isIOS) {
      // Start mobile-specific background services
      mediator.send(StartSyncCommand());
    }

    // Start app usage tracking for activity monitoring
    await mediator.send(StartTrackAppUsagesCommand());

    if (kDebugMode) {
      debugPrint('AppBootstrapService: Background workers started successfully');
    }
  }
}
