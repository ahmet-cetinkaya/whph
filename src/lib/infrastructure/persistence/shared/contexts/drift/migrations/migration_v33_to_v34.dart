import 'package:drift/drift.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/migrations/migration_exceptions.dart';

/// Migrates the database from version 33 to 34.
///
/// Changes:
/// - Creates [TaskStatusTable].
/// - Adds [statusId] column to [TaskTable].
/// - Seeds the built-in `todo` and `done` statuses (shared ids across devices).
/// - Backfills [TaskTable.statusId] from [TaskTable.completedAt].
Future<void> migrateV33ToV34(AppDatabase db, Migrator m, Schema34 schema) async {
  Logger.info('Migrating db from v33 to v34');

  try {
    final taskStatusTableExists = await db.customSelect('''
      SELECT name FROM sqlite_master WHERE type='table' AND name='task_status_table'
    ''').getSingleOrNull();
    if (taskStatusTableExists == null) {
      await m.createTable(schema.taskStatusTable);
    } else {
      // Table exists but may be missing columns from partial migration
      final statusColumns = await db.customSelect('PRAGMA table_info(task_status_table)').get();
      final columnNames = statusColumns.map((row) => row.data['name'] as String).toList();

      if (!columnNames.contains('order')) {
        await db.customStatement('ALTER TABLE task_status_table ADD COLUMN "order" REAL NOT NULL DEFAULT 0.0');
      }
    }

    final taskColumns = await db.customSelect('PRAGMA table_info(task_table)').get();
    final taskHasStatusId = taskColumns.any((row) => row.data['name'] == 'status_id');
    if (!taskHasStatusId) {
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      await m.addColumn(db.taskTable, db.taskTable.statusId);
    }

    await _seedBuiltInStatus(
      db,
      id: TaskStatusConstants.todoId,
      color: TaskStatusConstants.todoColor,
      sortOrder: TaskStatusConstants.todoOrder,
      isDoneStatus: 0,
    );
    await _seedBuiltInStatus(
      db,
      id: TaskStatusConstants.doneId,
      color: TaskStatusConstants.doneColor,
      sortOrder: TaskStatusConstants.doneOrder,
      isDoneStatus: 1,
    );

    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_task_status_id ON task_table (status_id) WHERE deleted_date IS NULL',
    );

    await db.customStatement(
      'UPDATE task_table SET status_id = ? WHERE status_id IS NULL AND completed_at IS NOT NULL',
      [TaskStatusConstants.doneId],
    );
    await db.customStatement(
      'UPDATE task_table SET status_id = ? WHERE status_id IS NULL AND completed_at IS NULL',
      [TaskStatusConstants.todoId],
    );

    Logger.info('Migration from v33 to v34 completed');
  } catch (e, stackTrace) {
    Logger.error(
      'Failed to migrate db from v33 to v34.',
      error: e,
      stackTrace: stackTrace,
      component: 'migration_v33_to_v34',
    );

    throw MigrationException(
      'Migration v33 to v34 failed: ${e.toString()}. '
      'The transaction was rolled back automatically. '
      'If the issue persists, check logs for details and ensure you have sufficient storage space.',
      e,
    );
  }
}

/// Inserts a built-in status row if it is not already present.
/// Built-in names are seeded empty and resolved to a localized label at display time.
Future<void> _seedBuiltInStatus(
  AppDatabase db, {
  required String id,
  required String color,
  required double sortOrder,
  required int isDoneStatus,
}) async {
  final exists = await db.customSelect(
    'SELECT id FROM task_status_table WHERE id = ?',
    variables: [Variable.withString(id)],
  ).getSingleOrNull();
  if (exists != null) return;

  await db.customStatement(
    '''
    INSERT INTO task_status_table
      (id, created_date, name, color, "order", is_built_in, is_done_status)
    VALUES (?, CAST(strftime('%s','now') AS INTEGER), '', ?, ?, 1, ?)
    ''',
    [id, color, sortOrder, isDoneStatus],
  );
}
