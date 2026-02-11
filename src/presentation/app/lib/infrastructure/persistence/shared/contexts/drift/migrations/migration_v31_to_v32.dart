import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/migrations/migration_exceptions.dart';

/// Migrates the database from version 31 to 32.
///
/// Changes:
/// - Adds [type] column to [TagTable] for distinguishing between labels, contexts, and projects.
/// - Sets all existing tags to type=0 (label) by default.
Future<void> migrateV31ToV32(AppDatabase db, Migrator m, dynamic schema) async {
  Logger.info('Migrating db from v31 to v32');

  try {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    await m.addColumn(db.tagTable, db.tagTable.type);

    // Update all existing tags to have type=0 (label)
    await db.customStatement('UPDATE tag_table SET type = ? WHERE type IS NULL', [0]);

    Logger.info('Migration from v31 to v32 completed');
  } catch (e, stackTrace) {
    Logger.error(
      'Failed to migrate db from v31 to v32. Rolling back changes.',
      error: e,
      stackTrace: stackTrace,
      component: 'migration_v31_to_v32',
    );

    // Rollback: Remove the column if it was added
    // Note: Drift doesn't support rolling back column additions directly,
    // so we mark the migration as failed and log the error for manual intervention
    throw MigrationException(
      'Migration v31 to v32 failed. Database may be in inconsistent state. '
      'Please review logs and manually verify state.',
      e,
    );
  }
}
