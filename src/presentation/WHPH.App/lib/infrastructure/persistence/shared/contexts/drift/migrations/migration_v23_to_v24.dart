import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v23 -> v24: Restructure habit_record_table, add dailyTarget
Future<void> migrateV23ToV24(AppDatabase db, Migrator m, Schema24 schema) async {
  await db.customStatement('''
    CREATE TABLE habit_record_table_new (
      id TEXT NOT NULL,
      created_date INTEGER NOT NULL,
      modified_date INTEGER NULL,
      deleted_date INTEGER NULL,
      habit_id TEXT NOT NULL,
      occurred_at INTEGER NOT NULL,
      PRIMARY KEY (id)
    )
  ''');

  await db.customStatement('''
    INSERT INTO habit_record_table_new (id, created_date, modified_date, deleted_date, habit_id, occurred_at)
    SELECT id, created_date, modified_date, deleted_date, habit_id, COALESCE(date, created_date)
    FROM habit_record_table
  ''');

  await db.customStatement('DROP TABLE habit_record_table');
  await db.customStatement('ALTER TABLE habit_record_table_new RENAME TO habit_record_table');

  await m.addColumn(db.habitTable, db.habitTable.dailyTarget);

  await db
      .customStatement('CREATE INDEX idx_habit_record_habit_occurred_at ON habit_record_table (habit_id, occurred_at)');

  await db.customStatement('''
    CREATE TABLE habit_time_record_table (
      id TEXT NOT NULL,
      created_date INTEGER NOT NULL,
      modified_date INTEGER NULL,
      deleted_date INTEGER NULL,
      habit_id TEXT NOT NULL,
      duration INTEGER NOT NULL,
      PRIMARY KEY (id)
    )
  ''');

  await db.customStatement(
      'CREATE INDEX idx_habit_time_record_habit_date ON habit_time_record_table (habit_id, created_date)');
}
