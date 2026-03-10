import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/migrations/migration_exceptions.dart';

/// Migrates the database from version 32 to 33.
///
/// Changes:
/// - Adds [tagOrder] column to [TaskTagTable], [NoteTagTable], [HabitTagTable], and [AppUsageTagTable].
/// - Sets existing values to 0.
Future<void> migrateV32ToV33(AppDatabase db, Migrator m, dynamic schema) async {
  Logger.info('Migrating db from v32 to v33');

  try {
    // Check if taskTagTable has the tag_order column
    final taskTagColumns = await db
        .customSelect(
          'PRAGMA table_info(task_tag_table)',
        )
        .get();
    final taskTagHasTagOrder = taskTagColumns.any((row) => row.data['name'] == 'tag_order');

    if (!taskTagHasTagOrder) {
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      await m.addColumn(db.taskTagTable, db.taskTagTable.tagOrder);
    }

    // Check if noteTagTable has the tag_order column
    final noteTagColumns = await db
        .customSelect(
          'PRAGMA table_info(note_tag_table)',
        )
        .get();
    final noteTagHasTagOrder = noteTagColumns.any((row) => row.data['name'] == 'tag_order');

    if (!noteTagHasTagOrder) {
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      await m.addColumn(db.noteTagTable, db.noteTagTable.tagOrder);
    }

    // Check if habitTagTable has the tag_order column
    final habitTagColumns = await db
        .customSelect(
          'PRAGMA table_info(habit_tag_table)',
        )
        .get();
    final habitTagHasTagOrder = habitTagColumns.any((row) => row.data['name'] == 'tag_order');

    if (!habitTagHasTagOrder) {
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      await m.addColumn(db.habitTagTable, db.habitTagTable.tagOrder);
    }

    // Check if appUsageTagTable has the tag_order column
    final appUsageTagColumns = await db
        .customSelect(
          'PRAGMA table_info(app_usage_tag_table)',
        )
        .get();
    final appUsageTagHasTagOrder = appUsageTagColumns.any((row) => row.data['name'] == 'tag_order');

    if (!appUsageTagHasTagOrder) {
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      await m.addColumn(db.appUsageTagTable, db.appUsageTagTable.tagOrder);
    }

    Logger.info('Migration from v32 to v33 completed');
  } catch (e, stackTrace) {
    Logger.error(
      'Failed to migrate db from v32 to v33. Rolling back changes.',
      error: e,
      stackTrace: stackTrace,
      component: 'migration_v32_to_v33',
    );

    throw MigrationException(
      'Migration v32 to v33 failed. Database may be in inconsistent state. '
      'Please review logs and manually verify state.',
      e,
    );
  }
}
