// T18 sim-drift: seeded random operations on three AppDatabase devices
// (repository-style SQL writes, triggers, this store) with random partial
// sessions, then a quiescent sync. The oracle is the last-writer-wins rule
// (T9) applied to the log of every cell any device authored.
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
import 'package:whph_sync_core/whph_sync_core.dart';

import 'drift_sync_test_support.dart';

const int _deviceCount = 3;
const int _maxClockOffsetMs = 60 * 60 * msPerSecond;
const int _maxSessionBatch = 12;
const int _finalSyncRounds = 3;

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
    final theirs = await source.store.readVector();
    final mine = await target.store.readVector();
    for (final entry in theirs.entries) {
      if (entry.key == target.origin || random.nextBool()) continue;
      var after = mine[entry.key] ?? 0;
      while (after < entry.value) {
        final batch = await source.store.readChanges(entry.key,
            afterSeq: after,
            upToSeq: entry.value,
            limit: 1 + random.nextInt(_maxSessionBatch));
        await target.store.applyBatch(batch);
        after = batch.toSeq;
        if (random.nextDouble() < 0.2) break;
      }
    }
    await _recordKnownNotes(into);
  }

  Future<void> _recordKnownNotes(int d) async {
    final ids = await devices[d].rows('SELECT id FROM note_table');
    knownNotes[d]
      ..clear()
      ..addAll(ids.map((r) => r['id'] as String));
  }

  // -- oracle ---------------------------------------------------------------

  Future<List<_Violation>> check() async {
    for (var d = 0; d < _deviceCount; d++) {
      await _recordKnownNotes(d);
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

  Map<String, Map<String, Object?>> _expectedRows() {
    final winners = <CellKey, CellRecord>{
      for (final entry in writeLog.entries)
        entry.key: entry.value.reduce(mergeCell2),
    };
    final byRow = <RowRef, List<CellRecord>>{};
    for (final cell in winners.values) {
      byRow.putIfAbsent(cell.key.row, () => []).add(cell);
    }
    final expected = <String, Map<String, Object?>>{};
    for (final entry in byRow.entries) {
      final row = CellListRow(entry.value);
      final deleted =
          rowExistence(entry.key, (ref) => ref == entry.key ? row : null) ==
              RowExistence.deleted;
      expected[entry.key.pk] = {
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
    final rows = {
      for (final row in await devices[d]
          .rows('SELECT id, title, content, deleted_date FROM note_table'))
        row['id'] as String: row
    };
    for (final entry in expected.entries) {
      final actual = rows[entry.key];
      if (actual == null) {
        violations.add(_Violation('lost_edit', 'd$d lacks ${entry.key}'));
        continue;
      }
      if (actual['title'] != entry.value['title'] ||
          actual['content'] != entry.value['content']) {
        violations.add(_Violation('lost_edit',
            'd$d ${entry.key} has ${actual['title']}/${actual['content']}, expected ${entry.value['title']}/${entry.value['content']}'));
      }
      if (actual['deleted_date'] != entry.value['deleted_date']) {
        final alive = actual['deleted_date'] == null;
        violations.add(_Violation(alive ? 'resurrection' : 'lost_revival',
            'd$d ${entry.key} deleted_date ${actual['deleted_date']}, expected ${entry.value['deleted_date']}'));
      }
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
