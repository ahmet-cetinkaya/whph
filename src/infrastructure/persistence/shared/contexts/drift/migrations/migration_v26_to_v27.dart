import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v26 -> v27: Add isEstimated column
Future<void> migrateV26ToV27(AppDatabase db, Migrator m, Schema27 schema) async {
  await m.addColumn(db.habitTimeRecordTable, db.habitTimeRecordTable.isEstimated);
}
