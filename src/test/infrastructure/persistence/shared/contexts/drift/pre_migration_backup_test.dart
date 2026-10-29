import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/infrastructure/persistence/shared/contexts/drift/database_backup_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sqlite_connection_setup.dart';

import '../../../../../drift/app_database/generated/schema.dart';
import 'wal_test_support.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temporaryDirectory;
  late File dbFile;
  // The service resolves 'debug_<name>' under kDebugMode (true for tests).
  final dbFileName = kDebugMode ? 'debug_app.db' : 'app.db';

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('whph_pre_migration_backup_');
    dbFile = File(p.join(temporaryDirectory.path, dbFileName));
    AppDatabase.backupServiceForTesting = DatabaseBackupService(
      getApplicationDirectory: () async => temporaryDirectory,
      databaseName: 'app.db',
    );
  });

  tearDown(() async {
    AppDatabase.resetInstance();
    if (await temporaryDirectory.exists()) await temporaryDirectory.delete(recursive: true);
  });

  List<File> preMigrationBackups() => temporaryDirectory
      .listSync()
      .whereType<File>()
      .where((file) => p.basename(file.path).startsWith('backup_v'))
      .toList();

  /// Opens the file like production does: a background isolate connection
  /// configured by [configureSqliteConnection].
  AppDatabase openLikeProduction() =>
      AppDatabase.withExecutor(NativeDatabase.createInBackground(dbFile, setup: configureSqliteConnection));

  test('v36 -> v37 upgrade backs up with VACUUM INTO inside onUpgrade (primary path), including WAL content', () async {
    // Given a v36 database whose latest write is still only in the WAL.
    final v36 = GeneratedHelper().databaseForVersion(openWalHoldingDatabase(dbFile), 36);
    await v36.customStatement(
      'INSERT INTO habit_table (id, created_date, name, description) VALUES (?, ?, ?, ?)',
      ['checkpointed-habit', 1000, 'Checkpointed', ''],
    );
    await v36.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await v36.customStatement(
      'INSERT INTO habit_table (id, created_date, name, description) VALUES (?, ?, ?, ?)',
      ['wal-habit', 2000, 'Only in WAL', ''],
    );
    expect(await walFileOf(dbFile).length(), greaterThan(0));
    // A plain file copy (the old backup method) would lose the WAL-only row.
    final plainCopy = await dbFile.copy(p.join(temporaryDirectory.path, 'plain_copy.sqlite'));
    expect(
      (await queryStandalone(plainCopy, 'SELECT id FROM habit_table')).map((row) => row['id']),
      ['checkpointed-habit'],
    );
    await plainCopy.delete();

    // When the app opens it through the production-style opener. The v36
    // connection stays open, so the row is still WAL-resident at upgrade time.
    final upgraded = openLikeProduction();
    addTearDown(upgraded.close);
    final migratedType = await upgraded
        .customSelect("SELECT type FROM habit_table WHERE id = 'wal-habit'")
        .getSingle(); // opening runs onUpgrade 36 -> 38
    await v36.close();

    // Then onUpgrade ran VACUUM INTO on the open connection without error
    // (VACUUM fails inside a transaction, see the control test below), so
    // Drift does not wrap onUpgrade in a transaction: the primary path ships.
    expect(migratedType.read<int>('type'), 0);
    final backups = preMigrationBackups();
    expect(backups, hasLength(1), reason: 'exactly one backup per upgrade');
    expect(p.basename(backups.single.path), startsWith('backup_v36_to_v38_'));
    expect(await userVersionOf(backups.single), 36);
    expect(await integrityCheckOf(backups.single), 'ok');
    expect(
      (await queryStandalone(backups.single, 'SELECT id FROM habit_table ORDER BY created_date')).map((r) => r['id']),
      ['checkpointed-habit', 'wal-habit'],
    );
    expect(await userVersionOf(dbFile), 38);
  });

  test('control: VACUUM INTO inside a transaction fails, so a successful onUpgrade backup proves no transaction',
      () async {
    final database = openLikeProduction();
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    Object? error;
    try {
      await database.transaction(() async {
        await database.customStatement(vacuumIntoStatement(p.join(temporaryDirectory.path, 'in_tx.db')));
      });
    } catch (e) {
      error = e;
    }

    expect(error, isNotNull);
    expect(error.toString(), contains('cannot VACUUM from within a transaction'));
  });

  test('opening a fresh database creates no pre-migration backup', () async {
    final database = openLikeProduction();
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    expect(await userVersionOf(dbFile), 38);
    expect(preMigrationBackups(), isEmpty);
  });
}
