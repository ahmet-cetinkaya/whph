import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Service for managing database backup and restore operations
class DatabaseBackupService {
  final Future<Directory> Function() _getApplicationDirectory;
  final String _databaseName;
  final bool _isTestMode;

  DatabaseBackupService({
    required Future<Directory> Function() getApplicationDirectory,
    required String databaseName,
    bool isTestMode = false,
  })  : _getApplicationDirectory = getApplicationDirectory,
        _databaseName = databaseName,
        _isTestMode = isTestMode;

  String get _dbFileName => kDebugMode ? 'debug_$_databaseName' : _databaseName;

  /// Creates a backup of the database before migration
  Future<void> createBackupBeforeMigration(int from, int to) async {
    if (_isTestMode) return;

    try {
      final dbFolder = await _getApplicationDirectory();
      final dbFile = File(p.join(dbFolder.path, _dbFileName));

      if (await dbFile.exists()) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
        final backupFile = File(p.join(
          dbFolder.path,
          'backup_v${from}_to_v${to}_$timestamp.db',
        ));

        await dbFile.copy(backupFile.path);
        DomainLogger.info('Database backup created: ${backupFile.path}');
      }
    } catch (e) {
      DomainLogger.warning('Failed to create database backup: $e');
    }
  }

  /// Lists available database backups for recovery
  Future<List<File>> listAvailableBackups() async {
    if (_isTestMode) return [];

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

      backupFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return backupFiles;
    } catch (e) {
      DomainLogger.error('Error listing backups: $e');
      return [];
    }
  }

  /// Attempts to restore from a backup file
  Future<bool> restoreFromBackup({
    File? specificBackup,
    required Future<void> Function() closeDatabase,
  }) async {
    if (_isTestMode) {
      DomainLogger.warning('Backup restoration not available in test mode');
      return false;
    }

    try {
      final dbFolder = await _getApplicationDirectory();
      final currentDbFile = File(p.join(dbFolder.path, _dbFileName));

      final backupFile = specificBackup ?? (await listAvailableBackups()).firstOrNull;

      if (backupFile == null) {
        DomainLogger.warning('No backup files found');
        return false;
      }

      DomainLogger.info('Restoring database from backup: ${backupFile.path}');

      await closeDatabase();

      if (await currentDbFile.exists()) {
        await currentDbFile.delete();
      }

      await backupFile.copy(currentDbFile.path);

      DomainLogger.info('Database restored successfully from backup');
      return true;
    } catch (e) {
      DomainLogger.error('CRITICAL: Failed to restore from backup: $e');
      return false;
    }
  }

  /// Creates a manual database backup
  Future<File?> createDatabaseBackup() async {
    if (_isTestMode) return null;

    try {
      final dbFolder = await _getApplicationDirectory();
      final dbFile = File(p.join(dbFolder.path, _dbFileName));

      if (await dbFile.exists()) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
        final backupFile = File(p.join(
          dbFolder.path,
          'import_backup_$timestamp.db',
        ));

        await dbFile.copy(backupFile.path);
        DomainLogger.info('Manual database backup created: ${backupFile.path}');
        return backupFile;
      }

      return null;
    } catch (e) {
      DomainLogger.error('Failed to create manual database backup: $e');
      return null;
    }
  }

  /// Resets the database by closing and deleting the database file
  Future<void> resetDatabase({
    required Future<void> Function() closeDatabase,
    required void Function() resetInstance,
  }) async {
    final backupFile = await createPreResetBackup();

    await closeDatabase();
    resetInstance();

    try {
      final dbFolder = await _getApplicationDirectory();
      final dbFile = File(p.join(dbFolder.path, _dbFileName));

      if (await dbFile.exists()) {
        await dbFile.delete();
        DomainLogger.info('Database deleted successfully');

        if (backupFile != null) {
          DomainLogger.info('Pre-reset backup created: ${backupFile.path}');
        }
      } else {
        DomainLogger.info('Database file does not exist - treating as fresh reset');
      }
    } catch (e) {
      DomainLogger.error('Error deleting database: $e');

      if (backupFile != null && await backupFile.exists()) {
        try {
          final dbFolder = await _getApplicationDirectory();
          final dbFile = File(p.join(dbFolder.path, _dbFileName));
          await backupFile.copy(dbFile.path);
          DomainLogger.info('Database restored from pre-reset backup due to deletion failure');
        } catch (restoreError) {
          DomainLogger.error('Failed to restore database from backup: $restoreError');
        }
      }

      rethrow;
    }
  }

  /// Creates an automatic backup before database reset
  Future<File?> createPreResetBackup() async {
    try {
      final dbFolder = await _getApplicationDirectory();
      final dbFile = File(p.join(dbFolder.path, _dbFileName));

      if (!await dbFile.exists()) {
        DomainLogger.info('No database file exists - no backup needed for fresh reset');
        return null;
      }

      final backupFolder = Directory(p.join(dbFolder.path, 'backups', 'pre_reset'));
      if (!await backupFolder.exists()) {
        await backupFolder.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupFileName = 'pre_reset_${timestamp}_$_databaseName';
      final backupFile = File(p.join(backupFolder.path, backupFileName));

      await dbFile.copy(backupFile.path);

      await _cleanupOldPreResetBackups(backupFolder);

      DomainLogger.info('Pre-reset backup created: ${backupFile.path}');
      return backupFile;
    } catch (e) {
      DomainLogger.warning('Failed to create pre-reset backup: $e');
      return null;
    }
  }

  /// Cleans up old pre-reset backups older than 7 days
  Future<void> _cleanupOldPreResetBackups(Directory backupFolder) async {
    try {
      final files = await backupFolder.list().toList();
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

      for (final file in files) {
        if (file is File && file.path.contains('pre_reset_')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            DomainLogger.info('Deleted old pre-reset backup: ${file.path}');
          }
        }
      }
    } catch (e) {
      DomainLogger.warning('Failed to cleanup old pre-reset backups: $e');
    }
  }

  /// Lists available pre-reset backups for recovery
  Future<List<File>> listPreResetBackups() async {
    try {
      final dbFolder = await _getApplicationDirectory();
      final backupFolder = Directory(p.join(dbFolder.path, 'backups', 'pre_reset'));

      if (!await backupFolder.exists()) {
        return [];
      }

      final files = await backupFolder.list().toList();
      final backupFiles = <File>[];

      for (final file in files) {
        if (file is File && file.path.contains('pre_reset_')) {
          backupFiles.add(file);
        }
      }

      backupFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      return backupFiles;
    } catch (e) {
      DomainLogger.error('Error listing pre-reset backups: $e');
      return [];
    }
  }

  /// Restores database from a pre-reset backup file
  Future<bool> restoreFromPreResetBackup({
    required File backupFile,
    required Future<void> Function() closeDatabase,
    required void Function() resetInstance,
  }) async {
    try {
      await closeDatabase();
      resetInstance();

      final dbFolder = await _getApplicationDirectory();
      final dbFile = File(p.join(dbFolder.path, _dbFileName));

      await backupFile.copy(dbFile.path);

      DomainLogger.info('Database restored from pre-reset backup: ${backupFile.path}');
      return true;
    } catch (e) {
      DomainLogger.error('Failed to restore from pre-reset backup: $e');
      return false;
    }
  }
}
