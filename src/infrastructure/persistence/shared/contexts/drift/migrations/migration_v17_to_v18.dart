import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v17 -> v18: Add archivedDate column
Future<void> migrateV17ToV18(AppDatabase db, Migrator m, Schema18 schema) async {
  await m.addColumn(db.habitTable, db.habitTable.archivedDate);
}
