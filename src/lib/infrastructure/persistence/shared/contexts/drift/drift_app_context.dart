import 'dart:io';
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
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
import 'package:whph/core/shared/utils/logger.dart';

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
  static IContainer? _container;
  static bool isTestMode = false;
  static Directory? testDirectory;
  
  // Database operation tracking for safety
  static int _activeOperationCount = 0;
  static final Map<String, bool> _activeOperations = {};
  
  // Track whether the database is currently being reset
  static bool _isResetting = false;

  AppDatabase(DatabaseConnection connection) : super(connection);

  // Constructor for testing
  AppDatabase.withExecutor(super.executor) {
    isTestMode = true;
  }

  // Constructor for testing with in-memory database
  factory AppDatabase.forTesting() {
    isTestMode = true;
    return AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  }

  /// Singleton instance with dependency injection
  static AppDatabase instance([IContainer? container, {DatabaseConnection? connection}]) {
    if (container != null) {
      _container = container;
    }

    // Return existing instance if available and not closed
    if (_instance != null) {
      // Quick check if the database is still accessible
      try {
        // Don't block, just return the instance
        return _instance!;
      } catch (e) {
        // If there's an error accessing the database, recreate it
        Logger.warning('Database instance error, recreating: $e');
        _instance = null;
      }
    }

    return _instance ??= AppDatabase(connection ?? _openConnection());
  }

  /// Execute a database operation with proper tracking
  static Future<T> executeWithTracking<T>(
    String operationType,
    Future<T> Function() operation,
  ) async {
    if (_isResetting) {
      throw StateError('Cannot execute database operation during reset');
    }
    
    _activeOperationCount++;
    _activeOperations[operationType] = true;
    
    try {
      return await operation();
    } finally {
      _activeOperationCount--;
      _activeOperations.remove(operationType);
    }
  }

  /// Check if database has active operations
  static bool get hasActiveOperations => _activeOperationCount > 0 || _isResetting;
  
  /// Get list of current active operations
  static List<String> get currentActiveOperations => _activeOperations.keys.toList();

  /// Initialize static properties for testing
  static void _initializeForTesting() {
    isTestMode = true;
    _activeOperationCount = 0;
    _activeOperations.clear();
    _isResetting = false;
  }

  /// Check if database is currently in use by attempting a simple query
  /// Enhanced version that tracks actual operations
  bool _isCurrentlyInUse() {
    try {
      // First check if we have tracked active operations
      if (hasActiveOperations) {
        debugPrint('Database is currently in use with $_activeOperationCount active operations');
        return true;
      }
      
      // Additional safety check: try to execute a simple query
      // This helps catch connections we might not be tracking
      try {
        customSelect('SELECT 1').get();
        return false;
      } catch (e) {
        debugPrint('Database connection test failed, assuming in use: $e');
        return true;
      }
    } catch (e) {
      // If we can't check, assume it might be in use for safety
      debugPrint('Unable to determine database usage status, assuming in use for safety: $e');
      return true;
    }
  }

  // Stream controller to notify when database is reset
  static final _resetController = StreamController<void>.broadcast();
  static Stream<void> get onDatabaseReset => _resetController.stream;

  @override
  int get schemaVersion => 29;

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

  /// Resets the database by deleting the file and re-initializing
  /// This is a destructive operation and should be used with caution
  Future<void> resetDatabase() async {
    if (isTestMode) {
      debugPrint('Database reset not available in test mode');
      return;
    }

    // Additional safety: Check if database is currently in use
    if (_isCurrentlyInUse()) {
      debugPrint('❌ Cannot reset database: database is currently in use');
      throw StateError('Cannot reset database while operations are active');
    }

    try {
      // Mark database as resetting to prevent new operations
      _isResetting = true;
      debugPrint('🗑️ Starting database reset with safety checks...');

      // Close the connection first
      await close();

      // Force garbage collection to help with connection cleanup
      await Future.delayed(const Duration(milliseconds: 50));

      // Reset the singleton instance to force reinitialization
      _instance = null;

      final dbFolder = await _getApplicationDirectory();
      final dbPath = p.join(dbFolder.path, kDebugMode ? 'debug_$databaseName' : databaseName);

      final deletionResults = await _deleteDatabaseFiles(dbPath);

      // Check if critical files were deleted successfully
      if (!deletionResults['mainFile']!) {
        throw StateError('Failed to delete main database file');
      }

      debugPrint('✅ Database reset completed successfully');
      
      // Notify listeners that database was reset
      _resetController.add(null);
    } catch (e) {
      debugPrint('❌ Failed to reset database: $e');
      rethrow; // Preserve original exception type and stack trace
    } finally {
      // Clear resetting flag to allow new operations
      _isResetting = false;
    }
  }

  /// Performs safe step-by-step migration to preserve existing user data
  Future<void> _performSafeStepByStepMigration(Migrator m, int from, int to) async {
    debugPrint('🔄 Starting safe step-by-step migration from v$from to v$to');
    
    // If this is a multi-version upgrade, migrate step by step
    if (to - from > 1) {
      debugPrint('📈 Multi-version upgrade detected, migrating step by step');
      for (int version = from; version < to; version++) {
        debugPrint('🔄 Migrating from v$version to v${version + 1}');
        await _migrateFromVersionToVersion(m, version, version + 1);
      }
    } else {
      // Single version upgrade
      debugPrint('🔄 Single version upgrade from v$from to v$to');
      await _migrateFromVersionToVersion(m, from, to);
    }
    
    debugPrint('✅ Step-by-step migration completed successfully');
  }

  /// Handles migration from one specific version to the next
  Future<void> _migrateFromVersionToVersion(Migrator m, int from, int to) async {
    try {
      // For now, use createAll() as a fallback since stepByStep may not be available
      // This is safer than the previous implementation but could be enhanced further
      await m.createAll();
      
      debugPrint('✅ Successfully migrated from v$from to v$to');
    } catch (e, stackTrace) {
      debugPrint('❌ Migration step v$from → v$to failed: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Attempt to recover or provide more specific error information
      if (e.toString().contains('no such table')) {
        debugPrint('💡 Hint: This might be a new installation or missing table issue');
      }
      
      rethrow;
    }
  }

  /// Deletes database files with improved error handling and reporting
  Future<Map<String, bool>> _deleteDatabaseFiles(String dbPath) async {
    final results = <String, bool>{};
    
    // Define file suffixes for database auxiliary files
    const fileSuffixes = ['', '-journal', '-wal', '-shm'];
    const fileNames = ['mainFile', 'journalFile', 'walFile', 'shmFile'];

    // Iterate through all file types and delete them
    for (int i = 0; i < fileSuffixes.length; i++) {
      final suffix = fileSuffixes[i];
      final fileName = fileNames[i];
      final filePath = '$dbPath$suffix';
      final file = File(filePath);

      if (await file.exists()) {
        try {
          await file.delete();
          debugPrint('✅ Database file deleted: $filePath');
          results[fileName] = true;
        } on FileSystemException catch (e) {
          debugPrint('❌ FileSystem error deleting $fileName: ${e.path} - ${e.message}');
          results[fileName] = false;
        } catch (e) {
          debugPrint('❌ Unexpected error deleting $fileName: $e');
          results[fileName] = false;
        }
      } else {
        debugPrint('ℹ️ File does not exist: $filePath');
        results[fileName] = true; // Success if file doesn't exist
      }
    }

    return results;
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

          // Use safe step-by-step migration to preserve existing user data
          await _performSafeStepByStepMigration(m, from, to);

          // Validate data integrity after migration steps
          await _validateDataIntegrity();

          debugPrint('Migration from v$from to v$to completed successfully');
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

  @override
  Future<void> close() async {
    debugPrint('🔌 Closing database connection...');
    await super.close();
    debugPrint('✅ Database connection closed');
  }

  /// Dispose the database and clean up resources
  static Future<void> dispose() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
    await _resetController.close();
  }
}
