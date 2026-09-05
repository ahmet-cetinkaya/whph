import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

Future<void> migrateV36ToV37(AppDatabase db, Migrator m, Schema37 schema) async {
  await m.addColumn(db.habitTable, db.habitTable.type);
}
