import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/migrations/migration_exceptions.dart';

/// Migrates the database from version 30 to 31.
///
/// Changes:
/// - Adds [recurrenceConfiguration] column to [TaskTable].
Future<void> migrateV30ToV31(AppDatabase db, Migrator m, dynamic schema) async {
  DomainLogger.info('Migrating db from v30 to v31');

  try {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    await m.addColumn(db.taskTable, db.taskTable.recurrenceConfiguration);

    DomainLogger.info('Migration from v30 to v31 completed');
  } catch (e, stackTrace) {
    DomainLogger.error(
      'Failed to migrate db from v30 to v31. Rolling back changes.',
      error: e,
      stackTrace: stackTrace,
      component: 'migration_v30_to_v31',
    );

    // Rollback: Remove the column if it was added
    // Note: Drift doesn't support rolling back column additions directly,
    // so we mark the migration as failed and log the error for manual intervention
    throw MigrationException(
      'Migration v30 to v31 failed. Database may be in inconsistent state. '
      'Please review logs and manually verify state.',
      e,
    );
  }
}
