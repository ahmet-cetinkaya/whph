import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/domain/features/habits/habit_record.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/domain/features/sync/sync_device.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_repository.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_tag_repository.dart';
import 'package:whph/persistence/features/habits/drift_habit_records_repository.dart';
import 'package:whph/persistence/features/habits/drift_habits_repository.dart';
import 'package:whph/persistence/features/settings/drift_settings_repository.dart';
import 'package:whph/persistence/features/sync/drift_sync_device_repository.dart';
import 'package:whph/persistence/features/tags/drift_tag_repository.dart';
import 'package:whph/persistence/features/tags/drift_tag_tag_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_tag_repository.dart';

part 'drift_app_context.g.dart';

const String folderName = "whph";
const String databaseName = 'whph.db';

@DriftDatabase(
  tables: [
    AppUsageTable,
    AppUsageTagTable,
    HabitTable,
    HabitRecordTable,
    TaskTable,
    TaskTagTable,
    TagTable,
    TagTagTable,
    SettingTable,
    SyncDeviceTable
  ],
)
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;
  static AppDatabase instance() {
    return _instance ??= AppDatabase();
  }

  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, folderName, databaseName));
      return NativeDatabase.createInBackground(file);
    });
  }
}
