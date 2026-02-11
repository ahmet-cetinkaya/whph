import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v19 -> v20: Add goal-related fields
Future<void> migrateV19ToV20(AppDatabase db, Migrator m, Schema20 schema) async {
  await m.addColumn(db.habitTable, db.habitTable.hasGoal);
  await m.addColumn(db.habitTable, db.habitTable.targetFrequency);
  await m.addColumn(db.habitTable, db.habitTable.periodDays);
}
