import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:acore/acore.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:domain/features/app_usages/app_usage.dart';
import 'package:domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:domain/features/app_usages/app_usage_tag.dart';
import 'package:domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:domain/features/app_usages/app_usage_time_record.dart';
import 'package:domain/features/habits/habit.dart';
import 'package:domain/features/habits/habit_record.dart';
import 'package:domain/features/habits/habit_record_status.dart';
import 'package:domain/features/habits/habit_tag.dart';
import 'package:domain/features/habits/habit_time_record.dart';
import 'package:domain/features/notes/note.dart';
import 'package:domain/features/notes/note_tag.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:domain/features/sync/sync_device.dart';
import 'package:domain/features/tags/tag.dart';
import 'package:domain/features/tags/tag_tag.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/tasks/models/recurrence_configuration.dart';
import 'package:domain/features/tasks/task_tag.dart';
import 'package:domain/features/tasks/task_time_record.dart';
import 'package:domain/shared/constants/app_info.dart';
import 'package:infrastructure_persistence/features/app_usages/repositories/drift_app_usage_ignore_rule_repository.dart';
import 'package:infrastructure_persistence/features/app_usages/repositories/drift_app_usage_repository.dart';
import 'package:infrastructure_persistence/features/app_usages/repositories/drift_app_usage_tag_repository.dart';
import 'package:infrastructure_persistence/features/app_usages/repositories/drift_app_usage_tag_rule_repository.dart';
import 'package:infrastructure_persistence/features/app_usages/repositories/drift_app_usage_time_record_repository.dart';
import 'package:infrastructure_persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:infrastructure_persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:infrastructure_persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:infrastructure_persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:infrastructure_persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:infrastructure_persistence/features/notes/repositories/drift_note_tag_repository.dart';
import 'package:infrastructure_persistence/features/settings/repositories/drift_settings_repository.dart';
import 'package:infrastructure_persistence/features/sync/repositories/drift_sync_device_repository.dart';
import 'package:infrastructure_persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:infrastructure_persistence/features/tags/repositories/drift_tag_tag_repository.dart';
import 'package:infrastructure_persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:infrastructure_persistence/features/tasks/repositories/drift_task_tag_repository.dart';
import 'package:infrastructure_persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/database_backup_service.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/migrations/migrations.dart';

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
  static DatabaseBackupService? _backupService;

  static DatabaseBackupService get backupService {
    return _backupService ??= DatabaseBackupService(
      getApplicationDirectory: _getApplicationDirectory,
      databaseName: databaseName,
      isTestMode: isTestMode,
    );
  }

  static AppDatabase instance([IContainer? container]) {
    if (container != null) {
      _container = container;
    }
    return _instance ??= AppDatabase(_openConnection());
  }

  /// Sets the singleton instance for testing purposes
  static void setInstanceForTesting(AppDatabase db) {
    _instance = db;
    isTestMode = true;
  }

  /// Resets the singleton instance for testing purposes
  static void resetInstance() {
    _instance = null;
    isTestMode = false;
    testDirectory = null;
    _container = null;
    _backupService = null;
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
  int get schemaVersion => 33;

  /// Validates migration version numbers
  void _validateMigrationVersions(int from, int to) {
    if (from < 0) {
      throw StateError('Migration from version cannot be negative: $from');
    }
    if (to < 0) {
      throw StateError('Migration to version cannot be negative: $to');
    }
    if (from > to) {
      // Database version is newer than schema version
      // This can happen if:
      // 1. Code was rolled back but database wasn't
      // 2. Test database from newer version is being reused
      if (isTestMode) {
        // In test mode, throw a clear error suggesting recreation
        throw StateError('Test database version ($from) is newer than schema version ($to). '
            'This indicates a stale test database. The test framework should recreate the database.');
      } else {
        // In production, this is a critical error
        throw StateError('Database version ($from) cannot be greater than schema version ($to). '
            'This may indicate a database from a newer app version. '
            'Please update the app or restore from backup.');
      }
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
    await backupService.createBackupBeforeMigration(from, to);
  }

  /// Validates data integrity after migration
  Future<void> _validateDataIntegrity() async {
    try {
      final violations = await customSelect('PRAGMA foreign_key_check').get();
      if (violations.isNotEmpty) {
        throw StateError('Foreign key integrity violations detected: ${violations.length} violations');
      }

      final tables = await customSelect('''
        SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'
      ''').get();

      if (tables.isEmpty) {
        throw StateError('No tables found in database after migration');
      }

      DomainLogger.info('Data integrity validation passed: ${tables.length} tables verified');
    } catch (e) {
      throw StateError('Data integrity validation failed: $e');
    }
  }

  /// Attempts to restore from the most recent backup
  Future<bool> restoreFromBackup({File? specificBackup}) {
    return backupService.restoreFromBackup(
      specificBackup: specificBackup,
      closeDatabase: close,
    );
  }

  /// Creates a manual database backup
  Future<File?> createDatabaseBackup() => backupService.createDatabaseBackup();

  /// Resets the database by closing the connection and deleting the database file
  Future<void> resetDatabase() {
    return backupService.resetDatabase(
      closeDatabase: close,
      resetInstance: () => _instance = null,
    );
  }

  /// Lists available pre-reset backups for recovery purposes
  Future<List<File>> listPreResetBackups() => backupService.listPreResetBackups();

  /// Restores database from a pre-reset backup file
  Future<bool> restoreFromPreResetBackup(File backupFile) {
    return backupService.restoreFromPreResetBackup(
      backupFile: backupFile,
      closeDatabase: close,
      resetInstance: () => _instance = null,
    );
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        try {
          DomainLogger.info('Creating database schema version $schemaVersion');
          await m.createAll();
          await customStatement('PRAGMA foreign_keys = ON');
          DomainLogger.info('Database schema created successfully');
        } catch (e, stackTrace) {
          DomainLogger.error('Error creating database schema: $e\n$stackTrace');
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
              DomainLogger.info('Created database directory: ${dbDirectory.path}');
            }
          }

          // Validate connection state
          await _validateConnectionState();

          // Enable foreign keys
          await customStatement('PRAGMA foreign_keys = ON');

          // Log migration info
          if (details.hadUpgrade) {
            DomainLogger.info('Migration completed from v${details.versionBefore} to v${details.versionNow}');
          } else if (details.versionNow == schemaVersion) {
            DomainLogger.info('Database schema is current: v${details.versionNow}');
          }
        } catch (e, stackTrace) {
          DomainLogger.error('Error in beforeOpen: $e\n$stackTrace');
          rethrow;
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        try {
          DomainLogger.info('Starting migration from version $from to $to');

          // Validate migration parameters
          _validateMigrationVersions(from, to);

          // Create backup before migration
          await _createBackupBeforeMigration(from, to);

          // Validate connection before migration
          await _validateConnectionState();

          // Run migration steps in transaction
          await transaction(() async {
            await runMigrationSteps(m, from, to);

            // Validate data integrity after migration steps
            await _validateDataIntegrity();

            DomainLogger.info('Migration from v$from to v$to completed successfully');
          });
        } catch (e, stackTrace) {
          DomainLogger.error('CRITICAL: Migration from v$from to v$to failed: $e\n$stackTrace');
          DomainLogger.info('Transaction will be rolled back automatically');
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
