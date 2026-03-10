import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v11 -> v12: Add parentTaskId column
Future<void> migrateV11ToV12(AppDatabase db, Migrator m, Schema12 schema) async {
  await m.addColumn(db.taskTable, db.taskTable.parentTaskId);
}
