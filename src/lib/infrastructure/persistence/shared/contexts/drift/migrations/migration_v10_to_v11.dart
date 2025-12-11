import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v10 -> v11: Add device ID columns to sync table
Future<void> migrateV10ToV11(AppDatabase db, Migrator m, Schema11 schema) async {
  await db.customStatement('DELETE FROM sync_device_table');
  await m.addColumn(db.syncDeviceTable, db.syncDeviceTable.fromDeviceId);
  await m.addColumn(db.syncDeviceTable, db.syncDeviceTable.toDeviceId);
}
