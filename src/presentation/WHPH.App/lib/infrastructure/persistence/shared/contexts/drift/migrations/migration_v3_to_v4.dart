import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v3 -> v4: Create AppUsageTimeRecord table, migrate durations
Future<void> migrateV3ToV4(AppDatabase db, Migrator m, Schema4 schema) async {
  await m.createTable(schema.appUsageTimeRecordTable);

  await db.customStatement('''
    INSERT INTO app_usage_time_record_table (
      id, app_usage_id, duration, created_date, modified_date, deleted_date
    )
    SELECT
      LOWER(HEX(RANDOMBLOB(4))) || '-' || LOWER(HEX(RANDOMBLOB(2))) || '-4' ||
      SUBSTR(LOWER(HEX(RANDOMBLOB(2))), 2) || '-' ||
      SUBSTR('89ab', ABS(RANDOM()) % 4 + 1, 1) ||
      SUBSTR(LOWER(HEX(RANDOMBLOB(2))), 2) || '-' ||
      LOWER(HEX(RANDOMBLOB(6))),
      id, duration, created_date, modified_date, deleted_date
    FROM app_usage_table
    WHERE duration > 0 AND deleted_date IS NULL
  ''');

  await m.dropColumn(db.appUsageTable, "duration");
}
