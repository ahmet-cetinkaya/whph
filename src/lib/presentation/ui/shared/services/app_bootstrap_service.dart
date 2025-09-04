import 'dart:async';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/application_container.dart';
import 'package:whph/core/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/core/application/features/demo/services/abstraction/i_demo_data_service.dart';
import 'package:whph/core/domain/shared/constants/demo_config.dart';
import 'package:whph/infrastructure/infrastructure_container.dart';
import 'package:whph/infrastructure/persistence/persistence_container.dart';
import 'package:whph/presentation/ui/features/notifications/services/reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/core/application/shared/services/abstraction/i_logger_service.dart';
import 'package:whph/presentation/ui/ui_presentation_container.dart';
import 'package:acore/acore.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;

/// Service responsible for bootstrapping the application
/// Handles dependency injection setup and core service initialization
class AppBootstrapService {
  /// Initializes the dependency injection container and core services
  ///
  /// Returns the configured [IContainer] instance
  static Future<IContainer> initializeApp() async {
    // Initialize dependency injection container and register modules
    final container = Container();
    initializeJsonMapper();

    registerPersistence(container);
    registerInfrastructure(container);
    registerApplication(container);
    registerUIPresentation(container);

    // Initialize Logger after ALL services are registered
    Logger.initialize(container);
    Logger.info('AppBootstrapService: Starting app initialization...');
    Logger.debug('AppBootstrapService: Registering dependency modules...');

    Logger.info('AppBootstrapService: Dependency injection container setup completed');

    return container;
  }

  /// Initializes core services after the container has been made globally available
  ///
  /// This method should be called after the container is assigned to the global variable
  static Future<void> initializeCoreServices(IContainer container) async {
    // Initialize core services
    await _initializeCoreServices(container);

    // Start background workers
    await _startBackgroundWorkers(container);

    Logger.info('AppBootstrapService: App initialization completed successfully');
  }

  /// Initializes essential core services required for app functionality
  static Future<void> _initializeCoreServices(IContainer container) async {
    Logger.debug('AppBootstrapService: Initializing core services...');

    // Configure logger service first (to enable file logging if setting is enabled)
    final loggerService = container.resolve<ILoggerService>();
    await loggerService.configureLogger();

    // Initialize translation service
    final translationService = container.resolve<ITranslationService>();
    await translationService.init();
    ErrorHelper.initialize(translationService);

    // Initialize theme service
    final themeService = container.resolve<IThemeService>();
    await themeService.initialize();

    // Initialize notification service
    final notificationService = container.resolve<INotificationService>();
    await notificationService.init();

    // Initialize reminder service
    final reminderService = container.resolve<ReminderService>();
    await reminderService.initialize();

    // Initialize demo data if demo mode is enabled
    if (DemoConfig.isDemoModeEnabled) {
      Logger.info('AppBootstrapService: Demo mode enabled - initializing demo data...');
      try {
        final demoDataService = container.resolve<IDemoDataService>();
        await demoDataService.initializeDemoDataIfNeeded();
        Logger.info('AppBootstrapService: Demo data initialization completed');
      } catch (e) {
        Logger.error('AppBootstrapService: Error initializing demo data: $e');
        // Don't rethrow - demo data failures shouldn't prevent app startup
      }
    } else {
      Logger.debug('AppBootstrapService: Demo mode disabled - skipping demo data initialization');
    }

    Logger.debug('AppBootstrapService: Core services initialized successfully');
  }

  /// Starts background workers and processes for all platforms
  static Future<void> _startBackgroundWorkers(IContainer container) async {
    Logger.debug('AppBootstrapService: Starting background workers...');

    final mediator = container.resolve<Mediator>();

    // Start app usage tracking for activity monitoring
    await mediator.send(StartTrackAppUsagesCommand());

    Logger.debug('AppBootstrapService: Background workers started successfully');
  }
}
