import 'package:drift/drift.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v20 -> v21: Add usage_date column
Future<void> migrateV20ToV21(AppDatabase db, Migrator m, Schema21 schema) async {
  try {
    final tableExists = await db.customSelect('''
      SELECT name FROM sqlite_master WHERE type='table' AND name='app_usage_time_record_table'
    ''').getSingleOrNull();

    if (tableExists == null) {
      throw StateError('app_usage_time_record_table does not exist');
    }

    final tableInfo = await db.customSelect('PRAGMA table_info(app_usage_time_record_table)').get();
    final usageDateExists = tableInfo.any((row) => row.data['name'] == 'usage_date');

    if (!usageDateExists) {
      await m.addColumn(db.appUsageTimeRecordTable, db.appUsageTimeRecordTable.usageDate);

      await db.customStatement('''
        UPDATE app_usage_time_record_table
        SET usage_date = created_date
        WHERE usage_date IS NULL
      ''');

      DomainLogger.info('Updated app_usage_time_record_table with usage_date from created_date');
    }
  } catch (e) {
    DomainLogger.error('Error in migration v20->v21: $e');
    rethrow;
  }
}
