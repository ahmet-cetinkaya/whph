import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v24 -> v25: Add occurredAt column to habit_time_record_table
Future<void> migrateV24ToV25(AppDatabase db, Migrator m, Schema25 schema) async {
  final tableExists = await db.customSelect('''
    SELECT name FROM sqlite_master
    WHERE type='table' AND name='habit_time_record_table'
  ''').getSingleOrNull();

  if (tableExists != null) {
    final columnInfo = await db.customSelect('PRAGMA table_info(habit_time_record_table)').get();
    final occurredAtExists = columnInfo.any((row) => row.data['name'] == 'occurred_at');

    if (!occurredAtExists) {
      await m.addColumn(db.habitTimeRecordTable, db.habitTimeRecordTable.occurredAt);

      await db.customStatement('''
        UPDATE habit_time_record_table
        SET occurred_at = created_date
        WHERE occurred_at IS NULL
      ''');
    }
  }
}
