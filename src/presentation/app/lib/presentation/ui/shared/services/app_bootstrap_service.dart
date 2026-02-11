import 'dart:async';
import 'package:mediatr/mediatr.dart';
import 'package:application/application_container.dart';
import 'package:application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:application/features/demo/services/abstraction/i_demo_data_service.dart';
import 'package:application/features/sync/services/database_integrity_service.dart';
import 'package:application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:domain/shared/constants/demo_config.dart';
import 'package:infrastructure/infrastructure_container.dart';
import 'package:infrastructure_persistence/persistence_container.dart';
import 'package:infrastructure_desktop/features/sync/desktop_sync_service.dart';
import 'package:presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:presentation/ui/shared/utils/error_helper.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:application/shared/services/abstraction/i_logger_service.dart';
import 'package:presentation/ui/ui_presentation_container.dart';
import 'package:acore/acore.dart';
import 'package:main.mapper.g.dart' show initializeJsonMapper;

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
    // Note: Logger.initialize removed - using DomainLogger with acore's ConsoleLogger fallback
    DomainLogger.info('AppBootstrapService: Starting app initialization...');
    DomainLogger.debug('AppBootstrapService: Registering dependency modules...');

    DomainLogger.info('AppBootstrapService: Dependency injection container setup completed');

    return container;
  }

  /// Initializes core services after the container has been made globally available
  ///
  /// This method should be called after the container is assigned to a global variable
  static Future<void> initializeCoreServices(IContainer container) async {
    // Initialize core services
    await _initializeCoreServices(container);

    // Start background workers
    await _startBackgroundWorkers(container);

    DomainLogger.info('AppBootstrapService: App initialization completed successfully');
  }

  /// Initializes essential core services required for app functionality
  static Future<void> _initializeCoreServices(IContainer container) async {
    DomainLogger.debug('AppBootstrapService: Initializing core services...');

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

    // Validate sync state and database integrity before starting sync services
    await _validateSyncStateAndIntegrity(container);

    // Initialize demo data if demo mode is enabled
    if (DemoConfig.isDemoModeEnabled) {
      DomainLogger.info('AppBootstrapService: Demo mode enabled - initializing demo data...');
      try {
        final demoDataService = container.resolve<IDemoDataService>();
        await demoDataService.initializeDemoDataIfNeeded();
        DomainLogger.info('AppBootstrapService: Demo data initialization completed');
      } catch (e) {
        DomainLogger.error('AppBootstrapService: Error initializing demo data: $e');
        // Don't rethrow - demo data failures shouldn't prevent app startup
      }
    } else {
      DomainLogger.debug('AppBootstrapService: Demo mode disabled - skipping demo data initialization');
    }

    DomainLogger.debug('AppBootstrapService: Core services initialized successfully');
  }

  /// Starts background workers and processes for all platforms
  static Future<void> _startBackgroundWorkers(IContainer container) async {
    DomainLogger.debug('AppBootstrapService: Starting background workers...');

    final mediator = container.resolve<Mediator>();

    // Start app usage tracking for activity monitoring
    await mediator.send(StartTrackAppUsagesCommand());

    DomainLogger.debug('AppBootstrapService: Background workers started successfully');
  }

  /// Validates sync state and database integrity before starting sync services
  /// This prevents crashes caused by corrupted sync state from interrupted operations
  static Future<void> _validateSyncStateAndIntegrity(IContainer container) async {
    DomainLogger.debug('AppBootstrapService: Validating sync state and database integrity...');

    try {
      // Run database integrity checks (but be conservative about automatic fixes)
      final databaseIntegrityService = container.resolve<DatabaseIntegrityService>();
      final integrityReport = await databaseIntegrityService.validateIntegrity();

      if (integrityReport.hasIssues) {
        DomainLogger.warning('Database integrity issues detected during startup:');
        DomainLogger.warning(integrityReport.toString());

        // Only attempt automatic fixes for critical issues that could cause crashes
        // Don't automatically fix ancient devices as this might delete recently added devices
        if (integrityReport.duplicateIds.isNotEmpty ||
            integrityReport.orphanedReferences.isNotEmpty ||
            integrityReport.softDeleteInconsistencies > 0) {
          DomainLogger.info('Attempting to fix critical database integrity issues automatically...');
          final repairReport = await databaseIntegrityService.fixCriticalIntegrityIssues();
          if (repairReport.repairFailures.isNotEmpty) {
            DomainLogger.warning(
                'Some automatic repair operations failed: ${repairReport.repairFailures.length} failures');
          }

          // Re-validate after fixes
          final postFixReport = await databaseIntegrityService.validateIntegrity();
          if (postFixReport.hasIssues) {
            DomainLogger.warning('Some database integrity issues remain after automatic fixes:');
            DomainLogger.warning(postFixReport.toString());
          } else {
            DomainLogger.info('All critical database integrity issues have been resolved automatically');
          }
        } else {
          DomainLogger.info(
              'ℹ️ Only non-critical sync state issues detected - skipping automatic fixes to preserve recently added devices');
        }
      } else {
        DomainLogger.debug('Database integrity check passed - no issues detected');
      }

      // Clear any stale sync state that could cause crashes
      await _clearStaleSyncState(container);

      DomainLogger.debug('Sync state and database integrity validation completed');
    } catch (e) {
      DomainLogger.error('Error during sync state validation: $e');
      // Don't rethrow - sync validation failures shouldn't prevent app startup
      // But log the error prominently for debugging
    }
  }

  /// Clears stale sync state that could cause app crashes on startup
  static Future<void> _clearStaleSyncState(IContainer container) async {
    DomainLogger.debug('AppBootstrapService: Clearing stale sync state...');

    try {
      // Check if we're on desktop platform before clearing sync state
      if (PlatformUtils.isDesktop) {
        // Reset sync pagination service state
        try {
          final syncPaginationService = container.resolve<ISyncPaginationService>();
          syncPaginationService.resetProgress();
          syncPaginationService.clearPendingResponseData();
          DomainLogger.debug('Sync pagination service state cleared');
        } catch (e) {
          DomainLogger.debug('Sync pagination service not available or already reset: $e');
        }

        // Ensure desktop sync service is in a clean state
        try {
          final desktopSyncService = container.resolve<DesktopSyncService>();
          // The service should already be clean at startup, but ensure no lingering operations
          if (desktopSyncService.isModeSwitching) {
            DomainLogger.warning(
                'Desktop sync service was in mode-switching state at startup - this indicates a crash or interruption during the previous session. Current mode: ${desktopSyncService.currentMode.name}');
          }
          DomainLogger.debug('Desktop sync service state verified');
        } catch (e) {
          DomainLogger.debug('Desktop sync service not available: $e');
        }
      }

      DomainLogger.debug('Stale sync state cleared successfully');
    } catch (e) {
      DomainLogger.warning('Error clearing stale sync state: $e');
      // Don't rethrow - this is a defensive cleanup operation
    }
  }
}
