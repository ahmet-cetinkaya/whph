import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v4 -> v5: Create AppUsageTagRule table
Future<void> migrateV4ToV5(AppDatabase db, Migrator m, Schema5 schema) async {
  await db.customStatement('''
    CREATE TABLE app_usage_tag_rule_table (
      id TEXT NOT NULL,
      pattern TEXT NOT NULL,
      tag_id TEXT NOT NULL,
      description TEXT NULL,
      is_active INTEGER NOT NULL DEFAULT (1) CHECK (is_active IN (0, 1)),
      created_date INTEGER NOT NULL,
      modified_date INTEGER NULL,
      deleted_date INTEGER NULL,
      PRIMARY KEY(id)
    )
  ''');
}
