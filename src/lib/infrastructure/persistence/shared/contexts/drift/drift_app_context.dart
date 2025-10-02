import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/notes/note_tag.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/tags/tag_tag.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/drift_app_usage_ignore_rule_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/drift_app_usage_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/drift_app_usage_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/drift_app_usage_tag_rule_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/drift_app_usage_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/notes/drift_note_repository.dart';
import 'package:whph/infrastructure/persistence/features/notes/drift_note_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/settings/drift_settings_repository.dart';
import 'package:whph/infrastructure/persistence/features/sync/drift_sync_device_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/drift_tag_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/drift_task_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

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
    HabitTimeRecordTable,
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
  static IContainer? _container;

  static AppDatabase instance([IContainer? container]) {
    if (container != null) {
      _container = container;
    }
    return _instance ??= AppDatabase(_openConnection());
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
  int get schemaVersion => 28;

  /// Validates migration version numbers
  void _validateMigrationVersions(int from, int to) {
    if (from < 0) {
      throw StateError('Migration from version cannot be negative: $from');
    }
    if (to < 0) {
      throw StateError('Migration to version cannot be negative: $to');
    }
    if (from > to) {
      throw StateError('Migration from version ($from) cannot be greater than to version ($to)');
    }
    if (to > schemaVersion) {
      throw StateError('Migration to version ($to) cannot exceed schema version ($schemaVersion)');
    }
  }

  /// Validates database connection state
  Future<void> _validateConnectionState() async {
    try {
      final result = await customSelect('SELECT 1').getSingleOrNull();
      if (result == null) {
        throw StateError('Database connection validation failed');
      }
    } catch (e) {
      throw StateError('Database connection is invalid: $e');
    }
  }

  /// Creates a backup of the database before migration
  Future<void> _createBackupBeforeMigration(int from, int to) async {
    if (isTestMode) return; // Skip backup in test mode

    try {
      final dbFolder = await _getApplicationDirectory();
      final dbFile = File(p.join(dbFolder.path, kDebugMode ? 'debug_$databaseName' : databaseName));

      if (await dbFile.exists()) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
        final backupFile = File(p.join(
          dbFolder.path,
          'backup_v${from}_to_v${to}_$timestamp.db',
        ));

        await dbFile.copy(backupFile.path);
        debugPrint('Database backup created: ${backupFile.path}');
      }
    } catch (e) {
      debugPrint('Warning: Failed to create database backup: $e');
      // Don't fail migration if backup fails, but log it
    }
  }

  /// Validates data integrity after migration
  Future<void> _validateDataIntegrity() async {
    try {
      // Check foreign key integrity
      final violations = await customSelect('PRAGMA foreign_key_check').get();
      if (violations.isNotEmpty) {
        throw StateError('Foreign key integrity violations detected: ${violations.length} violations');
      }

      // Verify all tables exist
      final tables = await customSelect('''
        SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'
      ''').get();

      if (tables.isEmpty) {
        throw StateError('No tables found in database after migration');
      }

      debugPrint('Data integrity validation passed: ${tables.length} tables verified');
    } catch (e) {
      throw StateError('Data integrity validation failed: $e');
    }
  }

  /// Lists available database backups for recovery
  Future<List<File>> _listAvailableBackups() async {
    if (isTestMode) return [];

    try {
      final dbFolder = await _getApplicationDirectory();
      final dbDirectory = Directory(dbFolder.path);

      if (!await dbDirectory.exists()) {
        return [];
      }

      final backupFiles = <File>[];
      await for (final entity in dbDirectory.list()) {
        if (entity is File && entity.path.contains('backup_v') && entity.path.endsWith('.db')) {
          backupFiles.add(entity);
        }
      }

      // Sort by modification time, newest first
      backupFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return backupFiles;
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  /// Attempts to restore from the most recent backup
  /// This should only be called manually in case of catastrophic migration failure
  Future<bool> restoreFromBackup({File? specificBackup}) async {
    if (isTestMode) {
      debugPrint('Backup restoration not available in test mode');
      return false;
    }

    try {
      final dbFolder = await _getApplicationDirectory();
      final currentDbFile = File(p.join(dbFolder.path, kDebugMode ? 'debug_$databaseName' : databaseName));

      final backupFile = specificBackup ?? (await _listAvailableBackups()).firstOrNull;

      if (backupFile == null) {
        debugPrint('No backup files found');
        return false;
      }

      debugPrint('Restoring database from backup: ${backupFile.path}');

      // Close current database connection before restoration
      await close();

      // Delete current database
      if (await currentDbFile.exists()) {
        await currentDbFile.delete();
      }

      // Restore from backup
      await backupFile.copy(currentDbFile.path);

      debugPrint('Database restored successfully from backup');
      return true;
    } catch (e) {
      debugPrint('CRITICAL: Failed to restore from backup: $e');
      return false;
    }
  }

  /// Creates a manual database backup (for use before risky operations like import)
  /// Returns the backup file or null if operation fails
  Future<File?> createDatabaseBackup() async {
    if (isTestMode) return null;

    try {
      final dbFolder = await _getApplicationDirectory();
      final dbFile = File(p.join(dbFolder.path, kDebugMode ? 'debug_$databaseName' : databaseName));

      if (await dbFile.exists()) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
        final backupFile = File(p.join(
          dbFolder.path,
          'import_backup_$timestamp.db',
        ));

        await dbFile.copy(backupFile.path);
        debugPrint('Manual database backup created: ${backupFile.path}');
        return backupFile;
      }

      return null;
    } catch (e) {
      debugPrint('Failed to create manual database backup: $e');
      return null;
    }
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        try {
          debugPrint('Creating database schema version $schemaVersion');
          await m.createAll();
          await customStatement('PRAGMA foreign_keys = ON');
          debugPrint('Database schema created successfully');
        } catch (e, stackTrace) {
          debugPrint('Error creating database schema: $e\n$stackTrace');
          rethrow;
        }
      },
      beforeOpen: (details) async {
        try {
          if (!isTestMode) {
            // Create database directory if it doesn't exist
            final dbFolder = await _getApplicationDirectory();
            final dbDirectory = Directory(dbFolder.path);
            if (!await dbDirectory.exists()) {
              await dbDirectory.create(recursive: true);
              debugPrint('Created database directory: ${dbDirectory.path}');
            }
          }

          // Validate connection state
          await _validateConnectionState();

          // Enable foreign keys
          await customStatement('PRAGMA foreign_keys = ON');

          // Log migration info
          if (details.hadUpgrade) {
            debugPrint('Migration completed from v${details.versionBefore} to v${details.versionNow}');
          } else if (details.versionNow == schemaVersion) {
            debugPrint('Database schema is current: v${details.versionNow}');
          }
        } catch (e, stackTrace) {
          debugPrint('Error in beforeOpen: $e\n$stackTrace');
          rethrow;
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        try {
          debugPrint('Starting migration from version $from to $to');

          // Validate migration parameters
          _validateMigrationVersions(from, to);

          // Create backup before migration
          await _createBackupBeforeMigration(from, to);

          // Validate connection before migration
          await _validateConnectionState();

          // Run migration steps in transaction
          await transaction(() async {
            await stepByStep(
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
                await m.createTable(schema.appUsageTimeRecordTable);

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
                try {
                  // Create AppUsageIgnoreRule table
                  await m.createTable(appUsageIgnoreRuleTable);

                  // Get existing ignore rules from settings
                  final existingRules = await customSelect(
                    'SELECT value FROM setting_table WHERE key = ? AND deleted_date IS NULL',
                    variables: [Variable('APP_USAGE_IGNORE_LIST')],
                  ).getSingleOrNull();

                  if (existingRules != null && existingRules.data['value'] != null) {
                    final valueData = existingRules.data['value'];
                    if (valueData is String && valueData.isNotEmpty) {
                      final patterns = valueData
                          .split('\n')
                          .where((line) => line.trim().isNotEmpty)
                          .map((line) => line.trim())
                          .toList();

                      // Insert each pattern as a new ignore rule
                      for (final pattern in patterns) {
                        if (pattern.isNotEmpty) {
                          await customInsert(
                            'INSERT INTO app_usage_ignore_rule_table (id, pattern, created_date) VALUES (?, ?, ?)',
                            variables: [
                              Variable(KeyHelper.generateStringId()),
                              Variable(pattern),
                              Variable(DateTime.now().toIso8601String()),
                            ],
                          );
                        }
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
                  }
                } catch (e) {
                  debugPrint('Warning: Migration v7->v8 partial failure: $e');
                  // Continue migration even if this optional data migration fails
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
              from20To21: (m, schema) async {
                try {
                  // Verify table exists before checking columns
                  final tableExists = await customSelect('''
                SELECT name FROM sqlite_master WHERE type='table' AND name='app_usage_time_record_table'
              ''').getSingleOrNull();

                  if (tableExists == null) {
                    throw StateError('app_usage_time_record_table does not exist');
                  }

                  // Check if usage_date column already exists
                  final tableInfo = await customSelect('''
                PRAGMA table_info(app_usage_time_record_table)
              ''').get();

                  final usageDateExists = tableInfo.any((row) => row.data['name'] == 'usage_date');

                  if (!usageDateExists) {
                    // Add usage_date column
                    await m.addColumn(appUsageTimeRecordTable, appUsageTimeRecordTable.usageDate);

                    // Set usage_date to created_date for all existing records
                    await customStatement('''
                  UPDATE app_usage_time_record_table
                  SET usage_date = created_date
                  WHERE usage_date IS NULL
                ''');

                    debugPrint('Updated app_usage_time_record_table with usage_date from created_date');
                  }
                } catch (e) {
                  debugPrint('Error in migration v20->v21: $e');
                  rethrow;
                }
              },
              from21To22: (m, schema) async {
                // Add order column to habit table for custom sorting
                await m.addColumn(habitTable, habitTable.order);

                // Set default order values for existing habits based on created_date
                await customStatement('''
              WITH ordered_habits AS (
                SELECT id, ROW_NUMBER() OVER (ORDER BY created_date ASC) * 1000.0 AS new_order
                FROM habit_table
                WHERE deleted_date IS NULL
              )
              UPDATE habit_table
              SET [order] = (SELECT new_order FROM ordered_habits WHERE ordered_habits.id = habit_table.id)
              WHERE habit_table.id IN (SELECT id FROM ordered_habits)
            ''');
              },
              from22To23: (m, schema) async {
                try {
                  // Clean up duplicate task records by keeping only the first occurrence of each ID
                  // This migration addresses the "orphaned task" issue where duplicate records
                  // caused "Too many elements" errors in getById() operations

                  // Verify task_table exists
                  final tableExists = await customSelect('''
                SELECT name FROM sqlite_master WHERE type='table' AND name='task_table'
              ''').getSingleOrNull();

                  if (tableExists == null) {
                    throw StateError('task_table does not exist');
                  }

                  // Count duplicates before deletion
                  final duplicates = await customSelect('''
                SELECT COUNT(*) as count FROM (
                  SELECT id FROM task_table GROUP BY id HAVING COUNT(*) > 1
                )
              ''').getSingleOrNull();

                  final duplicateCount = (duplicates?.data['count'] as int?) ?? 0;
                  if (duplicateCount > 0) {
                    debugPrint('Found $duplicateCount duplicate task IDs, cleaning up...');
                  }

                  // Delete duplicate records (keep the first record for each ID)
                  await customStatement('''
                DELETE FROM task_table
                WHERE rowid NOT IN (
                  SELECT MIN(rowid)
                  FROM task_table
                  GROUP BY id
                )
              ''');

                  // Recreate the task table with proper primary key constraint
                  await customStatement('''
                CREATE TABLE task_table_new (
                  id TEXT NOT NULL,
                  parent_task_id TEXT NULL,
                  title TEXT NOT NULL,
                  description TEXT NULL,
                  priority INTEGER NULL,
                  planned_date INTEGER NULL,
                  deadline_date INTEGER NULL,
                  estimated_time INTEGER NULL,
                  is_completed INTEGER NOT NULL DEFAULT (0) CHECK ("is_completed" IN (0, 1)),
                  created_date INTEGER NOT NULL,
                  modified_date INTEGER NULL,
                  deleted_date INTEGER NULL,
                  "order" REAL NOT NULL DEFAULT 0.0,
                  planned_date_reminder_time INTEGER NOT NULL DEFAULT 0,
                  deadline_date_reminder_time INTEGER NOT NULL DEFAULT 0,
                  recurrence_type INTEGER NOT NULL DEFAULT 0,
                  recurrence_interval INTEGER NULL,
                  recurrence_days_string TEXT NULL,
                  recurrence_start_date INTEGER NULL,
                  recurrence_end_date INTEGER NULL,
                  recurrence_count INTEGER NULL,
                  recurrence_parent_id TEXT NULL,
                  PRIMARY KEY (id)
                )
              ''');

                  // Copy data to the new table (duplicates should already be removed)
                  await customStatement('''
                INSERT INTO task_table_new (id, parent_task_id, title, description, priority, planned_date, deadline_date, estimated_time, is_completed, created_date, modified_date, deleted_date, "order", planned_date_reminder_time, deadline_date_reminder_time, recurrence_type, recurrence_interval, recurrence_days_string, recurrence_start_date, recurrence_end_date, recurrence_count, recurrence_parent_id)
                SELECT id, parent_task_id, title, description, priority, planned_date, deadline_date, estimated_time, is_completed, created_date, modified_date, deleted_date, "order", planned_date_reminder_time, deadline_date_reminder_time, recurrence_type, recurrence_interval, recurrence_days_string, recurrence_start_date, recurrence_end_date, recurrence_count, recurrence_parent_id FROM task_table
              ''');

                  // Verify records were copied
                  final copiedCount =
                      await customSelect('SELECT COUNT(*) as count FROM task_table_new').getSingleOrNull();
                  final insertCount = (copiedCount?.data['count'] as int?) ?? 0;
                  debugPrint('Copied $insertCount task records to new table');

                  // Drop the old table and rename the new one
                  await customStatement('DROP TABLE task_table');
                  await customStatement('ALTER TABLE task_table_new RENAME TO task_table');
                } catch (e) {
                  debugPrint('Error in migration v22->v23: $e');
                  rethrow;
                }
              },
              from23To24: (m, schema) async {
                // Step 1: Create new habit_record_table with updated schema
                await customStatement('''
              CREATE TABLE habit_record_table_new (
                id TEXT NOT NULL,
                created_date INTEGER NOT NULL,
                modified_date INTEGER NULL,
                deleted_date INTEGER NULL,
                habit_id TEXT NOT NULL,
                occurred_at INTEGER NOT NULL,
                PRIMARY KEY (id)
              )
            ''');

                // Step 2: Copy data from old table, mapping date to occurred_at
                // Ensure occurred_at is never NULL by using created_date as fallback
                await customStatement('''
              INSERT INTO habit_record_table_new (id, created_date, modified_date, deleted_date, habit_id, occurred_at)
              SELECT id, created_date, modified_date, deleted_date, habit_id, COALESCE(date, created_date)
              FROM habit_record_table
            ''');

                // Step 3: Drop old table and rename new one
                await customStatement('DROP TABLE habit_record_table');
                await customStatement('ALTER TABLE habit_record_table_new RENAME TO habit_record_table');

                // Step 4: Add daily_target column to habit_table
                await m.addColumn(habitTable, habitTable.dailyTarget);

                // Step 5: Add index for performance on habit records
                await customStatement(
                    'CREATE INDEX idx_habit_record_habit_occurred_at ON habit_record_table (habit_id, occurred_at)');

                // Step 6: Create HabitTimeRecord table for tracking actual time spent on habits
                await customStatement('''
              CREATE TABLE habit_time_record_table (
                id TEXT NOT NULL,
                created_date INTEGER NOT NULL,
                modified_date INTEGER NULL,
                deleted_date INTEGER NULL,
                habit_id TEXT NOT NULL,
                duration INTEGER NOT NULL,
                PRIMARY KEY (id)
              )
            ''');

                // Step 7: Add index for efficient queries by habit and date
                await customStatement(
                    'CREATE INDEX idx_habit_time_record_habit_date ON habit_time_record_table (habit_id, created_date)');
              },
              from24To25: (m, schema) async {
                // Check if habit_time_record_table exists before attempting to alter it
                final tableExists = await customSelect('''
              SELECT name FROM sqlite_master
              WHERE type='table' AND name='habit_time_record_table'
            ''').getSingleOrNull();

                if (tableExists != null) {
                  // Check if occurred_at column already exists
                  final columnInfo = await customSelect('''
                PRAGMA table_info(habit_time_record_table)
              ''').get();

                  final occurredAtExists = columnInfo.any((row) => row.data['name'] == 'occurred_at');

                  if (!occurredAtExists) {
                    // Add occurredAt column to habit_time_record_table as nullable
                    await m.addColumn(habitTimeRecordTable, habitTimeRecordTable.occurredAt);

                    // Set occurred_at to created_date for existing records
                    await customStatement('''
                  UPDATE habit_time_record_table
                  SET occurred_at = created_date
                  WHERE occurred_at IS NULL
                ''');
                  }
                }
              },
              from25To26: (m, schema) async {
                try {
                  // Verify habit_table exists
                  final habitTableExists = await customSelect('''
                SELECT name FROM sqlite_master WHERE type='table' AND name='habit_table'
              ''').getSingleOrNull();

                  if (habitTableExists == null) {
                    throw StateError('habit_table does not exist');
                  }

                  // Check if order column exists in habit_table before backup
                  final orderColumnExists = await customSelect('''
                SELECT COUNT(*) as count FROM pragma_table_info('habit_table')
                WHERE name = 'order'
              ''').getSingleOrNull();

                  final hasOrderColumn = (orderColumnExists?.data['count'] as int? ?? 0) > 0;
                  debugPrint('habit_table has order column: $hasOrderColumn');

                  // Count records before migration
                  final habitCount = await customSelect('SELECT COUNT(*) as count FROM habit_table').getSingleOrNull();
                  final totalHabits = (habitCount?.data['count'] as int?) ?? 0;
                  debugPrint('Migrating $totalHabits habit records');

                  // Backup habit_table
                  await customStatement('CREATE TEMPORARY TABLE habit_table_backup AS SELECT * FROM habit_table;');

                  // Drop and recreate habit_table with PRIMARY KEY on id
                  await customStatement('DROP TABLE IF EXISTS habit_table;');
                  await customStatement('''
                CREATE TABLE habit_table (
                  id TEXT NOT NULL,
                  created_date INTEGER NOT NULL,
                  modified_date INTEGER NULL,
                  deleted_date INTEGER NULL,
                  name TEXT NOT NULL,
                  description TEXT NOT NULL,
                  estimated_time INTEGER NULL,
                  archived_date INTEGER NULL,
                  has_reminder INTEGER NOT NULL DEFAULT 0 CHECK (has_reminder IN (0, 1)),
                  reminder_time TEXT NULL,
                  reminder_days TEXT NOT NULL DEFAULT '',
                  has_goal INTEGER NOT NULL DEFAULT 0 CHECK (has_goal IN (0, 1)),
                  target_frequency INTEGER NOT NULL DEFAULT 1,
                  period_days INTEGER NOT NULL DEFAULT 7,
                  daily_target INTEGER NULL,
                  `order` REAL NOT NULL DEFAULT 0.0,
                  PRIMARY KEY (id)
                );
              ''');

                  // Restore data to habit_table with explicit column mapping
                  if (hasOrderColumn) {
                    // Backup has order column, copy all columns
                    await customStatement('''
                  INSERT INTO habit_table (
                    id, created_date, modified_date, deleted_date, name, description,
                    estimated_time, archived_date, has_reminder, reminder_time, reminder_days,
                    has_goal, target_frequency, period_days, daily_target, `order`
                  )
                  SELECT
                    id, created_date, modified_date, deleted_date, name, description,
                    estimated_time, archived_date, has_reminder, reminder_time, reminder_days,
                    has_goal, target_frequency, period_days, daily_target, `order`
                  FROM habit_table_backup;
                ''');
                  } else {
                    // Backup missing order column, use default value and assign order based on created_date
                    await customStatement('''
                  INSERT INTO habit_table (
                    id, created_date, modified_date, deleted_date, name, description,
                    estimated_time, archived_date, has_reminder, reminder_time, reminder_days,
                    has_goal, target_frequency, period_days, daily_target, `order`
                  )
                  SELECT
                    id, created_date, modified_date, deleted_date, name, description,
                    estimated_time, archived_date, has_reminder, reminder_time, reminder_days,
                    has_goal, target_frequency, period_days, daily_target,
                    ROW_NUMBER() OVER (ORDER BY created_date ASC) * 1000.0 as `order`
                  FROM habit_table_backup;
                ''');
                  }

                  // Verify data was restored correctly
                  final restoredCount =
                      await customSelect('SELECT COUNT(*) as count FROM habit_table').getSingleOrNull();
                  final restoredHabits = (restoredCount?.data['count'] as int?) ?? 0;
                  if (restoredHabits != totalHabits) {
                    throw StateError('Data loss detected: expected $totalHabits habits, got $restoredHabits');
                  }

                  await customStatement('DROP TABLE habit_table_backup;');

                  // Check if habit_time_record_table exists before backing it up
                  final tableExists = await customSelect('''
                SELECT name FROM sqlite_master
                WHERE type='table' AND name='habit_time_record_table'
              ''').getSingleOrNull();

                  if (tableExists != null) {
                    // Count records before migration
                    final recordCount =
                        await customSelect('SELECT COUNT(*) as count FROM habit_time_record_table').getSingleOrNull();
                    final totalRecords = (recordCount?.data['count'] as int?) ?? 0;

                    // Backup habit_time_record_table
                    await customStatement(
                        'CREATE TEMPORARY TABLE habit_time_record_table_backup AS SELECT * FROM habit_time_record_table;');

                    // Drop and recreate habit_time_record_table with FK to habit_table.id
                    await customStatement('DROP TABLE IF EXISTS habit_time_record_table;');
                    await customStatement('''
                  CREATE TABLE habit_time_record_table (
                    id TEXT NOT NULL,
                    created_date INTEGER NOT NULL,
                    modified_date INTEGER NULL,
                    deleted_date INTEGER NULL,
                    habit_id TEXT NOT NULL REFERENCES habit_table(id) ON DELETE CASCADE,
                    duration INTEGER NOT NULL,
                    occurred_at INTEGER NULL,
                    PRIMARY KEY (id)
                  );
                ''');

                    // Restore data to habit_time_record_table, skipping orphans
                    await customStatement('''
                  INSERT INTO habit_time_record_table
                  SELECT * FROM habit_time_record_table_backup
                  WHERE habit_id IN (SELECT id FROM habit_table);
                ''');

                    // Count restored records to detect orphans
                    final restoredRecordCount =
                        await customSelect('SELECT COUNT(*) as count FROM habit_time_record_table').getSingleOrNull();
                    final restoredRecords = (restoredRecordCount?.data['count'] as int?) ?? 0;
                    final orphanedRecords = totalRecords - restoredRecords;
                    if (orphanedRecords > 0) {
                      debugPrint('Removed $orphanedRecords orphaned habit time records');
                    }

                    await customStatement('DROP TABLE habit_time_record_table_backup;');
                  } else {
                    // Table doesn't exist, create it from scratch
                    await customStatement('''
                  CREATE TABLE habit_time_record_table (
                    id TEXT NOT NULL,
                    created_date INTEGER NOT NULL,
                    modified_date INTEGER NULL,
                    deleted_date INTEGER NULL,
                    habit_id TEXT NOT NULL REFERENCES habit_table(id) ON DELETE CASCADE,
                    duration INTEGER NOT NULL,
                    occurred_at INTEGER NULL,
                    PRIMARY KEY (id)
                  );
                ''');
                  }

                  // Recreate index
                  await customStatement(
                      'CREATE INDEX IF NOT EXISTS idx_habit_time_record_habit_date ON habit_time_record_table (habit_id, created_date);');
                } catch (e) {
                  debugPrint('Error in migration v25->v26: $e');
                  rethrow;
                }
              },
              from26To27: (m, schema) async {
                // Add isEstimated column to habit_time_record_table
                await m.addColumn(habitTimeRecordTable, habitTimeRecordTable.isEstimated);
              },
              from27To28: (m, schema) async {
                // Migrate from isCompleted boolean to completedAt datetime
                // We need to manually recreate the table because m.dropColumn() doesn't work
                // properly when the schema definition has already removed the column

                await transaction(() async {
                  // Step 1: Create new task_table with the updated schema
                  await customStatement('''
                CREATE TABLE task_table_new (
                  id TEXT NOT NULL,
                  parent_task_id TEXT NULL,
                  title TEXT NOT NULL,
                  description TEXT NULL,
                  priority INTEGER NULL,
                  planned_date INTEGER NULL,
                  deadline_date INTEGER NULL,
                  estimated_time INTEGER NULL,
                  completed_at INTEGER NULL,
                  created_date INTEGER NOT NULL,
                  modified_date INTEGER NULL,
                  deleted_date INTEGER NULL,
                  "order" REAL NOT NULL DEFAULT 0.0,
                  planned_date_reminder_time INTEGER NOT NULL DEFAULT 0,
                  deadline_date_reminder_time INTEGER NOT NULL DEFAULT 0,
                  recurrence_type INTEGER NOT NULL DEFAULT 0,
                  recurrence_interval INTEGER NULL,
                  recurrence_days_string TEXT NULL,
                  recurrence_start_date INTEGER NULL,
                  recurrence_end_date INTEGER NULL,
                  recurrence_count INTEGER NULL,
                  recurrence_parent_id TEXT NULL,
                  PRIMARY KEY (id)
                )
              ''');

                  // Step 2: Copy data from old table to new table, migrating is_completed to completed_at
                  await customStatement('''
                INSERT INTO task_table_new (
                  id, parent_task_id, title, description, priority,
                  planned_date, deadline_date, estimated_time, completed_at,
                  created_date, modified_date, deleted_date, "order",
                  planned_date_reminder_time, deadline_date_reminder_time,
                  recurrence_type, recurrence_interval, recurrence_days_string,
                  recurrence_start_date, recurrence_end_date, recurrence_count, recurrence_parent_id
                )
                SELECT
                  id, parent_task_id, title, description, priority,
                  planned_date, deadline_date, estimated_time,
                  CASE WHEN is_completed = 1 THEN COALESCE(modified_date, created_date) ELSE NULL END as completed_at,
                  created_date, modified_date, deleted_date, "order",
                  planned_date_reminder_time, deadline_date_reminder_time,
                  recurrence_type, recurrence_interval, recurrence_days_string,
                  recurrence_start_date, recurrence_end_date, recurrence_count, recurrence_parent_id
                FROM task_table
              ''');

                  // Step 3: Drop the old table
                  await customStatement('DROP TABLE task_table');

                  // Step 4: Rename the new table to the original name
                  await customStatement('ALTER TABLE task_table_new RENAME TO task_table');
                });
              },
            )(m, from, to);

            // Validate data integrity after migration steps
            await _validateDataIntegrity();

            debugPrint('Migration from v$from to v$to completed successfully');
          });
        } catch (e, stackTrace) {
          debugPrint('CRITICAL: Migration from v$from to v$to failed: $e\n$stackTrace');
          debugPrint('Transaction will be rolled back automatically');
          rethrow;
        }
      },
    );
  }

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      late final File file;
      if (isTestMode) {
        file = File(p.join(testDirectory?.path ?? Directory.systemTemp.path, databaseName));
      } else {
        final dbFolder = await _getApplicationDirectory();
        file = File(p.join(dbFolder.path, kDebugMode ? 'debug_$databaseName' : databaseName));
        await file.parent.create(recursive: true);
      }
      return NativeDatabase.createInBackground(file);
    });
  }

  /// Gets the application directory using the injected application directory service
  static Future<Directory> _getApplicationDirectory() async {
    _container ??= Container().instance;
    final applicationDirectoryService = _container!.resolve<IApplicationDirectoryService>();
    return await applicationDirectoryService.getApplicationDirectory();
  }
}
