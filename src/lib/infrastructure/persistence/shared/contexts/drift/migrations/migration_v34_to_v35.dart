import 'package:drift/drift.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migrates the database from version 34 to 35.
///
/// Adds missing [order] column to [TaskStatusTable] for databases that
/// completed the v33→v34 migration before the column was added to the schema.
Future<void> migrateV34ToV35(AppDatabase db, Migrator m, Schema35 schema) async {
  Logger.info('Migrating db from v34 to v35');

  try {
    final columns = await db.customSelect('PRAGMA table_info(task_status_table)').get();
    final hasOrder = columns.any((row) => row.data['name'] == 'order');
    if (!hasOrder) {
      await db.customStatement('ALTER TABLE task_status_table ADD COLUMN "order" REAL NOT NULL DEFAULT 0.0');
      Logger.info('Added missing order column to task_status_table');
    }

    Logger.info('Migration from v34 to v35 completed');
  } catch (e, stackTrace) {
    Logger.error(
      'Failed to migrate db from v34 to v35.',
      error: e,
      stackTrace: stackTrace,
      component: 'migration_v34_to_v35',
    );
    rethrow;
  }
}
