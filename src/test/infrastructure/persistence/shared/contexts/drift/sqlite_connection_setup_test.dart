import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

/// Opens the database through the production opener (`AppDatabase()` ->
/// `_openConnection` -> `NativeDatabase.createInBackground`) and reads the
/// connection pragmas.
Future<(String, int)> _readPragmasThroughProductionOpener(String directoryPath) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  AppDatabase.isTestMode = true;
  AppDatabase.testDirectory = Directory(directoryPath);
  final database = AppDatabase();
  try {
    final journalMode = await database.customSelect('PRAGMA journal_mode').getSingle();
    final busyTimeout = await database.customSelect('PRAGMA busy_timeout').getSingle();
    return (journalMode.data.values.single as String, busyTimeout.data.values.single as int);
  } finally {
    await database.close();
  }
}

Future<(String, int)> _readPragmasInAnotherIsolate(String directoryPath) =>
    Isolate.run(() => _readPragmasThroughProductionOpener(directoryPath));

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('whph_connection_setup_');
  });

  tearDown(() async {
    AppDatabase.resetInstance();
    if (await temporaryDirectory.exists()) await temporaryDirectory.delete(recursive: true);
  });

  test('production opener enables WAL and a 5 s busy timeout on every connection, in any isolate', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    AppDatabase.isTestMode = true;
    AppDatabase.testDirectory = temporaryDirectory;
    final mainDatabase = AppDatabase();
    addTearDown(mainDatabase.close);

    final mainJournalMode = await mainDatabase.customSelect('PRAGMA journal_mode').getSingle();
    final mainBusyTimeout = await mainDatabase.customSelect('PRAGMA busy_timeout').getSingle();
    expect(mainJournalMode.data.values.single, 'wal');
    expect(mainBusyTimeout.data.values.single, 5000);
    expect(File(p.join(temporaryDirectory.path, databaseName)).existsSync(), isTrue);

    // A second connection to the same file, opened through the same opener
    // from another isolate (as the widget background isolate does).
    final (otherJournalMode, otherBusyTimeout) = await _readPragmasInAnotherIsolate(temporaryDirectory.path);
    expect(otherJournalMode, 'wal');
    expect(otherBusyTimeout, 5000);

    // The main connection is still usable alongside the other isolate's.
    await mainDatabase.customStatement('CREATE TABLE IF NOT EXISTS setup_probe (value INTEGER)');
  });
}
