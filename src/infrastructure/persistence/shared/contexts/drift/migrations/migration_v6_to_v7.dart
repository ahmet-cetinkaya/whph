import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v6 -> v7: Add estimatedTime column to Habit table
Future<void> migrateV6ToV7(AppDatabase db, Migrator m, Schema7 schema) async {
  await m.addColumn(db.habitTable, db.habitTable.estimatedTime);
}
