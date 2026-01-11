import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

Future<void> migrateV29ToV30(AppDatabase db, Migrator m, Schema30 schema) async {
  await m.addColumn(db.habitRecordTable, db.habitRecordTable.status);
  await db.customStatement('UPDATE ${db.habitRecordTable.actualTableName} SET status = 0');
}
