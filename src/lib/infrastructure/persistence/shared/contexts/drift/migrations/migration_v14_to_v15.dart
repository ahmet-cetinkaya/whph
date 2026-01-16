import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migration v14 -> v15: Create Note and NoteTag tables
Future<void> migrateV14ToV15(AppDatabase db, Migrator m, Schema15 schema) async {
  await m.createTable(schema.noteTable);
  await m.createTable(schema.noteTagTable);
}
