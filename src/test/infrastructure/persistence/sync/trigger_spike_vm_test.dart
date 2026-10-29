// S2 spike (plan T4): overlapping writers on one WAL file, pure Dart (no Flutter imports), so SQLite's busy handler
// sleeps for real (see wal_concurrency_vm_test.dart):
//
//   cd src && fvm dart test test/infrastructure/persistence/sync/trigger_spike_vm_test.dart
//
// Skipped under `flutter test`, where the profiler cuts busy_timeout to ~60 ms.
import 'dart:io';
import 'dart:isolate';

import 'package:drift/backends.dart';
import 'package:drift/drift.dart' show OpeningDetails;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sqlite_connection_setup.dart';

import 'trigger_spike_sql.dart';

class _RawUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

// Same columns and affinities as drift's task_time_record_table (DateTime columns are unix-second integers).
const String _timeRecordDdl = '''
CREATE TABLE IF NOT EXISTS task_time_record_table (
  id TEXT NOT NULL, task_id TEXT NOT NULL, duration INTEGER NOT NULL, created_date INTEGER NOT NULL,
  modified_date INTEGER NULL, deleted_date INTEGER NULL, PRIMARY KEY (id))''';

const int _writesPerWriter = 200;
const int _writers = 3;

/// One writer on its own isolate and connection: inserts then updates its own rows, each in its own transaction.
Future<List<String>> _writer(String path, int writer) async {
  final db = NativeDatabase(File(path), setup: configureSqliteConnection);
  await db.ensureOpen(_RawUser());
  final errors = <String>[];
  try {
    for (var i = 0; i < _writesPerWriter; i++) {
      try {
        await db.runInsert(
            'INSERT INTO task_time_record_table (id, task_id, duration, created_date) VALUES (?, ?, ?, ?)',
            ['w$writer-$i', 't', i, 1000]);
        await db.runUpdate('UPDATE task_time_record_table SET duration = duration + 1 WHERE id = ?', ['w$writer-$i']);
      } catch (e) {
        errors.add(e.toString());
      }
    }
  } finally {
    await db.close();
  }
  return errors;
}

void main() {
  final underFlutterTest = Platform.environment['FLUTTER_TEST'] == 'true';

  test(
    'overlapping writers on three isolates get unique, commit-ordered seqs and strictly increasing HLCs',
    () async {
      final dir = await Directory.systemTemp.createTemp('whph_s2_vm_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/overlap.sqlite';

      final setup = NativeDatabase(File(path), setup: configureSqliteConnection);
      await setup.ensureOpen(_RawUser());
      await setup.runCustom(_timeRecordDdl);
      for (final statement in [
        ...spikeSchemaStatements(),
        ...spikeTriggerStatements(taskTimeRecordPolicy),
      ]) {
        await setup.runCustom(statement);
      }
      final version = (await setup.runSelect('SELECT sqlite_version() AS v', [])).single['v'];
      await setup.close();

      final sw = Stopwatch()..start();
      final results = await Future.wait([
        for (var w = 0; w < _writers; w++) Isolate.run(() => _writer(path, w)),
      ]);
      sw.stop();
      expect(results.expand((e) => e), isEmpty, reason: 'no SQLITE_BUSY or other write errors');

      final check = NativeDatabase(File(path), setup: configureSqliteConnection);
      await check.ensureOpen(_RawUser());
      try {
        final cells =
            await check.runSelect('SELECT pk, col_id, hlc, origin_seq FROM sync_clock ORDER BY origin_seq', []);
        const expectedCells = _writers * _writesPerWriter * 2; // `*` and `~` per row
        expect(cells, hasLength(expectedCells));
        final seqs = cells.map((c) => c['origin_seq'] as int).toList();
        expect(seqs.toSet(), hasLength(cells.length), reason: 'no duplicate seqs');
        final state = (await check.runSelect('SELECT next_seq, hlc FROM sync_state', [])).single;
        // Each row: 2 insert cells + 1 update `*` cell that overwrote the insert `*` cell -> 3 seqs, 2 live cells.
        expect(state['next_seq'], _writers * _writesPerWriter * 3 + 1);
        for (var i = 1; i < cells.length; i++) {
          expect(cells[i]['hlc'] as int, greaterThan(cells[i - 1]['hlc'] as int),
              reason: 'HLC strictly increasing with seq at seq ${seqs[i]}');
        }
        // Per row: `~` from the insert precedes the `*` of the later update transaction.
        final byPk = <String, Map<int, int>>{};
        for (final c in cells) {
          (byPk[c['pk'] as String] ??= {})[c['col_id'] as int] = c['origin_seq'] as int;
        }
        for (final entry in byPk.entries) {
          expect(entry.value[tombstoneColId]!, lessThan(entry.value[rowLevelColId]!), reason: entry.key);
        }
        // ignore: avoid_print
        print('[S2] vm overlap: sqlite_version=$version, $_writers isolates x ${_writesPerWriter * 2} autocommit '
            'writes in ${sw.elapsedMilliseconds} ms, ${cells.length} cells, max seq ${seqs.last}, '
            'seqs unique, HLC strictly increasing by seq');
      } finally {
        await check.close();
      }
    },
    skip: underFlutterTest ? 'run with `fvm dart test`; flutter test cuts busy_timeout short' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
