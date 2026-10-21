import 'dart:io';

import 'package:drift/backends.dart';
import 'package:drift/drift.dart' show OpeningDetails;
import 'package:drift/native.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sqlite_connection_setup.dart';

/// Production connection setup plus `wal_autocheckpoint=0`, so committed
/// writes stay in the `-wal` file until a test checkpoints explicitly.
void configureWalHoldingConnection(dynamic database) {
  configureSqliteConnection(database);
  database.execute('PRAGMA wal_autocheckpoint = 0');
}

/// A file-backed connection that keeps committed writes in the WAL.
NativeDatabase openWalHoldingDatabase(File file) => NativeDatabase(file, setup: configureWalHoldingConnection);

String vacuumIntoStatement(String destinationPath) => "VACUUM INTO '${destinationPath.replaceAll("'", "''")}'";

File walFileOf(File dbFile) => File('${dbFile.path}-wal');
File shmFileOf(File dbFile) => File('${dbFile.path}-shm');

class _RawUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

/// Runs [sql] against [file] on a standalone connection with no drift
/// migrations (so `user_version` and the schema are left untouched).
Future<List<Map<String, Object?>>> queryStandalone(File file, String sql) async {
  final executor = NativeDatabase(file, enableMigrations: false);
  try {
    await executor.ensureOpen(_RawUser());
    return await executor.runSelect(sql, const []);
  } finally {
    await executor.close();
  }
}

Future<int> userVersionOf(File file) async =>
    (await queryStandalone(file, 'PRAGMA user_version')).single.values.single as int;

Future<String> integrityCheckOf(File file) async =>
    (await queryStandalone(file, 'PRAGMA integrity_check')).single.values.single as String;
