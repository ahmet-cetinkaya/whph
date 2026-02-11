import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v12 -> v13: Invert priority values
Future<void> migrateV12ToV13(AppDatabase db, Migrator m, Schema13 schema) async {
  await db.customStatement('ALTER TABLE task_table ADD COLUMN temp_priority INTEGER');

  await db.customStatement('''
    UPDATE task_table
    SET temp_priority = CASE priority
      WHEN 0 THEN 3
      WHEN 1 THEN 2
      WHEN 2 THEN 1
      WHEN 3 THEN 0
      ELSE NULL
    END
  ''');

  await db.customStatement('UPDATE task_table SET priority = temp_priority');
  await db.customStatement('ALTER TABLE task_table DROP COLUMN temp_priority');
}
