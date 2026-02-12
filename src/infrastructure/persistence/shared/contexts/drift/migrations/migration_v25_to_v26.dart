import 'package:drift/drift.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v25 -> v26: Restructure habit tables with proper PKs and FKs
Future<void> migrateV25ToV26(AppDatabase db, Migrator m, Schema26 schema) async {
  try {
    final habitTableExists = await db.customSelect('''
      SELECT name FROM sqlite_master WHERE type='table' AND name='habit_table'
    ''').getSingleOrNull();

    if (habitTableExists == null) {
      throw StateError('habit_table does not exist');
    }

    final orderColumnExists = await db.customSelect('''
      SELECT COUNT(*) as count FROM pragma_table_info('habit_table')
      WHERE name = 'order'
    ''').getSingleOrNull();

    final hasOrderColumn = (orderColumnExists?.data['count'] as int? ?? 0) > 0;
    DomainLogger.debug('habit_table has order column: $hasOrderColumn');

    final habitCount = await db.customSelect('SELECT COUNT(*) as count FROM habit_table').getSingleOrNull();
    final totalHabits = (habitCount?.data['count'] as int?) ?? 0;
    DomainLogger.info('Migrating $totalHabits habit records');

    final duplicatesResult = await db.customSelect('''
      SELECT id, COUNT(*) as count FROM habit_table
      GROUP BY id HAVING COUNT(*) > 1
    ''').get();

    if (duplicatesResult.isNotEmpty) {
      DomainLogger.warning('Found ${duplicatesResult.length} duplicate IDs in habit_table');
      for (final dup in duplicatesResult) {
        DomainLogger.debug('Duplicate ID: ${dup.data['id']} (count: ${dup.data['count']})');
      }
    }

    await db.customStatement('''
      CREATE TEMPORARY TABLE habit_table_backup AS
      SELECT * FROM habit_table
      WHERE rowid IN (
        SELECT rowid FROM (
          SELECT
            rowid,
            ROW_NUMBER() OVER(PARTITION BY id ORDER BY COALESCE(modified_date, created_date) DESC) as rn
          FROM habit_table
        )
        WHERE rn = 1
      )
    ''');

    await db.customStatement('DROP TABLE IF EXISTS habit_table;');
    await db.customStatement('''
      CREATE TABLE habit_table (
        id TEXT NOT NULL,
        created_date INTEGER NOT NULL,
        modified_date INTEGER NULL,
        deleted_date INTEGER NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        estimated_time INTEGER NULL,
        archived_date INTEGER NULL,
        has_reminder INTEGER NOT NULL DEFAULT 0 CHECK (has_reminder IN (0, 1)),
        reminder_time TEXT NULL,
        reminder_days TEXT NOT NULL DEFAULT '',
        has_goal INTEGER NOT NULL DEFAULT 0 CHECK (has_goal IN (0, 1)),
        target_frequency INTEGER NOT NULL DEFAULT 1,
        period_days INTEGER NOT NULL DEFAULT 7,
        daily_target INTEGER NULL,
        `order` REAL NOT NULL DEFAULT 0.0,
        PRIMARY KEY (id)
      );
    ''');

    if (hasOrderColumn) {
      await db.customStatement('''
        INSERT INTO habit_table (
          id, created_date, modified_date, deleted_date, name, description,
          estimated_time, archived_date, has_reminder, reminder_time, reminder_days,
          has_goal, target_frequency, period_days, daily_target, `order`
        )
        SELECT
          id, created_date, modified_date, deleted_date, name, description,
          estimated_time, archived_date, has_reminder, reminder_time, reminder_days,
          has_goal, target_frequency, period_days, daily_target, `order`
        FROM habit_table_backup;
      ''');
    } else {
      await db.customStatement('''
        INSERT INTO habit_table (
          id, created_date, modified_date, deleted_date, name, description,
          estimated_time, archived_date, has_reminder, reminder_time, reminder_days,
          has_goal, target_frequency, period_days, daily_target, `order`
        )
        SELECT
          id, created_date, modified_date, deleted_date, name, description,
          estimated_time, archived_date, has_reminder, reminder_time, reminder_days,
          has_goal, target_frequency, period_days, daily_target,
          ROW_NUMBER() OVER (ORDER BY created_date ASC) * 1000.0 as `order`
        FROM habit_table_backup;
      ''');
    }

    final restoredCount = await db.customSelect('SELECT COUNT(*) as count FROM habit_table').getSingleOrNull();
    final restoredHabits = (restoredCount?.data['count'] as int?) ?? 0;

    final backupUniqueCount =
        await db.customSelect('SELECT COUNT(*) as count FROM habit_table_backup').getSingleOrNull();
    final uniqueHabits = (backupUniqueCount?.data['count'] as int?) ?? 0;

    if (restoredHabits != uniqueHabits) {
      throw StateError('Data restoration mismatch: expected $uniqueHabits unique habits, got $restoredHabits');
    }

    if (restoredHabits < totalHabits) {
      final removedDuplicates = totalHabits - restoredHabits;
      DomainLogger.info('Successfully removed $removedDuplicates duplicate habit records during migration');
    }

    await db.customStatement('DROP TABLE habit_table_backup;');

    final tableExists = await db.customSelect('''
      SELECT name FROM sqlite_master
      WHERE type='table' AND name='habit_time_record_table'
    ''').getSingleOrNull();

    if (tableExists != null) {
      final recordCount =
          await db.customSelect('SELECT COUNT(*) as count FROM habit_time_record_table').getSingleOrNull();
      final totalRecords = (recordCount?.data['count'] as int?) ?? 0;

      await db.customStatement(
          'CREATE TEMPORARY TABLE habit_time_record_table_backup AS SELECT * FROM habit_time_record_table;');

      await db.customStatement('DROP TABLE IF EXISTS habit_time_record_table;');
      await db.customStatement('''
        CREATE TABLE habit_time_record_table (
          id TEXT NOT NULL,
          created_date INTEGER NOT NULL,
          modified_date INTEGER NULL,
          deleted_date INTEGER NULL,
          habit_id TEXT NOT NULL REFERENCES habit_table(id) ON DELETE CASCADE,
          duration INTEGER NOT NULL,
          occurred_at INTEGER NULL,
          PRIMARY KEY (id)
        );
      ''');

      await db.customStatement('''
        INSERT INTO habit_time_record_table
        SELECT * FROM habit_time_record_table_backup
        WHERE habit_id IN (SELECT id FROM habit_table);
      ''');

      final restoredRecordCount =
          await db.customSelect('SELECT COUNT(*) as count FROM habit_time_record_table').getSingleOrNull();
      final restoredRecords = (restoredRecordCount?.data['count'] as int?) ?? 0;
      final orphanedRecords = totalRecords - restoredRecords;
      if (orphanedRecords > 0) {
        DomainLogger.info('Removed $orphanedRecords orphaned habit time records');
      }

      await db.customStatement('DROP TABLE habit_time_record_table_backup;');
    } else {
      await db.customStatement('''
        CREATE TABLE habit_time_record_table (
          id TEXT NOT NULL,
          created_date INTEGER NOT NULL,
          modified_date INTEGER NULL,
          deleted_date INTEGER NULL,
          habit_id TEXT NOT NULL REFERENCES habit_table(id) ON DELETE CASCADE,
          duration INTEGER NOT NULL,
          occurred_at INTEGER NULL,
          PRIMARY KEY (id)
        );
      ''');
    }

    await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_habit_time_record_habit_date ON habit_time_record_table (habit_id, created_date);');
  } catch (e) {
    DomainLogger.error('Error in migration v25->v26: $e');
    rethrow;
  }
}
