import 'package:drift/drift.dart';
import 'package:domain/shared/utils/logger.dart';

import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

Future<void> migrateV29ToV30(AppDatabase db, Migrator m, Schema30 schema) async {
  try {
    await m.addColumn(db.habitRecordTable, db.habitRecordTable.status);
    await db.customStatement('UPDATE ${db.habitRecordTable.actualTableName} SET status = 0');
    DomainLogger.info('Migration V29->V30: Successfully added status column');
  } catch (e) {
    DomainLogger.error('Failed to migrate habit_record_table from V29 to V30: $e');
    throw StateError('Failed to add status column: $e');
  }
}
