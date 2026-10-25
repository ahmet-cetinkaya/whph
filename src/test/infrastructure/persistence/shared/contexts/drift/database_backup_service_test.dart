import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/database_backup_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import 'wal_test_support.dart';

void main() {
  late Directory tempDir;
  // The service looks up 'debug_<name>' under kDebugMode (true for `flutter
  // test`), matching its production _dbFileName getter.
  final dbFileName = kDebugMode ? 'debug_app.db' : 'app.db';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_service_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('does nothing when there is no existing database file to protect', () async {
    final service = DatabaseBackupService(
      getApplicationDirectory: () async => tempDir,
      databaseName: 'app.db',
    );

    await service.createBackupBeforeMigration(
      35,
      36,
      writeSnapshot: (_) async => fail('no snapshot should be written without a database file'),
    );

    expect(await tempDir.list().toList(), isEmpty);
  });

  test('creates a verified backup snapshot when a database file exists', () async {
    final dbFile = File('${tempDir.path}/$dbFileName');
    final database = AppDatabase.withExecutor(NativeDatabase(dbFile));
    addTearDown(() async {
      await database.close();
      AppDatabase.resetInstance();
    });
    await database.customStatement('CREATE TABLE backup_probe (value INTEGER NOT NULL)');
    await database.customStatement('INSERT INTO backup_probe VALUES (42)');

    final service = DatabaseBackupService(
      getApplicationDirectory: () async => tempDir,
      databaseName: 'app.db',
    );

    await service.createBackupBeforeMigration(
      35,
      36,
      writeSnapshot: (path) => database.customStatement(vacuumIntoStatement(path)),
    );

    final backups = await tempDir.list().where((entity) => entity.path.contains('backup_v35_to_v36')).toList();
    expect(backups, hasLength(1));
    final rows = await queryStandalone(File(backups.single.path), 'SELECT value FROM backup_probe');
    expect(rows.single['value'], 42);
  });

  test('throws instead of silently continuing when the backup copy fails', () async {
    final dbFile = File('${tempDir.path}/$dbFileName');
    await dbFile.writeAsBytes([1, 2, 3]);

    // Making the directory read-only makes every write inside it —
    // including the backup copy — fail with a real, portable
    // FileSystemException, without relying on a specific error message.
    final chmodResult = await Process.run('chmod', ['555', tempDir.path]);
    expect(chmodResult.exitCode, 0, reason: 'test setup: chmod must succeed to make this a valid regression check');
    addTearDown(() => Process.run('chmod', ['755', tempDir.path]));

    final service = DatabaseBackupService(
      getApplicationDirectory: () async => tempDir,
      databaseName: 'app.db',
    );

    await expectLater(
      () => service.createBackupBeforeMigration(
        35,
        36,
        writeSnapshot: (path) => File(path).writeAsBytes([1, 2, 3]),
      ),
      throwsA(isA<StateError>()),
      reason: 'a backup failure must abort the migration, not be logged and silently ignored',
    );
  }, testOn: 'linux || mac-os');
}
