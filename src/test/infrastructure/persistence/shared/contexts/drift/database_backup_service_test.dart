import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/database_backup_service.dart';

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

    await service.createBackupBeforeMigration(35, 36);

    expect(await tempDir.list().toList(), isEmpty);
  });

  test('creates a verified backup copy when a database file exists', () async {
    final dbFile = File('${tempDir.path}/$dbFileName');
    await dbFile.writeAsBytes(List.generate(256, (i) => i % 256));

    final service = DatabaseBackupService(
      getApplicationDirectory: () async => tempDir,
      databaseName: 'app.db',
    );

    await service.createBackupBeforeMigration(35, 36);

    final backups = await tempDir.list().where((entity) => entity.path.contains('backup_v35_to_v36')).toList();
    expect(backups, hasLength(1));
    expect(await File(backups.single.path).length(), await dbFile.length());
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
      () => service.createBackupBeforeMigration(35, 36),
      throwsA(isA<StateError>()),
      reason: 'a backup failure must abort the migration, not be logged and silently ignored',
    );
  }, testOn: 'linux || mac-os');
}
