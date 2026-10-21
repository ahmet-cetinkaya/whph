import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

int _nowMicros() => DateTime.now().microsecondsSinceEpoch;

typedef _ConnectionBResult = ({
  List<String> rowsSeenDuringA,
  int readAtMicros,
  List<int> commitTimesMicros,
  List<String> errors,
});

/// Connection B: a separate isolate opening the database through the
/// production opener, standing in for the widget background isolate.
Future<_ConnectionBResult> _runConnectionB(String directoryPath) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  AppDatabase.isTestMode = true;
  AppDatabase.testDirectory = Directory(directoryPath);
  final database = AppDatabase();
  final errors = <String>[];
  final commitTimes = <int>[];
  try {
    final rows = await database.customSelect('SELECT source FROM wal_probe ORDER BY id').get();
    final readAt = _nowMicros();
    for (var i = 0; i < 20; i++) {
      try {
        await database.customStatement('INSERT INTO wal_probe (source) VALUES (?)', ['b-$i']);
        commitTimes.add(_nowMicros());
      } catch (e) {
        errors.add(e.toString());
      }
    }
    return (
      rowsSeenDuringA: rows.map((row) => row.read<String>('source')).toList(),
      readAtMicros: readAt,
      commitTimesMicros: commitTimes,
      errors: errors,
    );
  } finally {
    await database.close();
  }
}

/// Spawns connection B; kept top-level so the isolate closure captures only
/// the directory path.
Future<_ConnectionBResult> _spawnConnectionB(String directoryPath) => Isolate.run(() => _runConnectionB(directoryPath));

/// Blocked under `flutter test`: the Flutter tester always runs with Dart
/// profiling on, and the profiler's SIGPROF interrupts the `nanosleep` inside
/// SQLite's default busy handler. SQLite counts nominal sleep time, so
/// `busy_timeout = 5000` gives up after ~60 ms of real time and every write
/// fails with "database is locked". The same scenario waits correctly (~2 s,
/// no error) in a VM without the profiler (release builds compile it out).
/// Unskip once busy waiting no longer depends on uninterrupted sleeps.
const _profilerBlocksBusyTimeout =
    'Dart profiler (always on in flutter test) cuts SQLite busy_timeout to ~60 ms; see comment above main().';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('whph_wal_concurrency_');
  });

  tearDown(() async {
    AppDatabase.resetInstance();
    if (await temporaryDirectory.exists()) await temporaryDirectory.delete(recursive: true);
  });

  test('writes from another isolate wait out a 2 s write transaction instead of failing as locked', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    AppDatabase.isTestMode = true;
    AppDatabase.testDirectory = temporaryDirectory;
    final connectionA = AppDatabase();
    addTearDown(connectionA.close);
    await connectionA.customStatement(
      'CREATE TABLE wal_probe (id INTEGER PRIMARY KEY AUTOINCREMENT, source TEXT NOT NULL)',
    );
    await connectionA.customStatement("INSERT INTO wal_probe (source) VALUES ('committed-before')");

    // Connection A holds a write transaction for 2 s, like a long sync apply.
    final aHoldsWriteLock = Completer<void>();
    late int aReleasesAtMicros;
    final transactionA = connectionA.transaction(() async {
      await connectionA.customStatement("INSERT INTO wal_probe (source) VALUES ('a-pending')");
      aHoldsWriteLock.complete();
      await Future<void>.delayed(const Duration(seconds: 2));
      aReleasesAtMicros = _nowMicros();
    });
    await aHoldsWriteLock.future;

    final connectionBFuture = _spawnConnectionB(temporaryDirectory.path);
    await transactionA;
    final connectionB = await connectionBFuture;

    expect(connectionB.errors, isEmpty, reason: 'no SQLITE_BUSY / "database is locked" error');
    expect(connectionB.commitTimesMicros, hasLength(20));

    // B read committed data while A's transaction was still open, without
    // seeing A's uncommitted row.
    expect(connectionB.readAtMicros, lessThan(aReleasesAtMicros));
    expect(connectionB.rowsSeenDuringA, ['committed-before']);

    // B's writes only committed once A had finished.
    for (final commitTime in connectionB.commitTimesMicros) {
      expect(commitTime, greaterThanOrEqualTo(aReleasesAtMicros));
    }

    final finalRows = await connectionA.customSelect('SELECT source FROM wal_probe ORDER BY id').get();
    expect(finalRows.map((row) => row.read<String>('source')), [
      'committed-before',
      'a-pending',
      for (var i = 0; i < 20; i++) 'b-$i',
    ]);
  }, skip: _profilerBlocksBusyTimeout);
}
