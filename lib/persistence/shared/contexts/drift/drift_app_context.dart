import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/application/shared/utils/key_helper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/domain/features/habits/habit_record.dart';
import 'package:whph/domain/features/habits/habit_tag.dart';
import 'package:whph/domain/features/notes/note.dart';
import 'package:whph/domain/features/notes/note_tag.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/domain/features/sync/sync_device.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/domain/features/tasks/task_time_record.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_ignore_rule_repository.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_repository.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_tag_repository.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_tag_rule_repository.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_time_record_repository.dart';
import 'package:whph/persistence/features/habits/drift_habit_records_repository.dart';
import 'package:whph/persistence/features/habits/drift_habit_tags_repository.dart';
import 'package:whph/persistence/features/habits/drift_habits_repository.dart';
import 'package:whph/persistence/features/notes/drift_note_repository.dart';
import 'package:whph/persistence/features/notes/drift_note_tag_repository.dart';
import 'package:whph/persistence/features/settings/drift_settings_repository.dart';
import 'package:whph/persistence/features/sync/drift_sync_device_repository.dart';
import 'package:whph/persistence/features/tags/drift_tag_repository.dart';
import 'package:whph/persistence/features/tags/drift_tag_tag_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_tag_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_time_record_repository.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.steps.dart';

part 'drift_app_context.g.dart';

String folderName = AppInfo.shortName.toLowerCase();
String databaseName = "${AppInfo.shortName.toLowerCase()}.db";

@DriftDatabase(
  tables: [
    AppUsageIgnoreRuleTable,
    AppUsageTable,
    AppUsageTagRuleTable,
    AppUsageTagTable,
    AppUsageTimeRecordTable,
    HabitRecordTable,
    HabitTable,
    HabitTagTable,
    NoteTable,
    NoteTagTable,
    SettingTable,
    SyncDeviceTable,
    TagTable,
    TagTagTable,
    TaskTable,
    TaskTagTable,
    TaskTimeRecordTable,
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
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
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
      },
      onUpgrade: stepByStep(
        from1To2: (m, schema) async {
          await m.addColumn(tagTable, tagTable.color);
        },
        from2To3: (m, schema) async {
          // Create TaskTimeRecord table
          await m.createTable(taskTimeRecordTable);

          // Drop column elapsed time from Task table
          await m.dropColumn(taskTable, "elapsed_time");
        },
        from3To4: (m, schema) async {
          // Create AppUsageTimeRecord table
          await m.createTable(appUsageTimeRecordTable);

          // Copy existing durations to new time records
          await customStatement('''
            INSERT INTO app_usage_time_record_table (
              id,
              app_usage_id,
              duration,
              created_date,
              modified_date,
              deleted_date
            )
            SELECT
              LOWER(HEX(RANDOMBLOB(4))) || '-' || LOWER(HEX(RANDOMBLOB(2))) || '-4' ||
              SUBSTR(LOWER(HEX(RANDOMBLOB(2))), 2) || '-' ||
              SUBSTR('89ab', ABS(RANDOM()) % 4 + 1, 1) ||
              SUBSTR(LOWER(HEX(RANDOMBLOB(2))), 2) || '-' ||
              LOWER(HEX(RANDOMBLOB(6))),
              id,
              duration,
              created_date,
              modified_date,
              deleted_date
            FROM app_usage_table
            WHERE duration > 0 AND deleted_date IS NULL
          ''');

          // Drop duration column from AppUsage table
          await m.dropColumn(appUsageTable, "duration");
        },
        from4To5: (m, schema) async {
          // Create AppUsageTagRule table with correct SQLite types and constraints
          await customStatement('''
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
        },
        from5To6: (m, schema) async {
          // Add deviceName column to AppUsage table
          await m.addColumn(appUsageTable, appUsageTable.deviceName);
        },
        from6To7: (m, schema) async {
          // Add estimatedTime column to Habit table
          await m.addColumn(habitTable, habitTable.estimatedTime);
        },
        from7To8: (m, schema) async {
          // Create AppUsageIgnoreRule table
          await m.createTable(appUsageIgnoreRuleTable);

          // Get existing ignore rules from settings
          final existingRules = await customSelect(
            'SELECT value FROM setting_table WHERE key = ? AND deleted_date IS NULL',
            variables: [Variable('APP_USAGE_IGNORE_LIST')],
          ).getSingleOrNull();

          if (existingRules != null && existingRules.data['value'] != null) {
            final patterns = (existingRules.data['value'] as String)
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .map((line) => line.trim());

            // Insert each pattern as a new ignore rule
            for (final pattern in patterns) {
              await customInsert(
                'INSERT INTO app_usage_ignore_rule_table (id, pattern, created_date) VALUES (?, ?, ?)',
                variables: [
                  Variable(KeyHelper.generateStringId()),
                  Variable(pattern),
                  Variable(DateTime.now().toIso8601String()),
                ],
              );
            }

            // Delete the old setting
            await customUpdate(
              'UPDATE setting_table SET deleted_date = ? WHERE key = ?',
              variables: [
                Variable(DateTime.now().toIso8601String()),
                Variable('APP_USAGE_IGNORE_LIST'),
              ],
            );
          }
        },
        from8To9: (m, schema) async {
          await customStatement('DROP TABLE IF EXISTS app_usage_tag_rule_table_temp');

          await customStatement('''
            CREATE TABLE app_usage_tag_rule_table_temp (
              id TEXT NOT NULL,
              pattern TEXT NOT NULL,
              tag_id TEXT NOT NULL,
              description TEXT NULL,
              created_date INTEGER NOT NULL,
              modified_date INTEGER NULL,
              deleted_date INTEGER NULL,
              PRIMARY KEY(id)
            )
          ''');

          // Fix timestamp conversion to handle NULL and ensure NOT NULL for created_date
          await customStatement('''
            INSERT INTO app_usage_tag_rule_table_temp
            SELECT
              id,
              pattern,
              tag_id,
              description,
              COALESCE(CAST(strftime('%s000', created_date) AS INTEGER),
                      CAST(strftime('%s000', 'now') AS INTEGER)) as created_date,
              CASE
                WHEN modified_date IS NULL THEN NULL
                ELSE CAST(strftime('%s000', modified_date) AS INTEGER)
              END as modified_date,
              CASE
                WHEN deleted_date IS NULL THEN NULL
                ELSE CAST(strftime('%s000', deleted_date) AS INTEGER)
              END as deleted_date
            FROM app_usage_tag_rule_table
          ''');

          await customStatement('DROP TABLE app_usage_tag_rule_table');
          await customStatement('ALTER TABLE app_usage_tag_rule_table_temp RENAME TO app_usage_tag_rule_table');
        },
        from9To10: (m, schema) async {
          // Update existing timestamps to Unix timestamp format (milliseconds)
          await customStatement('''
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
        },
        from10To11: (m, schema) async {
          // First, delete all existing sync device records since we're changing the sync logic
          await customStatement('DELETE FROM sync_device_table');

          // Add new device ID columns
          await m.addColumn(syncDeviceTable, syncDeviceTable.fromDeviceId);
          await m.addColumn(syncDeviceTable, syncDeviceTable.toDeviceId);
        },
        from11To12: (m, schema) async {
          // Add parentTaskId column to Task table
          await m.addColumn(taskTable, taskTable.parentTaskId);
        },
        from12To13: (m, schema) async {
          // Add temporary column
          await customStatement('ALTER TABLE task_table ADD COLUMN temp_priority INTEGER');

          // Copy and convert values (3->0, 2->1, 1->2, 0->3)
          await customStatement('''
            UPDATE task_table
            SET temp_priority = CASE priority
              WHEN 0 THEN 3
              WHEN 1 THEN 2
              WHEN 2 THEN 1
              WHEN 3 THEN 0
              ELSE NULL
            END
          ''');

          // Update the original priority column
          await customStatement('''
            UPDATE task_table
            SET priority = temp_priority
          ''');

          // Drop temporary column
          await customStatement('ALTER TABLE task_table DROP COLUMN temp_priority');
        },
        from13To14: (m, schema) async {
          // Add order column to Task table
          await m.addColumn(taskTable, taskTable.order);
        },
        from14To15: (m, schema) async {
          // Create Note and NoteTag tables
          await m.createTable(noteTable);
          await m.createTable(noteTagTable);
        },
        from15To16: (m, schema) async {
          // Add reminder fields to Task table
          await m.addColumn(taskTable, taskTable.plannedDateReminderTime);
          await m.addColumn(taskTable, taskTable.deadlineDateReminderTime);

          // Add reminder fields to Habit table
          await m.addColumn(habitTable, habitTable.hasReminder);
          await m.addColumn(habitTable, habitTable.reminderTime);
          await m.addColumn(habitTable, habitTable.reminderDays);
        },
        from16To17: (Migrator m, Schema17 schema) async {
          // Convert habit_record_table date column to UTC
          await customStatement('''
            UPDATE habit_record_table
            SET date = datetime(date)
            WHERE date LIKE '%+%' OR date LIKE '%-0%' OR date LIKE '%-1%' OR date LIKE '%-2%'
          ''');

          // Convert task_table planned_date column to UTC
          await customStatement('''
            UPDATE task_table 
            SET planned_date = datetime(planned_date)
            WHERE planned_date IS NOT NULL 
            AND (planned_date LIKE '%+%' OR planned_date LIKE '%-0%' OR planned_date LIKE '%-1%' OR planned_date LIKE '%-2%')
          ''');

          // Convert task_table deadline_date column to UTC
          await customStatement('''
            UPDATE task_table
            SET deadline_date = datetime(deadline_date)
            WHERE deadline_date IS NOT NULL
            AND (deadline_date LIKE '%+%' OR deadline_date LIKE '%-0%' OR deadline_date LIKE '%-1%' OR deadline_date LIKE '%-2%')
          ''');

          // Convert sync_device_table last_sync_date column to UTC
          await customStatement('''
            UPDATE sync_device_table
            SET last_sync_date = datetime(strftime('%s', last_sync_date), 'unixepoch', 'utc')
            WHERE last_sync_date IS NOT NULL
          ''');
        },
        from17To18: (Migrator m, Schema18 schema) async {
          // Add archivedDate column to Habit table
          await m.addColumn(habitTable, habitTable.archivedDate);
        },
        from18To19: (Migrator m, Schema19 schema) async {
          // Add recurrence fields to Task table
          await m.addColumn(taskTable, taskTable.recurrenceType);
          await m.addColumn(taskTable, taskTable.recurrenceInterval);
          await m.addColumn(taskTable, taskTable.recurrenceDaysString);
          await m.addColumn(taskTable, taskTable.recurrenceStartDate);
          await m.addColumn(taskTable, taskTable.recurrenceEndDate);
          await m.addColumn(taskTable, taskTable.recurrenceCount);
          await m.addColumn(taskTable, taskTable.recurrenceParentId);
        },
        from19To20: (Migrator m, Schema20 schema) async {
          // Add goal-related fields to Habit table
          await m.addColumn(habitTable, habitTable.hasGoal);
          await m.addColumn(habitTable, habitTable.targetFrequency);
          await m.addColumn(habitTable, habitTable.periodDays);
        },
      ),
    );
  }

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      late final File file;
      if (isTestMode) {
        file = File(p.join(testDirectory?.path ?? Directory.systemTemp.path, databaseName));
      } else {
        final dbFolder = await getApplicationDocumentsDirectory();
        file = File(p.join(dbFolder.path, folderName, kDebugMode ? 'debug_$databaseName' : databaseName));
        await file.parent.create(recursive: true);
      }
      return NativeDatabase.createInBackground(file);
    });
  }
}
