import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v28 -> v29: Add custom reminder offset columns
Future<void> migrateV28ToV29(AppDatabase db, Migrator m, Schema29 schema) async {
  await m.addColumn(db.taskTable, db.taskTable.plannedDateReminderCustomOffset);
  await m.addColumn(db.taskTable, db.taskTable.deadlineDateReminderCustomOffset);
}
