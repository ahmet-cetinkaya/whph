import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/infrastructure/persistence/shared/contexts/drift/database_backup_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sqlite_connection_setup.dart';

import 'wal_test_support.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temporaryDirectory;
  late File dbFile;
  late DatabaseBackupService service;
  late AppDatabase database;
  // The service resolves 'debug_<name>' under kDebugMode (true for tests).
  final dbFileName = kDebugMode ? 'debug_app.db' : 'app.db';

  Future<void> insertProbe(String value) => database.customStatement('INSERT INTO backup_probe VALUES (?)', [value]);

  Future<List<Object?>> probeValues(File file) async =>
      (await queryStandalone(file, 'SELECT value FROM backup_probe ORDER BY rowid'))
          .map((row) => row['value'])
          .toList();

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('whph_vacuum_into_backup_');
    dbFile = File(p.join(temporaryDirectory.path, dbFileName));
    service = DatabaseBackupService(
      getApplicationDirectory: () async => temporaryDirectory,
      databaseName: 'app.db',
    );
    AppDatabase.backupServiceForTesting = service;
    database = AppDatabase.withExecutor(openWalHoldingDatabase(dbFile));

    // One checkpointed row, then one row that only exists in the WAL.
    await database.customStatement('CREATE TABLE backup_probe (value TEXT NOT NULL)');
    await insertProbe('checkpointed');
    await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await insertProbe('wal-only');
    expect(await walFileOf(dbFile).length(), greaterThan(0));
  });

  tearDown(() async {
    await database.close();
    AppDatabase.resetInstance();
    if (await temporaryDirectory.exists()) await temporaryDirectory.delete(recursive: true);
  });

  Future<void> expectCompleteBackup(File backup) async {
    expect(await backup.exists(), isTrue);
    expect(await integrityCheckOf(backup), 'ok');
    expect(await probeValues(backup), ['checkpointed', 'wal-only']);
  }

  test('the WAL-only row is really missing from the main database file', () async {
    final plainCopy = await dbFile.copy(p.join(temporaryDirectory.path, 'plain_copy.sqlite'));
    expect(await probeValues(plainCopy), ['checkpointed']);
  });

  group('backups use VACUUM INTO and include WAL content', () {
    test('pre-migration backup', () async {
      await service.createBackupBeforeMigration(
        36,
        37,
        writeSnapshot: (path) => database.customStatement(vacuumIntoStatement(path)),
      );

      final backups = temporaryDirectory
          .listSync()
          .whereType<File>()
          .where((file) => p.basename(file.path).startsWith('backup_v36_to_v37_'))
          .toList();
      expect(backups, hasLength(1));
      await expectCompleteBackup(backups.single);
    });

    test('manual backup (AppDatabase.createDatabaseBackup)', () async {
      final backup = await database.createDatabaseBackup();

      expect(backup, isNotNull);
      expect(p.basename(backup!.path), startsWith('import_backup_'));
      await expectCompleteBackup(backup);
    });

    test('pre-reset backup', () async {
      final backup = await service.createPreResetBackup(
        writeSnapshot: (path) => database.customStatement(vacuumIntoStatement(path)),
      );

      expect(backup, isNotNull);
      expect(p.split(backup!.path), containsAllInOrder(['backups', 'pre_reset']));
      await expectCompleteBackup(backup);
    });
  });

  group('restore and reset remove stale -wal/-shm', () {
    late Uint8List staleWal;
    late Uint8List staleShm;

    /// Captures the live sidecars after a post-backup write, and returns a
    /// close callback that leaves them behind as crash residue would.
    Future<Future<void> Function()> closeLeavingStaleSidecars() async {
      await insertProbe('after-backup');
      staleWal = await walFileOf(dbFile).readAsBytes();
      staleShm = await shmFileOf(dbFile).readAsBytes();
      expect(staleWal, isNotEmpty);
      return () async {
        await database.close();
        await walFileOf(dbFile).writeAsBytes(staleWal);
        await shmFileOf(dbFile).writeAsBytes(staleShm);
      };
    }

    Future<void> expectRestoredContent() async {
      expect(await walFileOf(dbFile).exists(), isFalse);
      expect(await shmFileOf(dbFile).exists(), isFalse);
      final reopened = AppDatabase.withExecutor(NativeDatabase(dbFile, setup: configureSqliteConnection));
      addTearDown(reopened.close);
      final rows = await reopened.customSelect('SELECT value FROM backup_probe ORDER BY rowid').get();
      expect(rows.map((row) => row.read<String>('value')), ['checkpointed', 'wal-only']);
    }

    test('restoreFromBackup', () async {
      final backup = (await database.createDatabaseBackup())!;
      final close = await closeLeavingStaleSidecars();

      final restored = await service.restoreFromBackup(specificBackup: backup, closeDatabase: close);

      expect(restored, isTrue);
      await expectRestoredContent();
    });

    test('restoreFromPreResetBackup', () async {
      final backup = (await service.createPreResetBackup(
        writeSnapshot: (path) => database.customStatement(vacuumIntoStatement(path)),
      ))!;
      final close = await closeLeavingStaleSidecars();

      final restored = await service.restoreFromPreResetBackup(
        backupFile: backup,
        closeDatabase: close,
        resetInstance: () {},
      );

      expect(restored, isTrue);
      await expectRestoredContent();
    });

    test('resetDatabase deletes the database file with its sidecars', () async {
      final close = await closeLeavingStaleSidecars();

      await service.resetDatabase(
        writeSnapshot: (path) => database.customStatement(vacuumIntoStatement(path)),
        closeDatabase: close,
        resetInstance: () {},
      );

      expect(await dbFile.exists(), isFalse);
      expect(await walFileOf(dbFile).exists(), isFalse);
      expect(await shmFileOf(dbFile).exists(), isFalse);
      final preResetBackups = await service.listPreResetBackups();
      expect(preResetBackups, hasLength(1));
      expect(await probeValues(preResetBackups.single), ['checkpointed', 'wal-only', 'after-backup']);
    });

    test('AppDatabase.resetDatabase backs up through VACUUM INTO and removes the files', () async {
      await database.resetDatabase();

      expect(await dbFile.exists(), isFalse);
      expect(await walFileOf(dbFile).exists(), isFalse);
      expect(await shmFileOf(dbFile).exists(), isFalse);
      final preResetBackups = await service.listPreResetBackups();
      expect(preResetBackups, hasLength(1));
      await expectCompleteBackup(preResetBackups.single);
    });
  });
}
