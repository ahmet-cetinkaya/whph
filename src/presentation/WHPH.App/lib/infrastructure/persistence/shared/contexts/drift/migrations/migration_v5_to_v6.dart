import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v5 -> v6: Add deviceName column to AppUsage table
Future<void> migrateV5ToV6(AppDatabase db, Migrator m, Schema6 schema) async {
  await m.addColumn(db.appUsageTable, db.appUsageTable.deviceName);
}
