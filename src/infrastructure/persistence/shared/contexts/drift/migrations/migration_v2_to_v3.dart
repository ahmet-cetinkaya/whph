import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v2 -> v3: Create TaskTimeRecord table, drop elapsed_time
Future<void> migrateV2ToV3(AppDatabase db, Migrator m, Schema3 schema) async {
  await m.createTable(db.taskTimeRecordTable);
  await m.dropColumn(db.taskTable, "elapsed_time");
}
