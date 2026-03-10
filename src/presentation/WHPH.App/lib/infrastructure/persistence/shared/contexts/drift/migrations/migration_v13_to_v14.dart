import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v13 -> v14: Add order column to Task table
Future<void> migrateV13ToV14(AppDatabase db, Migrator m, Schema14 schema) async {
  await m.addColumn(db.taskTable, db.taskTable.order);
}
