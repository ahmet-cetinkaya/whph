import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v15 -> v16: Add reminder fields
Future<void> migrateV15ToV16(AppDatabase db, Migrator m, Schema16 schema) async {
  await m.addColumn(db.taskTable, db.taskTable.plannedDateReminderTime);
  await m.addColumn(db.taskTable, db.taskTable.deadlineDateReminderTime);
  await m.addColumn(db.habitTable, db.habitTable.hasReminder);
  await m.addColumn(db.habitTable, db.habitTable.reminderTime);
  await m.addColumn(db.habitTable, db.habitTable.reminderDays);
}
