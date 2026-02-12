import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v1 -> v2: Add color column to tag table
Future<void> migrateV1ToV2(AppDatabase db, Migrator m, Schema2 schema) async {
  await m.addColumn(db.tagTable, db.tagTable.color);
}
