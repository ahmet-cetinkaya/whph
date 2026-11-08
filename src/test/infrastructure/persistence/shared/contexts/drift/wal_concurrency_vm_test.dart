// Pure-Dart variant of wal_concurrency_test.dart (no Flutter imports), so it can run in a VM without the
// Dart profiler, which is how release builds run:
//
//   cd src && fvm dart test test/infrastructure/persistence/shared/contexts/drift/wal_concurrency_vm_test.dart
//
// Under `flutter test` the profiler is always on and its SIGPROF interrupts the sleep in SQLite's default
// busy handler, which cuts `busy_timeout = 5000` down to ~60 ms of real time (see wal_concurrency_test.dart).
// The test is therefore skipped when FLUTTER_TEST is set.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/backends.dart';
import 'package:drift/drift.dart' show OpeningDetails;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sqlite_connection_setup.dart';

class _RawUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

int _nowMicros() => DateTime.now().microsecondsSinceEpoch;

typedef _ConnectionBResult = ({
  List<String> rowsSeenDuringA,
  int readAtMicros,
  List<int> commitTimesMicros,
  List<String> errors,
  String journalMode,
  int busyTimeout,
});

/// Connection B: a separate isolate and connection on the same file, standing in for the widget background
/// isolate, opened with the production `setup:` callback.
Future<_ConnectionBResult> _runConnectionB(String path) async {
  final database = NativeDatabase(File(path), setup: configureSqliteConnection);
  await database.ensureOpen(_RawUser());
  final errors = <String>[];
  final commitTimes = <int>[];
  try {
    final journalMode = (await database.runSelect('PRAGMA journal_mode', [])).single.values.single as String;
    final busyTimeout = (await database.runSelect('PRAGMA busy_timeout', [])).single.values.single as int;
    final rows = await database.runSelect('SELECT source FROM wal_probe ORDER BY id', []);
    final readAt = _nowMicros();
    for (var i = 0; i < 20; i++) {
      try {
        await database.runInsert('INSERT INTO wal_probe (source) VALUES (?)', ['b-$i']);
        commitTimes.add(_nowMicros());
      } catch (e) {
        errors.add(e.toString());
      }
    }
    return (
      rowsSeenDuringA: rows.map((row) => row['source'] as String).toList(),
      readAtMicros: readAt,
      commitTimesMicros: commitTimes,
      errors: errors,
      journalMode: journalMode,
      busyTimeout: busyTimeout,
    );
  } finally {
    await database.close();
  }
}

Future<_ConnectionBResult> _spawnConnectionB(String path) => Isolate.run(() => _runConnectionB(path));

void main() {
  final underFlutterTest = Platform.environment['FLUTTER_TEST'] == 'true';

  test(
    'writes from another isolate wait out a 2 s write transaction instead of failing as locked (no profiler)',
    () async {
      final directory = await Directory.systemTemp.createTemp('whph_wal_concurrency_vm_');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/probe.db';

      final connectionA = NativeDatabase.createInBackground(File(path), setup: configureSqliteConnection);
      addTearDown(connectionA.close);
      await connectionA.ensureOpen(_RawUser());
      await connectionA.runCustom(
        'CREATE TABLE wal_probe (id INTEGER PRIMARY KEY AUTOINCREMENT, source TEXT NOT NULL)',
      );
      await connectionA.runInsert("INSERT INTO wal_probe (source) VALUES ('committed-before')", []);

      // Connection A holds a write transaction for 2 s, like a long sync apply.
      final transaction = connectionA.beginTransaction();
      await transaction.ensureOpen(_RawUser());
      await transaction.runInsert("INSERT INTO wal_probe (source) VALUES ('a-pending')", []);

      final connectionBFuture = _spawnConnectionB(path);
      await Future<void>.delayed(const Duration(seconds: 2));
      final aReleasesAtMicros = _nowMicros();
      await transaction.send();
      final connectionB = await connectionBFuture;

      expect(connectionB.journalMode, 'wal');
      expect(connectionB.busyTimeout, sqliteBusyTimeoutMs);
      expect(connectionB.errors, isEmpty, reason: 'no SQLITE_BUSY / "database is locked" error');
      expect(connectionB.commitTimesMicros, hasLength(20));

      // B read committed data while A's transaction was open, without A's uncommitted row.
      expect(connectionB.readAtMicros, lessThan(aReleasesAtMicros));
      expect(connectionB.rowsSeenDuringA, ['committed-before']);

      // B's writes committed only after A finished.
      for (final commitTime in connectionB.commitTimesMicros) {
        expect(commitTime, greaterThanOrEqualTo(aReleasesAtMicros));
      }

      final finalRows = await connectionA.runSelect('SELECT source FROM wal_probe ORDER BY id', []);
      expect(finalRows.map((row) => row['source']), [
        'committed-before',
        'a-pending',
        for (var i = 0; i < 20; i++) 'b-$i',
      ]);
    },
    skip: underFlutterTest
        ? 'Dart profiler (always on in flutter test) cuts SQLite busy_timeout to ~60 ms; run with `fvm dart test`.'
        : false,
  );
}
