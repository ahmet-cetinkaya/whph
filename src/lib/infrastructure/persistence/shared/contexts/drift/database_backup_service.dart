import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Writes a consistent snapshot of the open database to a destination path,
/// typically with `VACUUM INTO` on the live connection.
typedef SnapshotWriter = Future<void> Function(String destinationPath);

/// Service for managing database backup and restore operations.
///
/// Backups are written through a [SnapshotWriter] (`VACUUM INTO`) instead of
/// copying the database file, because in WAL mode recent commits may still
/// live only in the `-wal` sidecar.
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

  /// Deletes the WAL and shared-memory sidecars of [dbFile]. Stale sidecars
  /// left next to a file that is replaced or removed would otherwise be
  /// replayed onto (or confuse) the next database at that path.
  Future<void> _deleteSidecarFiles(File dbFile) async {
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('${dbFile.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
  }

  /// Creates a backup of the database before migration.
  ///
  /// A migration rewrites user data in place with no other recovery path, so
  /// a failure to create this backup must abort the migration rather than be
  /// logged and ignored — proceeding without a recovery copy would leave the
  /// user with no way back if the migration itself turns out to be wrong.
  ///
  /// [writeSnapshot] must write from the open connection outside any
  /// transaction; the snapshot keeps `user_version = from`.
  Future<void> createBackupBeforeMigration(
    int from,
    int to, {
    required SnapshotWriter writeSnapshot,
  }) async {
    if (_isTestMode) return;

    final dbFolder = await _getApplicationDirectory();
    final dbFile = File(p.join(dbFolder.path, _dbFileName));

    if (!await dbFile.exists()) {
      // Nothing to protect: a fresh install has no prior data to lose.
      return;
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final backupFile = File(p.join(
      dbFolder.path,
      'backup_v${from}_to_v${to}_$timestamp.db',
    ));

    try {
      await createConsistentSnapshot(writeSnapshot: writeSnapshot, destination: backupFile);
    } catch (e, stackTrace) {
      throw StateError('Failed to create pre-migration backup (v$from to v$to): $e\n$stackTrace');
    }

    Logger.info('Database backup created: ${backupFile.path}');
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
      Logger.error('Error listing backups: $e');
      return [];
    }
  }

  /// Attempts to restore from a backup file
  Future<bool> restoreFromBackup({
    File? specificBackup,
    required Future<void> Function() closeDatabase,
  }) async {
    if (_isTestMode) {
      Logger.warning('Backup restoration not available in test mode');
      return false;
    }

    try {
      final dbFolder = await _getApplicationDirectory();
      final currentDbFile = File(p.join(dbFolder.path, _dbFileName));

      final backupFile = specificBackup ?? (await listAvailableBackups()).firstOrNull;

      if (backupFile == null) {
        Logger.warning('No backup files found');
        return false;
      }

      Logger.info('Restoring database from backup: ${backupFile.path}');

      await closeDatabase();

      if (await currentDbFile.exists()) {
        await currentDbFile.delete();
      }
      await _deleteSidecarFiles(currentDbFile);

      await backupFile.copy(currentDbFile.path);

      Logger.info('Database restored successfully from backup');
      return true;
    } catch (e) {
      Logger.error('CRITICAL: Failed to restore from backup: $e');
      return false;
    }
  }

  /// Creates a manual database backup
  Future<File?> createDatabaseBackup({required SnapshotWriter writeSnapshot}) async {
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

        await createConsistentSnapshot(writeSnapshot: writeSnapshot, destination: backupFile);
        Logger.info('Manual database backup created: ${backupFile.path}');
        return backupFile;
      }

      return null;
    } catch (e) {
      Logger.error('Failed to create manual database backup: $e');
      return null;
    }
  }

  /// Writes a verified SQLite snapshot through [writeSnapshot].
  ///
  /// Without [destination], the snapshot goes to `backups/restore/`. An
  /// explicit [destination] must not exist yet (`VACUUM INTO` refuses a
  /// non-empty target, and a failed attempt must not delete an unrelated file).
  Future<File> createConsistentSnapshot({
    required SnapshotWriter writeSnapshot,
    File? destination,
  }) async {
    final File snapshot;
    if (destination != null) {
      if (await destination.exists()) {
        throw StateError('Snapshot destination already exists: ${destination.path}');
      }
      await destination.parent.create(recursive: true);
      snapshot = destination;
    } else {
      final applicationDirectory = await _getApplicationDirectory();
      final snapshotDirectory = Directory(
        p.join(applicationDirectory.path, 'backups', 'restore'),
      );
      await snapshotDirectory.create(recursive: true);

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      snapshot = File(
        p.join(snapshotDirectory.path, 'restore_$timestamp.db'),
      );
    }
    try {
      await writeSnapshot(snapshot.path);
      await _verifySqliteSnapshot(snapshot);
      return snapshot;
    } catch (_) {
      if (await snapshot.exists()) await snapshot.delete();
      rethrow;
    }
  }

  Future<void> _verifySqliteSnapshot(File snapshot) async {
    if (!await snapshot.exists() || await snapshot.length() < 16) {
      throw StateError('Consistent database snapshot was not created');
    }
    final handle = await snapshot.open();
    try {
      final header = String.fromCharCodes(await handle.read(16));
      if (header != 'SQLite format 3\u0000') {
        throw StateError('Consistent database snapshot is not SQLite');
      }
    } finally {
      await handle.close();
    }
  }

  /// Resets the database by closing and deleting the database file
  /// together with its `-wal`/`-shm` sidecars.
  Future<void> resetDatabase({
    required SnapshotWriter writeSnapshot,
    required Future<void> Function() closeDatabase,
    required void Function() resetInstance,
  }) async {
    final backupFile = await createPreResetBackup(writeSnapshot: writeSnapshot);

    await closeDatabase();
    resetInstance();

    try {
      final dbFolder = await _getApplicationDirectory();
      final dbFile = File(p.join(dbFolder.path, _dbFileName));

      if (await dbFile.exists()) {
        await dbFile.delete();
        await _deleteSidecarFiles(dbFile);
        Logger.info('Database deleted successfully');

        if (backupFile != null) {
          Logger.info('Pre-reset backup created: ${backupFile.path}');
        }
      } else {
        await _deleteSidecarFiles(dbFile);
        Logger.info('Database file does not exist - treating as fresh reset');
      }
    } catch (e) {
      Logger.error('Error deleting database: $e');

      if (backupFile != null && await backupFile.exists()) {
        try {
          final dbFolder = await _getApplicationDirectory();
          final dbFile = File(p.join(dbFolder.path, _dbFileName));
          await _deleteSidecarFiles(dbFile);
          await backupFile.copy(dbFile.path);
          Logger.info('Database restored from pre-reset backup due to deletion failure');
        } catch (restoreError) {
          Logger.error('Failed to restore database from backup: $restoreError');
        }
      }

      rethrow;
    }
  }

  /// Creates an automatic backup before database reset
  Future<File?> createPreResetBackup({required SnapshotWriter writeSnapshot}) async {
    try {
      final dbFolder = await _getApplicationDirectory();
      final dbFile = File(p.join(dbFolder.path, _dbFileName));

      if (!await dbFile.exists()) {
        Logger.info('No database file exists - no backup needed for fresh reset');
        return null;
      }

      final backupFolder = Directory(p.join(dbFolder.path, 'backups', 'pre_reset'));
      if (!await backupFolder.exists()) {
        await backupFolder.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupFileName = 'pre_reset_${timestamp}_$_databaseName';
      final backupFile = File(p.join(backupFolder.path, backupFileName));

      await createConsistentSnapshot(writeSnapshot: writeSnapshot, destination: backupFile);

      await _cleanupOldPreResetBackups(backupFolder);

      Logger.info('Pre-reset backup created: ${backupFile.path}');
      return backupFile;
    } catch (e) {
      Logger.warning('Failed to create pre-reset backup: $e');
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
            Logger.info('Deleted old pre-reset backup: ${file.path}');
          }
        }
      }
    } catch (e) {
      Logger.warning('Failed to cleanup old pre-reset backups: $e');
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
      Logger.error('Error listing pre-reset backups: $e');
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

      await _deleteSidecarFiles(dbFile);
      await backupFile.copy(dbFile.path);

      Logger.info('Database restored from pre-reset backup: ${backupFile.path}');
      return true;
    } catch (e) {
      Logger.error('Failed to restore from pre-reset backup: $e');
      return false;
    }
  }
}
