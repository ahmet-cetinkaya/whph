import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v16 -> v17: Convert datetime columns to UTC
Future<void> migrateV16ToV17(AppDatabase db, Migrator m, Schema17 schema) async {
  await db.customStatement('''
    UPDATE habit_record_table
    SET date = datetime(date)
    WHERE date LIKE '%+%' OR date LIKE '%-0%' OR date LIKE '%-1%' OR date LIKE '%-2%'
  ''');

  await db.customStatement('''
    UPDATE task_table
    SET planned_date = datetime(planned_date)
    WHERE planned_date IS NOT NULL
    AND (planned_date LIKE '%+%' OR planned_date LIKE '%-0%' OR planned_date LIKE '%-1%' OR planned_date LIKE '%-2%')
  ''');

  await db.customStatement('''
    UPDATE task_table
    SET deadline_date = datetime(deadline_date)
    WHERE deadline_date IS NOT NULL
    AND (deadline_date LIKE '%+%' OR deadline_date LIKE '%-0%' OR deadline_date LIKE '%-1%' OR deadline_date LIKE '%-2%')
  ''');

  await db.customStatement('''
    UPDATE sync_device_table
    SET last_sync_date = datetime(strftime('%s', last_sync_date), 'unixepoch', 'utc')
    WHERE last_sync_date IS NOT NULL
  ''');
}
