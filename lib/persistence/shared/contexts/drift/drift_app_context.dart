import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whph/domain/features/app_usage/app_usage.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/persistence/features/app_usage/drift_app_usage_repository.dart';
import 'package:whph/persistence/features/tags/drift_tag_repository.dart';
import 'package:whph/persistence/features/tags/drift_tag_tag_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_repository.dart';

part 'drift_app_context.g.dart';

const String folderName = "whph";
const String databaseName = 'whph.db';

@DriftDatabase(
  tables: [AppUsageTable, TaskTable, TagTable, TagTagTable],
)
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;

  static AppDatabase instance() {
    return _instance ??= AppDatabase();
  }

  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, folderName, databaseName));
    return NativeDatabase.createInBackground(file);
  });
}
