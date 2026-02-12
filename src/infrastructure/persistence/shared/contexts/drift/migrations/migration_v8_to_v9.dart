import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v8 -> v9: Recreate AppUsageTagRule table with proper timestamp types
Future<void> migrateV8ToV9(AppDatabase db, Migrator m, Schema9 schema) async {
  await db.customStatement('DROP TABLE IF EXISTS app_usage_tag_rule_table_temp');

  await db.customStatement('''
    CREATE TABLE app_usage_tag_rule_table_temp (
      id TEXT NOT NULL,
      pattern TEXT NOT NULL,
      tag_id TEXT NOT NULL,
      description TEXT NULL,
      created_date INTEGER NOT NULL,
      modified_date INTEGER NULL,
      deleted_date INTEGER NULL,
      PRIMARY KEY(id)
    )
  ''');

  await db.customStatement('''
    INSERT INTO app_usage_tag_rule_table_temp
    SELECT
      id, pattern, tag_id, description,
      COALESCE(CAST(strftime('%s000', created_date) AS INTEGER),
              CAST(strftime('%s000', 'now') AS INTEGER)) as created_date,
      CASE WHEN modified_date IS NULL THEN NULL
           ELSE CAST(strftime('%s000', modified_date) AS INTEGER)
      END as modified_date,
      CASE WHEN deleted_date IS NULL THEN NULL
           ELSE CAST(strftime('%s000', deleted_date) AS INTEGER)
      END as deleted_date
    FROM app_usage_tag_rule_table
  ''');

  await db.customStatement('DROP TABLE app_usage_tag_rule_table');
  await db.customStatement('ALTER TABLE app_usage_tag_rule_table_temp RENAME TO app_usage_tag_rule_table');
}
