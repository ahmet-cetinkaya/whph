import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/domain/features/habits/habit_record.dart';
import 'package:whph/domain/features/habits/habit_tag.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/domain/features/sync/sync_device.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_repository.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_tag_repository.dart';
import 'package:whph/persistence/features/habits/drift_habit_records_repository.dart';
import 'package:whph/persistence/features/habits/drift_habit_tags_repository.dart';
import 'package:whph/persistence/features/habits/drift_habits_repository.dart';
import 'package:whph/persistence/features/settings/drift_settings_repository.dart';
import 'package:whph/persistence/features/sync/drift_sync_device_repository.dart';
import 'package:whph/persistence/features/tags/drift_tag_repository.dart';
import 'package:whph/persistence/features/tags/drift_tag_tag_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_tag_repository.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.steps.dart';

part 'drift_app_context.g.dart';

const String folderName = "whph";
const String databaseName = 'whph.db';

@DriftDatabase(
  tables: [
    AppUsageTable,
    AppUsageTagTable,
    HabitTable,
    HabitTagTable,
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
  static bool isTestMode = false;
  static Directory? testDirectory;

  static AppDatabase instance() {
    return _instance ??= AppDatabase();
  }

  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  // Constructor for testing
  AppDatabase.withExecutor(super.executor) {
    isTestMode = true;
  }

  // Constructor for testing with in-memory database
  factory AppDatabase.forTesting() {
    isTestMode = true;
    return AppDatabase(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(onCreate: (Migrator m) async {
      await m.createAll();
    }, beforeOpen: (details) async {
      if (!isTestMode) {
        // Create database directory if it doesn't exist
        final dbFolder = await getApplicationDocumentsDirectory();
        final dbDirectory = Directory(p.join(dbFolder.path, folderName));
        if (!await dbDirectory.exists()) {
          await dbDirectory.create(recursive: true);
        }
      }

      // Verify that all tables are created
      await customStatement('PRAGMA foreign_keys = ON');
    }, onUpgrade: stepByStep(from1To2: (m, schema) async {
      // Add color column to tag table
      await m.addColumn(tagTable, tagTable.color);
    }));
  }

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      late final File file;
      if (isTestMode) {
        file = File(p.join(testDirectory?.path ?? Directory.systemTemp.path, databaseName));
      } else {
        final dbFolder = await getApplicationDocumentsDirectory();
        file = File(p.join(dbFolder.path, folderName, databaseName));
        await file.parent.create(recursive: true);
      }
      return NativeDatabase.createInBackground(file);
    });
  }
}
