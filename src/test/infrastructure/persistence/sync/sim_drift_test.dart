// T18 sim-drift: seeded random operations on three AppDatabase devices
// (repository-style SQL writes, triggers, this store) with random partial
// sessions, then a quiescent sync. The oracle is the last-writer-wins rule
// (T9) applied to the log of every cell any device authored.
//
// Entities: notes (field-level) and tasks with subtasks, whose deletion is a
// cascade (D5b) caught by the cause-scoped tombstones. Sessions run through
// the `AsyncReplicaStore` port.
//
// SIM_DRIFT_SEEDS (default 3), SIM_DRIFT_OPS (default 150) and
// SIM_SEED=<n> (run one seed) scale the run; soaks use larger values.
@Tags(['sim-drift'])
@Timeout(Duration(minutes: 30))
library;

import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_cascade_service.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'drift_sync_test_support.dart';

const int _deviceCount = 3;
const int _maxClockOffsetMs = 60 * 60 * msPerSecond;
const int _maxSessionBatch = 12;
const int _finalSyncRounds = 3;
const double _noteShare = 0.6;
const String _taskTable = 'task_table';
const List<String> _comparedColumns = ['title', 'content'];
const String _noteTable = 'note_table';

int _envInt(String name, int fallback) =>
    int.tryParse(Platform.environment[name] ?? '') ?? fallback;

class _Violation {
  final String kind;
  final String detail;
  _Violation(this.kind, this.detail);

  @override
  String toString() => '$kind: $detail';
}

class _Run {
  final int seed;
  final int ops;
  final Random random;
  final List<SyncTestDevice> devices = [];
  final List<int> lastLoggedSeq = List.filled(_deviceCount, 0);
  final Map<CellKey, List<CellRecord>> writeLog = {};
  final List<List<String>> knownNotes = List.generate(_deviceCount, (_) => []);
  final List<List<String>> knownTasks = List.generate(_deviceCount, (_) => []);
  var created = 0;

  _Run(this.seed, this.ops) : random = Random(seed);

  Future<void> open() async {
    for (var d = 0; d < _deviceCount; d++) {
      final device = await SyncTestDevice.open('d$d');
      final offset = random.nextInt(2 * _maxClockOffsetMs) - _maxClockOffsetMs;
      await device.sql('UPDATE sync_state SET hlc = ((CAST((julianday(\'now\') '
          '- 2440587.5) * 86400000 AS INTEGER) + $offset) << $hlcBits)');
      devices.add(device);
    }
  }

  Future<void> close() async {
    for (final device in devices) {
      await device.close();
    }
  }

  Future<void> run() async {
    for (var step = 0; step < ops; step++) {
      final d = random.nextInt(_deviceCount);
      await _localOp(d, step);
      await _logAuthoredCells(d);
      if (random.nextDouble() < 0.3) await _randomSession();
    }
    for (var round = 0; round < _finalSyncRounds; round++) {
      await syncAllDevices(devices);
    }
  }

  Future<void> _localOp(int d, int step) async {
    if (random.nextDouble() < _noteShare) return _noteOp(d, step);
    return _taskOp(d, step);
  }

  Future<void> _taskOp(int d, int step) async {
    final device = devices[d];
    final known = knownTasks[d];
    final r = random.nextDouble();
    if (known.isEmpty || r < 0.3) {
      final pk = 't${d}_${created++}';
      final alive = await device
          .rows('SELECT id FROM task_table WHERE deleted_date IS NULL');
      final parent = alive.isEmpty || random.nextBool()
          ? 'NULL'
          : "'${alive[random.nextInt(alive.length)]['id']}'";
      await device.sql(
          "INSERT INTO task_table (id, created_date, title, parent_task_id) VALUES ('$pk', 1, 'task $step', $parent)");
      known.add(pk);
      return;
    }
    final pk = known[random.nextInt(known.length)];
    final isDeleted = (await device.rows(
                'SELECT deleted_date FROM task_table WHERE id = ?',
                [Variable(pk)]))
            .single['deleted_date'] !=
        null;
    if (isDeleted) {
      await device
          .sql('UPDATE task_table SET deleted_date = NULL WHERE id = ?', [pk]);
    } else if (r < 0.65) {
      await device.sql(
          "UPDATE task_table SET title = 'task $step by d$d' WHERE id = ?",
          [pk]);
    } else {
      await _cascadeDelete(device, pk, 1000 + step);
    }
  }

  /// Soft-deletes task [pk] and its alive subtasks with [pk] as the cause.
  Future<void> _cascadeDelete(SyncTestDevice device, String pk, int at) async {
    final children = await device.rows(
        'SELECT id FROM task_table WHERE parent_task_id = ? AND deleted_date IS NULL',
        [Variable(pk)]);
    await DriftSyncCascadeService(device.db).withCause(_taskTable, pk,
        () async {
      await device
          .sql('UPDATE task_table SET deleted_date = $at WHERE id = ?', [pk]);
      for (final child in children) {
        await device.sql(
            'UPDATE task_table SET deleted_date = $at WHERE id = ?',
            [child['id']]);
      }
    });
  }

  Future<void> _noteOp(int d, int step) async {
    final device = devices[d];
    final known = knownNotes[d];
    final r = random.nextDouble();
    if (known.isEmpty || r < 0.2) {
      final pk = 'n${d}_${created++}';
      await device.insertNote(pk, 'title $step');
      known.add(pk);
      return;
    }
    final pk = known[random.nextInt(known.length)];
    final isDeleted = (await device.note(pk))['deleted_date'] != null;
    // Users cannot edit a deleted item; they can restore it.
    if (isDeleted) {
      await device
          .sql('UPDATE note_table SET deleted_date = NULL WHERE id = ?', [pk]);
    } else if (r < 0.55) {
      await device.setTitle(pk, 'title $step by d$d');
    } else if (r < 0.85) {
      await device.sql(
          "UPDATE note_table SET content = 'content $step' WHERE id = ?", [pk]);
    } else {
      await device.sql(
          'UPDATE note_table SET deleted_date = ${1000 + step} WHERE id = ?',
          [pk]);
    }
  }

  /// Adds the cells device [d] authored since its last logged seq.
  Future<void> _logAuthoredCells(int d) async {
    final device = devices[d];
    final origin = device.origin;
    final batch = await device.store.readChanges(origin,
        afterSeq: lastLoggedSeq[d],
        upToSeq: (await device.store.readVector())[origin]!,
        limit: 1000);
    for (final cell in batch.cells) {
      writeLog.putIfAbsent(cell.key, () => []).add(cell);
    }
    lastLoggedSeq[d] = batch.toSeq;
  }

  /// A partial session: random direction, some origins, small batches, and a
  /// cut after the first batch of an origin now and then.
  Future<void> _randomSession() async {
    final from = random.nextInt(_deviceCount);
    final into = (from + 1 + random.nextInt(_deviceCount - 1)) % _deviceCount;
    final source = devices[from];
    final target = devices[into];
    final batches = await source.store.changesSince(await target.store.vector(),
        maxCellsPerBatch: 1 + random.nextInt(_maxSessionBatch));
    final skipped = <String>{};
    for (final batch in batches) {
      if (batch.origin == target.origin) continue;
      if (skipped.contains(batch.origin)) continue;
      if (random.nextDouble() < 0.15) {
        skipped.add(batch.origin);
        continue;
      }
      await target.store.mergeBatch(batch);
    }
    await _recordKnownEntities(into);
  }

  Future<void> _recordKnownEntities(int d) async {
    knownNotes[d]
      ..clear()
      ..addAll(await _ids(d, _noteTable));
    knownTasks[d]
      ..clear()
      ..addAll(await _ids(d, _taskTable));
  }

  Future<List<String>> _ids(int d, String table) async => [
        for (final row in await devices[d].rows('SELECT id FROM $table'))
          row['id'] as String
      ];

  // -- oracle ---------------------------------------------------------------

  Future<List<_Violation>> check() async {
    for (var d = 0; d < _deviceCount; d++) {
      await _recordKnownEntities(d);
    }
    final violations = <_Violation>[];
    final contents = [for (final device in devices) await device.content()];
    for (var d = 1; d < _deviceCount; d++) {
      if (contents[d] != contents[0]) {
        violations.add(_Violation('divergence',
            'd$d differs from d0: ${_firstDifference(contents[0], contents[d])}'));
      }
    }
    final expected = _expectedRows();
    for (var d = 0; d < _deviceCount; d++) {
      violations.addAll(await _compareDevice(d, expected));
    }
    return violations;
  }

  String _firstDifference(String left, String right) {
    final leftLines = left.split('\n');
    final rightLines = right.split('\n');
    for (var i = 0; i < min(leftLines.length, rightLines.length); i++) {
      if (leftLines[i] != rightLines[i])
        return '${leftLines[i]} vs ${rightLines[i]}';
    }
    return 'length ${leftLines.length} vs ${rightLines.length}';
  }

  /// Expected rows by `table/pk` from the merged winners, with cascade
  /// causes resolved over the whole row set (D5b).
  Map<String, Map<String, Object?>> _expectedRows() {
    final winners = <CellKey, CellRecord>{
      for (final entry in writeLog.entries)
        entry.key: entry.value.reduce(mergeCell2),
    };
    final byRow = <RowRef, List<CellRecord>>{};
    for (final cell in winners.values) {
      byRow.putIfAbsent(cell.key.row, () => []).add(cell);
    }
    final lookup = {
      for (final entry in byRow.entries) entry.key: CellListRow(entry.value)
    };
    final expected = <String, Map<String, Object?>>{};
    for (final entry in lookup.entries) {
      final row = entry.value;
      final deleted =
          rowExistence(entry.key, (ref) => lookup[ref]) == RowExistence.deleted;
      expected['${entry.key.table}/${entry.key.pk}'] = {
        'deleted_date': deleted ? row.existence!.value : null,
        for (final cell in row.dataCells) cell.key.col: cell.value,
      };
    }
    return expected;
  }

  CellRecord mergeCell2(CellRecord a, CellRecord b) => mergeCell(a, b);

  Future<List<_Violation>> _compareDevice(
      int d, Map<String, Map<String, Object?>> expected) async {
    final violations = <_Violation>[];
    for (final table in [_noteTable, _taskTable]) {
      final rows = {
        for (final row in await devices[d].rows('SELECT * FROM $table'))
          row['id'] as String: row
      };
      for (final entry in expected.entries) {
        if (!entry.key.startsWith('$table/')) continue;
        final pk = entry.key.substring(table.length + 1);
        violations.addAll(_compareRow(d, pk, rows[pk], entry.value));
      }
    }
    return violations;
  }

  List<_Violation> _compareRow(int d, String pk, Map<String, Object?>? actual,
      Map<String, Object?> want) {
    if (actual == null) return [_Violation('lost_edit', 'd$d lacks $pk')];
    final violations = <_Violation>[];
    for (final column in _comparedColumns) {
      if (!want.containsKey(column) && actual[column] == null) continue;
      if (actual[column] != want[column]) {
        violations.add(_Violation('lost_edit',
            'd$d $pk $column is ${actual[column]}, expected ${want[column]}'));
      }
    }
    if (actual['deleted_date'] != want['deleted_date']) {
      final alive = actual['deleted_date'] == null;
      violations.add(_Violation(alive ? 'resurrection' : 'lost_revival',
          'd$d $pk deleted_date ${actual['deleted_date']}, expected ${want['deleted_date']}'));
    }
    return violations;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final single = Platform.environment['SIM_SEED'];
  final seeds = single != null
      ? [int.parse(single)]
      : [for (var i = 1; i <= _envInt('SIM_DRIFT_SEEDS', 3); i++) i];
  final ops = _envInt('SIM_DRIFT_OPS', 150);

  for (final seed in seeds) {
    test('seed $seed: $_deviceCount devices x $ops ops converge', () async {
      final run = _Run(seed, ops);
      await run.open();
      addTearDown(run.close);

      await run.run();
      final violations = await run.check();

      expect(violations, isEmpty,
          reason: 'seed=$seed ops=$ops: ${violations.take(8).join('\n')}');
    });
  }
}
