import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v21 -> v22: Add order column to habit table
Future<void> migrateV21ToV22(AppDatabase db, Migrator m, Schema22 schema) async {
  await m.addColumn(db.habitTable, db.habitTable.order);

  await db.customStatement('''
    WITH ordered_habits AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY created_date ASC) * 1000.0 AS new_order
      FROM habit_table
      WHERE deleted_date IS NULL
    )
    UPDATE habit_table
    SET [order] = (SELECT new_order FROM ordered_habits WHERE ordered_habits.id = habit_table.id)
    WHERE habit_table.id IN (SELECT id FROM ordered_habits)
  ''');
}
