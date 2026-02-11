import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v18 -> v19: Add recurrence fields
Future<void> migrateV18ToV19(AppDatabase db, Migrator m, Schema19 schema) async {
  await m.addColumn(db.taskTable, db.taskTable.recurrenceType);
  await m.addColumn(db.taskTable, db.taskTable.recurrenceInterval);
  await m.addColumn(db.taskTable, db.taskTable.recurrenceDaysString);
  await m.addColumn(db.taskTable, db.taskTable.recurrenceStartDate);
  await m.addColumn(db.taskTable, db.taskTable.recurrenceEndDate);
  await m.addColumn(db.taskTable, db.taskTable.recurrenceCount);
  await m.addColumn(db.taskTable, db.taskTable.recurrenceParentId);
}
