import 'package:drift/drift.dart';
import 'package:application/shared/utils/key_helper.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v7 -> v8: Create AppUsageIgnoreRule table, migrate settings
Future<void> migrateV7ToV8(AppDatabase db, Migrator m, Schema8 schema) async {
  try {
    await m.createTable(db.appUsageIgnoreRuleTable);

    final existingRules = await db.customSelect(
      'SELECT value FROM setting_table WHERE key = ? AND deleted_date IS NULL',
      variables: [Variable('APP_USAGE_IGNORE_LIST')],
    ).getSingleOrNull();

    if (existingRules != null && existingRules.data['value'] != null) {
      final valueData = existingRules.data['value'];
      if (valueData is String && valueData.isNotEmpty) {
        final patterns =
            valueData.split('\n').where((line) => line.trim().isNotEmpty).map((line) => line.trim()).toList();

        for (final pattern in patterns) {
          if (pattern.isNotEmpty) {
            await db.customInsert(
              'INSERT INTO app_usage_ignore_rule_table (id, pattern, created_date) VALUES (?, ?, ?)',
              variables: [
                Variable(KeyHelper.generateStringId()),
                Variable(pattern),
                Variable(DateTime.now().toIso8601String()),
              ],
            );
          }
        }

        await db.customUpdate(
          'UPDATE setting_table SET deleted_date = ? WHERE key = ?',
          variables: [
            Variable(DateTime.now().toIso8601String()),
            Variable('APP_USAGE_IGNORE_LIST'),
          ],
        );
      }
    }
  } catch (e) {
    DomainLogger.warning('Migration v7->v8 partial failure: $e');
  }
}
