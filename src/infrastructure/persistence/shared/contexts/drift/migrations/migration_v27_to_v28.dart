import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v27 -> v28: Migrate isCompleted to completedAt
Future<void> migrateV27ToV28(AppDatabase db, Migrator m, Schema28 schema) async {
  await db.transaction(() async {
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
        completed_at INTEGER NULL,
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
      INSERT INTO task_table_new (
        id, parent_task_id, title, description, priority,
        planned_date, deadline_date, estimated_time, completed_at,
        created_date, modified_date, deleted_date, "order",
        planned_date_reminder_time, deadline_date_reminder_time,
        recurrence_type, recurrence_interval, recurrence_days_string,
        recurrence_start_date, recurrence_end_date, recurrence_count, recurrence_parent_id
      )
      SELECT
        id, parent_task_id, title, description, priority,
        planned_date, deadline_date, estimated_time,
        CASE WHEN is_completed = 1 THEN COALESCE(modified_date, created_date) ELSE NULL END as completed_at,
        created_date, modified_date, deleted_date, "order",
        planned_date_reminder_time, deadline_date_reminder_time,
        recurrence_type, recurrence_interval, recurrence_days_string,
        recurrence_start_date, recurrence_end_date, recurrence_count, recurrence_parent_id
      FROM task_table
    ''');

    await db.customStatement('DROP TABLE task_table');
    await db.customStatement('ALTER TABLE task_table_new RENAME TO task_table');
  });
}
