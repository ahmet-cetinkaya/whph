import 'dart:async';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/application_container.dart';
import 'package:whph/core/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/core/application/features/demo/services/abstraction/i_demo_data_service.dart';
import 'package:whph/core/application/features/sync/services/database_integrity_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/domain/shared/constants/demo_config.dart';
import 'package:whph/infrastructure/infrastructure_container.dart';
import 'package:whph/infrastructure/persistence/persistence_container.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_sync_service.dart';
import 'package:whph/presentation/ui/features/notifications/services/reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/shared/services/abstraction/i_logger_service.dart';
import 'package:whph/presentation/ui/ui_presentation_container.dart';
import 'package:acore/acore.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;

class AppBootstrapService {
  static Future<IContainer> initializeApp() async {
    final container = Container();
    initializeJsonMapper();

    registerPersistence(container);
    registerInfrastructure(container);
    registerApplication(container);
    registerUIPresentation(container);

    Logger.initialize(container);
    return container;
  }

  static Future<void> initializeCoreServices(IContainer container) async {
    await _initializeCoreServices(container);
    await _startBackgroundWorkers(container);
  }

  static Future<void> _initializeCoreServices(IContainer container) async {
    // Logger must be configured first to enable file logging
    final loggerService = container.resolve<ILoggerService>();
    await loggerService.configureLogger();

    final translationService = container.resolve<ITranslationService>();
    await translationService.init();
    ErrorHelper.initialize(translationService);

    final themeService = container.resolve<IThemeService>();
    await themeService.initialize();

    final notificationService = container.resolve<INotificationService>();
    await notificationService.init();

    final reminderService = container.resolve<ReminderService>();
    await reminderService.initialize();

    await _validateSyncStateAndIntegrity(container);

    if (DemoConfig.isDemoModeEnabled) {
      try {
        final demoDataService = container.resolve<IDemoDataService>();
        await demoDataService.initializeDemoDataIfNeeded();
      } catch (e) {
        Logger.error('AppBootstrapService: Error initializing demo data: $e');
      }
    }
  }

  static Future<void> _startBackgroundWorkers(IContainer container) async {
    final mediator = container.resolve<Mediator>();
    await mediator.send(StartTrackAppUsagesCommand());
  }

  /// Prevents crashes from corrupted sync state caused by interrupted operations
  static Future<void> _validateSyncStateAndIntegrity(IContainer container) async {
    try {
      final databaseIntegrityService = container.resolve<DatabaseIntegrityService>();
      final integrityReport = await databaseIntegrityService.validateIntegrity();

      if (integrityReport.hasIssues) {
        Logger.warning('Database integrity issues detected during startup:');
        Logger.warning(integrityReport.toString());

        // Only auto-fix critical issues; skip non-critical to avoid deleting recently added devices
        if (integrityReport.duplicateIds.isNotEmpty ||
            integrityReport.orphanedReferences.isNotEmpty ||
            integrityReport.softDeleteInconsistencies > 0) {
          final repairReport = await databaseIntegrityService.fixCriticalIntegrityIssues();
          if (repairReport.repairFailures.isNotEmpty) {
            Logger.warning('Some automatic repair operations failed: ${repairReport.repairFailures.length} failures');
          }

          final postFixReport = await databaseIntegrityService.validateIntegrity();
          if (postFixReport.hasIssues) {
            Logger.warning('Some database integrity issues remain after automatic fixes:');
            Logger.warning(postFixReport.toString());
          } else {
            Logger.info('All critical database integrity issues have been resolved automatically');
          }
        } else {
          Logger.info(
              'ℹ️ Only non-critical sync state issues detected - skipping automatic fixes to preserve recently added devices');
        }
      } else {
        Logger.debug('Database integrity check passed - no issues detected');
      }

      await _clearStaleSyncState(container);
    } catch (e) {
      Logger.error('Error during sync state validation: $e');
    }
  }

  static Future<void> _clearStaleSyncState(IContainer container) async {
    try {
      if (PlatformUtils.isDesktop) {
        try {
          final syncPaginationService = container.resolve<ISyncPaginationService>();
          syncPaginationService.resetProgress();
          syncPaginationService.clearPendingResponseData();
        } catch (e) {
          Logger.debug('Sync pagination service not available or already reset: $e');
        }

        try {
          final desktopSyncService = container.resolve<DesktopSyncService>();
          if (desktopSyncService.isModeSwitching) {
            Logger.warning(
                'Desktop sync service was in mode-switching state at startup - this indicates a crash or interruption during the previous session. Current mode: ${desktopSyncService.currentMode.name}');
          }
        } catch (e) {
          Logger.debug('Desktop sync service not available: $e');
        }
      }
    } catch (e) {
      Logger.warning('Error clearing stale sync state: $e');
    }
  }
}
