// T18 sim-drift: seeded random operations on three real devices (Drift
// database, file key store, membership with real Noise identities, paired
// through the real handover) driven through repository-style SQL writes,
// capture triggers and the async session engine (T22e): sessions are real
// `AsyncSyncSession`s over in-memory transports, some cut half way. The oracle
// is the last-writer-wins rule (T9) applied to the log of every cell any
// device authored.
//
// One op per run is a real key loss (D6b/D14): a device's key file is
// deleted, the startup check switches origin and issues a new identity,
// its un-manifested cells are adopted onto the new origin, the peers revoke
// the old member, and the device is paired again; the quiescent sync still
// converges.
//
// Entities: notes (field-level) and tasks with subtasks, whose deletion is a
// cascade (D5b) caught by the cause-scoped tombstones.
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
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_cascade_service.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../shared/features/sync/drift_session_test_support.dart';
import '../../shared/features/sync/sync_security_test_support.dart';
import 'drift_sync_test_support.dart';
import 'restore_test_support.dart';

const int _deviceCount = 3;
const int _maxClockOffsetMs = 60 * 60 * msPerSecond;
const int _finalSyncRounds = 3;
const double _cutShare = 0.2;
const double _sessionShare = 0.3;
const int _minCutFrames = 4;
const int _cutFrameSpread = 80;
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
  final Directory scratch;
  final List<DriftEngineDevice> engines = [];
  final List<_Violation> structural = [];
  final List<int> lastLoggedSeq = List.filled(_deviceCount, 0);
  final Map<CellKey, List<CellRecord>> writeLog = {};
  final List<List<String>> knownNotes = List.generate(_deviceCount, (_) => []);
  final List<List<String>> knownTasks = List.generate(_deviceCount, (_) => []);
  var created = 0;

  _Run(this.seed, this.ops, this.scratch) : random = Random(seed);

  /// The database handle of device [d] (SQL writes, raw reads).
  List<SyncTestDevice> get devices =>
      [for (final engine in engines) engine.security.database];

  Future<void> open() async {
    for (var d = 0; d < _deviceCount; d++) {
      final security = await SecurityDevice.open('d$d', scratch);
      final offset = random.nextInt(2 * _maxClockOffsetMs) - _maxClockOffsetMs;
      await security.database
          .sql('UPDATE sync_state SET hlc = ((CAST((julianday(\'now\') '
              '- 2440587.5) * 86400000 AS INTEGER) + $offset) << $hlcBits)');
      engines.add(DriftEngineDevice.over(security));
    }
    for (var d = 1; d < _deviceCount; d++) {
      await pairDevices(engines[0].security, engines[d].security);
    }
    await _fullSync();
    await _fullSync();
  }

  Future<void> close() async {
    for (final engine in engines) {
      await engine.close();
    }
  }

  Future<void> run() async {
    for (var step = 0; step < ops; step++) {
      final d = random.nextInt(_deviceCount);
      if (step == ops ~/ 2) await _keyLostOp(random.nextInt(_deviceCount));
      await _localOp(d, step);
      await _logAuthoredCells(d);
      if (random.nextDouble() < _sessionShare) await _randomSession();
    }
    for (var round = 0; round < _finalSyncRounds; round++) {
      await _fullSync(mustComplete: round == _finalSyncRounds - 1);
    }
  }

  /// A real key loss with an old DB (D6b, D14): the key file is deleted, the
  /// startup check issues a new identity and switches origin (adopting what no
  /// peer can hold), the device is paired again and a peer removes the old
  /// member.
  Future<void> _keyLostOp(int lost) async {
    await _fullSync();
    final old = engines[lost].security;
    final oldMember = old.memberId;
    await old.keyStore.keyFile.delete();
    await old.restart();
    final action = await old.startup
        .run(deviceName: old.name, databaseCreatedThisLaunch: false);
    if (action != SyncStartupAction.keyLost) {
      structural.add(_Violation('key_lost', 'startup check said $action'));
    }
    if (!await SyncUpgradeJob(old.database.db).runChunks()) {
      structural.add(_Violation('key_lost', 'reauthor did not finish'));
    }
    engines[lost] = DriftEngineDevice.over(old);
    lastLoggedSeq[lost] = 0;
    await _logAuthoredCells(lost);

    final inviter = engines[(lost + 1) % _deviceCount].security;
    await pairDevices(inviter, old);
    await inviter.service.removeMember(oldMember);
    await _fullSync();
    await _fullSync();
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
    final store = engines[d].security.database.store;
    final origin = await store.localOrigin();
    final batch = await store.readChanges(origin,
        afterSeq: lastLoggedSeq[d],
        upToSeq: (await store.readVector())[origin] ?? 0,
        limit: 1000);
    for (final cell in batch.cells) {
      writeLog.putIfAbsent(cell.key, () => []).add(cell);
    }
    lastLoggedSeq[d] = batch.toSeq;
  }

  /// A real session between two random devices; now and then the link is cut
  /// after a few frames, leaving a partial exchange.
  Future<void> _randomSession() async {
    final from = random.nextInt(_deviceCount);
    final into = (from + 1 + random.nextInt(_deviceCount - 1)) % _deviceCount;
    final cut = random.nextDouble() < _cutShare;
    final faults = cut
        ? TransportFaults(
            cutAfter: _minCutFrames + random.nextInt(_cutFrameSpread))
        : TransportFaults.none;
    await _session(from, into, faults, mustComplete: false);
    await _recordKnownEntities(into);
  }

  /// Runs one session; an uncut one must complete.
  Future<void> _session(int from, int into, TransportFaults faults,
      {bool mustComplete = true}) async {
    final (initiatorEnd, responderEnd) = InMemoryTransport.pair(faults: faults);
    final results = await Future.wait([
      engines[from].initiate(initiatorEnd, engines[into].memberId),
      engines[into].respond(responderEnd),
    ]);
    if (faults.cutAfter != null || !mustComplete) return;
    for (final result in results) {
      if (result is! SessionComplete) {
        structural.add(_Violation(
            'session', 'd$from -> d$into ended $result (seed $seed)'));
      }
    }
  }

  /// Every ordered pair syncs once without faults. Membership spreads
  /// transitively, so a session may fail while a new member is still unknown
  /// to its peer: only a pass with [mustComplete] holds sessions to success.
  Future<void> _fullSync({bool mustComplete = false}) async {
    for (var from = 0; from < _deviceCount; from++) {
      for (var into = 0; into < _deviceCount; into++) {
        if (from == into) continue;
        await _session(from, into, TransportFaults.none,
            mustComplete: mustComplete);
      }
    }
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
    final violations = <_Violation>[...structural];
    for (var d = 0; d < _deviceCount; d++) {
      final revoked = await devices[d]
          .count('SELECT COUNT(DISTINCT revoked_pub) FROM sync_revocation');
      if (revoked != 1) {
        violations.add(_Violation(
            'revocation', 'd$d revokes $revoked members, expected 1'));
      }
    }
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
      final scratch = await Directory.systemTemp.createTemp('sim_drift_');
      addTearDown(() => scratch.delete(recursive: true));
      final run = _Run(seed, ops, scratch);
      await run.open();
      addTearDown(run.close);

      await run.run();
      final violations = await run.check();

      expect(violations, isEmpty,
          reason: 'seed=$seed ops=$ops: ${violations.take(8).join('\n')}');
    });
  }
}
