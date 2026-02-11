import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v9 -> v10: Convert timestamps to Unix format
Future<void> migrateV9ToV10(AppDatabase db, Migrator m, Schema10 schema) async {
  await db.customStatement('''
    UPDATE app_usage_ignore_rule_table
    SET created_date = CAST(strftime('%s', created_date) * 1000 AS INTEGER),
        modified_date = CASE
          WHEN modified_date IS NULL THEN NULL
          ELSE CAST(strftime('%s', modified_date) * 1000 AS INTEGER)
        END,
        deleted_date = CASE
          WHEN deleted_date IS NULL THEN NULL
          ELSE CAST(strftime('%s', deleted_date) * 1000 AS INTEGER)
        END
    WHERE created_date LIKE '%T%'
  ''');
}
