import 'package:drift/drift.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v22 -> v23: Clean up duplicate task records
Future<void> migrateV22ToV23(AppDatabase db, Migrator m, Schema23 schema) async {
  try {
    final tableExists = await db.customSelect('''
      SELECT name FROM sqlite_master WHERE type='table' AND name='task_table'
    ''').getSingleOrNull();

    if (tableExists == null) {
      throw StateError('task_table does not exist');
    }

    final duplicates = await db.customSelect('''
      SELECT COUNT(*) as count FROM (
        SELECT id FROM task_table GROUP BY id HAVING COUNT(*) > 1
      )
    ''').getSingleOrNull();

    final duplicateCount = (duplicates?.data['count'] as int?) ?? 0;
    if (duplicateCount > 0) {
      DomainLogger.warning('Found $duplicateCount duplicate task IDs, cleaning up...');
    }

    await db.customStatement('''
      DELETE FROM task_table
      WHERE rowid NOT IN (
        SELECT MIN(rowid)
        FROM task_table
        GROUP BY id
      )
    ''');

    await db.customStatement('''
      CREATE TABLE task_table_new (
        id TEXT NOT NULL,
        parent_task_id TEXT NULL,
        title TEXT NOT NULL,
        description TEXT NULL,
        priority INTEGER NULL,
        planned_date INTEGER NULL,
        deadline_date INTEGER NULL,
        estimated_time INTEGER NULL,
        is_completed INTEGER NOT NULL DEFAULT (0) CHECK ("is_completed" IN (0, 1)),
        created_date INTEGER NOT NULL,
        modified_date INTEGER NULL,
        deleted_date INTEGER NULL,
        "order" REAL NOT NULL DEFAULT 0.0,
        planned_date_reminder_time INTEGER NOT NULL DEFAULT 0,
        deadline_date_reminder_time INTEGER NOT NULL DEFAULT 0,
        recurrence_type INTEGER NOT NULL DEFAULT 0,
        recurrence_interval INTEGER NULL,
        recurrence_days_string TEXT NULL,
        recurrence_start_date INTEGER NULL,
        recurrence_end_date INTEGER NULL,
        recurrence_count INTEGER NULL,
        recurrence_parent_id TEXT NULL,
        PRIMARY KEY (id)
      )
    ''');

    await db.customStatement('''
      INSERT INTO task_table_new (id, parent_task_id, title, description, priority, planned_date, deadline_date, estimated_time, is_completed, created_date, modified_date, deleted_date, "order", planned_date_reminder_time, deadline_date_reminder_time, recurrence_type, recurrence_interval, recurrence_days_string, recurrence_start_date, recurrence_end_date, recurrence_count, recurrence_parent_id)
      SELECT id, parent_task_id, title, description, priority, planned_date, deadline_date, estimated_time, is_completed, created_date, modified_date, deleted_date, "order", planned_date_reminder_time, deadline_date_reminder_time, recurrence_type, recurrence_interval, recurrence_days_string, recurrence_start_date, recurrence_end_date, recurrence_count, recurrence_parent_id FROM task_table
    ''');

    final copiedCount = await db.customSelect('SELECT COUNT(*) as count FROM task_table_new').getSingleOrNull();
    final insertCount = (copiedCount?.data['count'] as int?) ?? 0;
    DomainLogger.info('Copied $insertCount task records to new table');

    await db.customStatement('DROP TABLE task_table');
    await db.customStatement('ALTER TABLE task_table_new RENAME TO task_table');
  } catch (e) {
    DomainLogger.error('Error in migration v22->v23: $e');
    rethrow;
  }
}
