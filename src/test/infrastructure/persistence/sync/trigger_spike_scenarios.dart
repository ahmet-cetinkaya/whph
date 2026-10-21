// S2 spike (plan T4) scenarios, shared by
//   test/infrastructure/persistence/sync/trigger_spike_test.dart          (flutter test, host VM)
//   integration_test/sync_trigger_spike_test.dart                          (flutter test -d linux / android)
// Spike-only code; nothing here ships in src/lib.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sqlite_connection_setup.dart';

import 'trigger_spike_sql.dart';

/// Registers one test. The unit test passes `test`, the integration test passes `testWidgets`.
typedef SpikeRegistrar = void Function(String description, Future<void> Function() body);

void spikeLog(String message) {
  // ignore: avoid_print
  print('[S2] $message');
}

// ---------------------------------------------------------------------------------------------------------------
// Connections

AppDatabase openMemoryDb() => AppDatabase.withExecutor(NativeDatabase.memory());

AppDatabase openFileDb(File file) => AppDatabase.withExecutor(NativeDatabase(file, setup: configureSqliteConnection));

AppDatabase openBackgroundFileDb(File file) =>
    AppDatabase.withExecutor(NativeDatabase.createInBackground(file, setup: configureSqliteConnection));

Future<void> installSpike(AppDatabase db, [SpikeSqlOptions options = SpikeSqlOptions.recommended]) async {
  for (final statement in spikeInstallStatements(options)) {
    await db.customStatement(statement);
  }
  // Coverage: every column of each spike table is either a synced column or one of the excluded ones.
  for (final policy in spikePolicies) {
    final info = await db.customSelect('PRAGMA table_info(${policy.tableName})').get();
    final actual = info.map((r) => r.read<String>('name')).toSet();
    final expected = {...policy.columns.keys, ...SpikeTablePolicy.excludedColumns};
    expect(actual, equals(expected), reason: 'synced column coverage for ${policy.tableName}');
  }
}

Future<String> sqliteVersion(AppDatabase db) async =>
    (await db.customSelect('SELECT sqlite_version() AS v').getSingle()).read<String>('v');

// ---------------------------------------------------------------------------------------------------------------
// Clock inspection

class ClockRow {
  final int tblId;
  final String pk;
  final int colId;
  final int hlc;
  final int nodeId;
  final int originId;
  final int originSeq;
  final int? manifestId;
  final int? tombValue;
  final int recordedAt;

  ClockRow(Map<String, Object?> d)
      : tblId = d['tbl_id'] as int,
        pk = d['pk'] as String,
        colId = d['col_id'] as int,
        hlc = d['hlc'] as int,
        nodeId = d['node_id'] as int,
        originId = d['origin_id'] as int,
        originSeq = d['origin_seq'] as int,
        manifestId = d['manifest_id'] as int?,
        tombValue = d['tomb_value'] as int?,
        recordedAt = d['recorded_at'] as int;

  (int, String, int) get key => (tblId, pk, colId);

  @override
  String toString() => 'cell($tblId,$pk,$colId seq=$originSeq hlc=$hlc tomb=$tombValue)';
}

class SyncStateRow {
  final int hlc;
  final int nextSeq;
  final int applyMode;
  final int nodeId;
  final int originId;
  SyncStateRow(Map<String, Object?> d)
      : hlc = d['hlc'] as int,
        nextSeq = d['next_seq'] as int,
        applyMode = d['apply_mode'] as int,
        nodeId = d['node_id'] as int,
        originId = d['origin_id'] as int;
}

Future<SyncStateRow> readState(AppDatabase db) async =>
    SyncStateRow((await db.customSelect('SELECT * FROM sync_state WHERE id = 1').getSingle()).data);

/// Cells of [originId] with a seq above [seq], in seq order.
Future<List<ClockRow>> cellsWithSeqAbove(AppDatabase db, int originId, int seq) async =>
    (await db.customSelect('SELECT * FROM sync_clock WHERE origin_id = ? AND origin_seq > ? ORDER BY origin_seq',
            variables: [Variable.withInt(originId), Variable.withInt(seq)]).get())
        .map((r) => ClockRow(r.data))
        .toList();

Future<List<ClockRow>> allCellsBySeq(AppDatabase db) async =>
    (await db.customSelect('SELECT * FROM sync_clock ORDER BY origin_seq').get()).map((r) => ClockRow(r.data)).toList();

Future<ClockRow?> cellOf(AppDatabase db, int tblId, String pk, int colId) async {
  final row = await db.customSelect('SELECT * FROM sync_clock WHERE tbl_id = ? AND pk = ? AND col_id = ?',
      variables: [Variable.withInt(tblId), Variable.withString(pk), Variable.withInt(colId)]).getSingleOrNull();
  return row == null ? null : ClockRow(row.data);
}

Future<int?> deletedDateOf(AppDatabase db, String table, String id) async => (await db
        .customSelect('SELECT deleted_date FROM $table WHERE id = ?', variables: [Variable.withString(id)]).getSingle())
    .data['deleted_date'] as int?;

Set<(int, String, int)> cellKeys(int tblId, String pk, Iterable<int> colIds) =>
    {for (final c in colIds) (tblId, pk, c)};

void expectStrictlyIncreasingHlc(List<ClockRow> bySeq, String label) {
  for (var i = 1; i < bySeq.length; i++) {
    if (bySeq[i].hlc <= bySeq[i - 1].hlc) {
      fail('$label: HLC not strictly increasing at seq ${bySeq[i].originSeq}: ${bySeq[i - 1].hlc} -> ${bySeq[i].hlc}');
    }
  }
}

/// Runs [write] and asserts it produced exactly the cells in [expected] (by key), each with a fresh local seq and
/// HLC, with `next_seq` advancing by exactly the number of cells. Returns the new cells.
Future<List<ClockRow>> expectWrite(
  AppDatabase db,
  String label,
  Future<void> Function() write,
  Set<(int, String, int)> expected,
) async {
  final before = await readState(db);
  await write();
  final after = await readState(db);
  final cells = await cellsWithSeqAbove(db, before.originId, before.nextSeq - 1);
  expect(cells.map((c) => c.key).toSet(), equals(expected), reason: '$label: cell set');
  expect(cells.length, expected.length, reason: '$label: one cell per key');
  expect(after.nextSeq - before.nextSeq, expected.length, reason: '$label: seq advance equals cell count');
  for (final c in cells) {
    expect(c.originId, before.originId, reason: '$label: own origin');
    expect(c.nodeId, before.nodeId, reason: '$label: own node');
    expect(c.manifestId, isNull, reason: '$label: local cells have no manifest');
    expect(c.hlc, greaterThan(before.hlc), reason: '$label: fresh HLC');
  }
  expectStrictlyIncreasingHlc(cells, label);
  expect(after.applyMode, 0, reason: '$label: apply_mode');
  spikeLog('path "$label": ${cells.length} cell(s) ${cells.map((c) => '${c.pk}/${c.colId}').join(' ')}');
  return cells;
}

// ---------------------------------------------------------------------------------------------------------------
// Fixtures (synthetic)

Task newTask(String id, {String title = 'Spike task'}) => Task(
      id: id,
      createdDate: DateTime.utc(2026, 1, 1),
      title: title,
      description: 'Synthetic',
      estimatedTime: 15,
    );

TaskTimeRecord newTimeRecord(String id, String taskId) =>
    TaskTimeRecord(id: id, taskId: taskId, duration: 60, createdDate: DateTime.utc(2026, 1, 1));

int nowSeconds() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

Set<int> allTaskCols() => {...taskPolicy.columns.values, tombstoneColId};

// ---------------------------------------------------------------------------------------------------------------
// Scenarios

/// Criterion 1: every write path on one connection.
Future<void> runWritePathsScenario(AppDatabase db, String label) async {
  await installSpike(db);
  spikeLog('$label sqlite_version=${await sqliteVersion(db)}');
  final tasks = DriftTaskRepository.withDatabase(db);
  final records = DriftTaskTimeRecordRepository.withDatabase(db);
  const t = taskTblId;
  const r = taskTimeRecordTblId;
  final cols = taskPolicy.columns;

  // --- task_table (field-level)
  final insertCells = await expectWrite(
      db, 'task repo insert', () => tasks.add(newTask('task-a')), cellKeys(t, 'task-a', allTaskCols()));
  expect(insertCells.firstWhere((c) => c.colId == tombstoneColId).tombValue, isNull);

  await expectWrite(db, 'task repo update title', () async {
    final task = (await tasks.getById('task-a'))!;
    task.title = 'Renamed';
    await tasks.update(task);
  }, cellKeys(t, 'task-a', [cols['title']!]));

  await expectWrite(db, 'task repo update no-op (modified_date only)', () async {
    await tasks.update((await tasks.getById('task-a'))!);
  }, {});

  await expectWrite(
      db,
      'task customUpdate note-order style',
      () => db.customUpdate('UPDATE task_table SET "order" = ? WHERE id = ?',
          variables: [Variable<String>('V'), Variable<String>('task-a')], updates: {db.taskTable}),
      cellKeys(t, 'task-a', [cols['order']!]));

  await expectWrite(
      db,
      'task customStatement 2 columns',
      () =>
          db.customStatement('UPDATE task_table SET priority = ?, estimated_time = ? WHERE id = ?', [2, 45, 'task-a']),
      cellKeys(t, 'task-a', [cols['priority']!, cols['estimated_time']!]));

  await expectWrite(db, 'task customStatement no-op', () async {
    await db.customStatement('UPDATE task_table SET title = title, "order" = "order" WHERE id = ?', ['task-a']);
    await db.customStatement('UPDATE task_table SET modified_date = ? WHERE id = ?', [nowSeconds(), 'task-a']);
  }, {});

  final softDelete = await expectWrite(db, 'task repo delete (soft)', () async {
    await tasks.delete((await tasks.getById('task-a'))!);
  }, cellKeys(t, 'task-a', [tombstoneColId]));
  final deletedDate = await deletedDateOf(db, 'task_table', 'task-a');
  expect(deletedDate, isNotNull);
  expect(softDelete.single.tombValue, deletedDate, reason: 'soft delete: ~ carries deleted_date');

  final revival = await expectWrite(db, 'task repo revival (deleted_date -> NULL)', () async {
    final task = (await tasks.getById('task-a', includeDeleted: true))!;
    task.deletedDate = null;
    await tasks.update(task);
  }, cellKeys(t, 'task-a', [tombstoneColId]));
  expect(revival.single.tombValue, isNull, reason: 'revival: ~ carries NULL');

  await expectWrite(
      db,
      'task customStatement INSERT OR REPLACE existing id',
      () => db.customStatement('INSERT OR REPLACE INTO task_table (id, title, created_date) VALUES (?, ?, ?)',
          ['task-a', 'Replaced', nowSeconds()]),
      cellKeys(t, 'task-a', allTaskCols()));

  await tasks.add(newTask('task-b'));
  final hardDelete = await expectWrite(db, 'task customStatement hard DELETE (live)',
      () => db.customStatement('DELETE FROM task_table WHERE id = ?', ['task-b']), cellKeys(t, 'task-b', [0]));
  expect(hardDelete.single.tombValue, closeTo(nowSeconds(), 5), reason: 'hard delete: ~ = now');

  await expectWrite(
      db,
      'task customStatement INSERT OR IGNORE re-creating hard-deleted id',
      () => db.customStatement('INSERT OR IGNORE INTO task_table (id, title, created_date) VALUES (?, ?, ?)',
          ['task-b', 'Back', nowSeconds()]),
      cellKeys(t, 'task-b', allTaskCols()));
  expect((await cellOf(db, t, 'task-b', tombstoneColId))!.tombValue, isNull);

  await tasks.add(newTask('task-c'));
  await tasks.delete((await tasks.getById('task-c'))!);
  await expectWrite(db, 'task repo hardDeleteSoftDeleted (row not live)',
      () => tasks.hardDeleteSoftDeleted(DateTime.now().toUtc().add(const Duration(days: 1))), {});
  expect(await db.customSelect("SELECT 1 FROM task_table WHERE id = 'task-c'").get(), isEmpty);

  // --- task_time_record_table (row-level)
  await expectWrite(db, 'time record repo insert', () => records.add(newTimeRecord('ttr-a', 'task-a')),
      cellKeys(r, 'ttr-a', [rowLevelColId, tombstoneColId]));

  await expectWrite(db, 'time record repo update duration', () async {
    final rec = (await records.getById('ttr-a'))!;
    rec.duration = 120;
    await records.update(rec);
  }, cellKeys(r, 'ttr-a', [rowLevelColId]));

  await expectWrite(db, 'time record repo update no-op', () async {
    await records.update((await records.getById('ttr-a'))!);
  }, {});

  await expectWrite(
      db,
      'time record customStatement 2 columns -> one * cell',
      () => db.customStatement(
          'UPDATE task_time_record_table SET task_id = ?, duration = ? WHERE id = ?', ['task-b', 300, 'ttr-a']),
      cellKeys(r, 'ttr-a', [rowLevelColId]));

  final recDelete = await expectWrite(db, 'time record repo delete (soft)', () async {
    await records.delete((await records.getById('ttr-a'))!);
  }, cellKeys(r, 'ttr-a', [tombstoneColId]));
  expect(recDelete.single.tombValue, await deletedDateOf(db, 'task_time_record_table', 'ttr-a'));

  final recRevive = await expectWrite(
      db,
      'time record customStatement revival',
      () => db.customStatement('UPDATE task_time_record_table SET deleted_date = NULL WHERE id = ?', ['ttr-a']),
      cellKeys(r, 'ttr-a', [tombstoneColId]));
  expect(recRevive.single.tombValue, isNull);

  await expectWrite(
      db,
      'time record hard DELETE (live)',
      () => db.customStatement('DELETE FROM task_time_record_table WHERE id = ?', ['ttr-a']),
      cellKeys(r, 'ttr-a', [tombstoneColId]));

  // Whole-table invariants.
  final all = await allCellsBySeq(db);
  expect(all.map((c) => c.originSeq).toSet().length, all.length, reason: 'unique seqs');
  expectStrictlyIncreasingHlc(all, '$label all cells');
}

/// Criterion 4: hard DELETE of a duplicate rowid (mirrors `drift_task_repository.dart:222`).
Future<void> runDuplicateRowidScenario(AppDatabase db) async {
  // Duplicates cannot exist under the current `PRIMARY KEY ("id")`; recreate task_table without it (as in legacy
  // databases that produced duplicates) before installing the triggers.
  final ddl =
      (await db.customSelect("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'task_table'").getSingle())
          .read<String>('sql');
  final noPk = ddl.replaceFirst(RegExp(r',\s*PRIMARY KEY\s*\("id"\)'), '');
  expect(noPk, isNot(equals(ddl)), reason: 'PRIMARY KEY clause found and removed');
  await db.customStatement('DROP TABLE task_table');
  await db.customStatement(noPk);
  await installSpike(db);

  const insert = 'INSERT INTO task_table (id, title, created_date) VALUES (?, ?, ?)';
  await db.customStatement(insert, ['dup', 'first', 1000]);
  await db.customStatement(insert, ['dup', 'second', 2000]);
  final rowIds = (await db.customSelect("SELECT rowid AS rid FROM task_table WHERE id = 'dup' ORDER BY rowid").get())
      .map((r) => r.read<int>('rid'))
      .toList();
  expect(rowIds, hasLength(2));

  await expectWrite(db, 'duplicate rowid DELETE while another row with the id remains',
      () => db.customStatement('DELETE FROM task_table WHERE rowid IN (?)', [rowIds[1]]), {});
  expect((await cellOf(db, taskTblId, 'dup', tombstoneColId))!.tombValue, isNull, reason: 'no tombstone');

  await expectWrite(
      db,
      'last row with the id DELETE',
      () => db.customStatement('DELETE FROM task_table WHERE rowid IN (?)', [rowIds[0]]),
      cellKeys(taskTblId, 'dup', [tombstoneColId]));
}

/// Criterion 3: `apply_mode = 1` remote apply writes verbatim; committed apply_mode is 0.
Future<void> runRemoteApplyScenario(AppDatabase db, AppDatabase other) async {
  await installSpike(db);
  final tasks = DriftTaskRepository.withDatabase(db);
  await tasks.add(newTask('r1'));
  final before = await readState(db);

  await db.customStatement("INSERT OR IGNORE INTO sync_intern (kind, value) VALUES ($internKindNode, 'spike-remote')");
  await db.customStatement(
      "INSERT OR IGNORE INTO sync_intern (kind, value) VALUES ($internKindOrigin, 'spike-origin-remote')");
  final remoteNode =
      (await db.customSelect("SELECT id FROM sync_intern WHERE value = 'spike-remote'").getSingle()).read<int>('id');
  final remoteOrigin =
      (await db.customSelect("SELECT id FROM sync_intern WHERE value = 'spike-origin-remote'").getSingle())
          .read<int>('id');
  // One day ahead: accepted (no forward clamp, D2).
  final remoteBase = before.hlc + (86400000 << 16);
  const remoteDeletedDate = 1767225600; // 2026-01-01T00:00:00Z
  const manifestId = 7;

  final remoteCells = [
    (pk: 'r1', col: taskPolicy.columns['title']!, hlc: remoteBase + 1, seq: 41, tomb: null),
    (pk: 'r2', col: taskPolicy.columns['title']!, hlc: remoteBase + 2, seq: 42, tomb: null),
    (pk: 'r2', col: tombstoneColId, hlc: remoteBase + 3, seq: 43, tomb: remoteDeletedDate),
  ];

  var applyModeInside = -1;
  await db.transaction(() async {
    await db.customStatement('UPDATE sync_state SET apply_mode = 1 WHERE id = 1');
    applyModeInside = (await readState(db)).applyMode;
    await db.customStatement(
        'UPDATE task_table SET title = ?, modified_date = ? WHERE id = ?', ['Remote title', nowSeconds() + 1, 'r1']);
    await db.customStatement('INSERT INTO task_table (id, title, created_date, deleted_date) VALUES (?, ?, ?, ?)',
        ['r2', 'Remote new', 1000, remoteDeletedDate]);
    for (final c in remoteCells) {
      await db.customStatement('''
INSERT INTO sync_clock (tbl_id, pk, col_id, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value, recorded_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT (tbl_id, pk, col_id) DO UPDATE SET hlc = excluded.hlc, node_id = excluded.node_id,
  origin_id = excluded.origin_id, origin_seq = excluded.origin_seq, manifest_id = excluded.manifest_id,
  tomb_value = excluded.tomb_value, cause_tbl_id = NULL, cause_pk = NULL, recorded_at = excluded.recorded_at''',
          [taskTblId, c.pk, c.col, c.hlc, remoteNode, remoteOrigin, c.seq, manifestId, c.tomb, 0]);
    }
    await db.customStatement('UPDATE sync_state SET hlc = MAX(hlc, ?), apply_mode = 0 WHERE id = 1', [remoteBase + 3]);
  });
  expect(applyModeInside, 1);

  final after = await readState(db);
  expect(after.applyMode, 0, reason: 'committed apply_mode (same connection)');
  expect((await readState(other)).applyMode, 0, reason: 'committed apply_mode (other connection)');
  expect(after.nextSeq, before.nextSeq, reason: 'remote apply does not advance next_seq');
  expect(after.hlc, remoteBase + 3, reason: 'receive: hlc = max(local, remote)');
  expect(await cellsWithSeqAbove(db, before.originId, before.nextSeq - 1), isEmpty,
      reason: 'no own-origin cells created');

  for (final c in remoteCells) {
    final cell = (await cellOf(db, taskTblId, c.pk, c.col))!;
    expect((
      cell.hlc,
      cell.nodeId,
      cell.originId,
      cell.originSeq,
      cell.manifestId,
      cell.tombValue
    ), (
      c.hlc,
      remoteNode,
      remoteOrigin,
      c.seq,
      manifestId,
      c.tomb
    ), reason: 'remote cell ${c.pk}/${c.col} verbatim');
  }
  final r1 = await db.customSelect("SELECT title FROM task_table WHERE id = 'r1'").getSingle();
  expect(r1.read<String>('title'), 'Remote title');
  expect(await deletedDateOf(db, 'task_table', 'r2'), remoteDeletedDate, reason: 'deleted_date verbatim');
  expect(await db.customSelect("SELECT 1 FROM sync_clock WHERE pk = 'r2'").get(), hasLength(2),
      reason: 'insert under apply_mode 1 stamps nothing');

  // A failed remote apply rolls back, including apply_mode.
  await expectLater(
    db.transaction(() async {
      await db.customStatement('UPDATE sync_state SET apply_mode = 1 WHERE id = 1');
      throw StateError('simulated apply failure');
    }),
    throwsStateError,
  );
  expect((await readState(other)).applyMode, 0, reason: 'rolled back apply_mode');

  // Next local write ticks past the remote HLC.
  final local = await expectWrite(db, 'local write after remote apply', () async {
    final task = (await tasks.getById('r1'))!;
    task.description = 'local';
    await tasks.update(task);
  }, cellKeys(taskTblId, 'r1', [taskPolicy.columns['description']!]));
  expect(local.single.hlc, greaterThan(remoteBase + 3));
  expect(local.single.originSeq, before.nextSeq);
  spikeLog('remote apply: 3 remote cells verbatim, next_seq unchanged (${before.nextSeq}), committed apply_mode=0');
}

/// Criterion 2 (sequential interleaving): three connections on one file, writes awaited one by one.
Future<void> runMultiConnectionScenario(Directory dir) async {
  final file = File(p.join(dir.path, 'multi_conn.sqlite'));
  final a = openFileDb(file);
  await installSpike(a);
  final b = openFileDb(file);
  final c = openBackgroundFileDb(file);
  final conns = [a, b, c];
  const names = ['A:NativeDatabase', 'B:second NativeDatabase', 'C:createInBackground'];
  try {
    for (var i = 0; i < conns.length; i++) {
      final mode = (await conns[i].customSelect('PRAGMA journal_mode').getSingle()).data.values.single;
      expect(mode, 'wal', reason: '${names[i]} journal_mode');
    }
    spikeLog('multi-connection sqlite_version=${await sqliteVersion(c)} (background isolate)');

    var lastMax = 0;
    var writes = 0;
    Future<void> step(
        int connIndex, String label, Future<void> Function(AppDatabase) write, String pk, int expectedCells) async {
      final db = conns[connIndex];
      await write(db);
      final newMax = (await db.customSelect('SELECT MAX(origin_seq) AS m FROM sync_clock').getSingle()).read<int>('m');
      final cells = (await db.customSelect('SELECT * FROM sync_clock WHERE origin_seq > ? AND origin_seq <= ?',
              variables: [Variable.withInt(lastMax), Variable.withInt(newMax)]).get())
          .map((r) => ClockRow(r.data))
          .toList();
      expect(cells, hasLength(expectedCells), reason: '${names[connIndex]} $label');
      expect(cells.every((cell) => cell.pk == pk), isTrue, reason: '${names[connIndex]} $label seq block');
      expect(newMax, lastMax + expectedCells, reason: 'seq block follows previous commit');
      lastMax = newMax;
      writes++;
    }

    for (var k = 0; k < 12; k++) {
      await step(k % 3, 'repo insert mc-$k', (db) => DriftTaskRepository.withDatabase(db).add(newTask('mc-$k')),
          'mc-$k', allTaskCols().length);
    }
    for (var k = 0; k < 12; k++) {
      final target = 'mc-${(k + 1) % 12}';
      await step(
          k % 3,
          'customUpdate title $target',
          (db) => db.customUpdate('UPDATE task_table SET title = ? WHERE id = ?',
              variables: [Variable<String>('t$k'), Variable<String>(target)], updates: {db.taskTable}),
          target,
          1);
    }
    for (var k = 0; k < 6; k++) {
      await step(k % 3, 'repo insert time record mcr-$k',
          (db) => DriftTaskTimeRecordRepository.withDatabase(db).add(newTimeRecord('mcr-$k', 'mc-0')), 'mcr-$k', 2);
    }

    final all = await allCellsBySeq(b);
    expect(all.map((cell) => cell.originSeq).toSet().length, all.length, reason: 'no duplicate seqs');
    expectStrictlyIncreasingHlc(all, 'multi-connection');
    expect((await readState(c)).nextSeq, lastMax + 1);
    spikeLog('multi-connection: $writes interleaved writes over 3 connections, ${all.length} live cells, '
        'max seq $lastMax, seqs unique and in commit order, HLC strictly increasing by seq');
  } finally {
    await c.close();
    await b.close();
    await a.close();
  }
}

/// Criterion 2 (overflow): 65,537 cells at one pinned wall ms; the last carries into the wall part.
Future<void> runCounterOverflowScenario(AppDatabase db) async {
  await installSpike(db);
  const n = 65537;
  await db.transaction(() async {
    await db.customStatement('UPDATE sync_state SET apply_mode = 4 WHERE id = 1');
    await db.customStatement('''
WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < ${n - 1})
INSERT INTO task_time_record_table (id, task_id, duration, created_date)
SELECT printf('ov-%06d', i), 'ov-task', 0, 1000 FROM n''');
    await db.customStatement('UPDATE sync_state SET apply_mode = 0 WHERE id = 1');
  });
  expect(await db.customSelect('SELECT 1 FROM sync_clock').get(), isEmpty, reason: 'apply_mode 4 stamps nothing');

  final wall = DateTime.now().millisecondsSinceEpoch + 3600000;
  await db.customStatement('UPDATE sync_state SET test_wall_ms = ? WHERE id = 1', [wall]);
  final sw = Stopwatch()..start();
  await db.customStatement('UPDATE task_time_record_table SET duration = duration + 1');
  sw.stop();
  await db.customStatement('UPDATE sync_state SET test_wall_ms = NULL WHERE id = 1');

  final hlcs = (await db.customSelect('SELECT hlc FROM sync_clock ORDER BY origin_seq').get())
      .map((r) => r.read<int>('hlc'))
      .toList();
  expect(hlcs, hasLength(n));
  for (var i = 0; i < n; i++) {
    if (hlcs[i] != (wall << 16) + i) fail('overflow: cell $i hlc ${hlcs[i]} != ${(wall << 16) + i}');
  }
  expect((hlcWall(hlcs[65535]), hlcCounter(hlcs[65535])), (wall, 0xFFFF));
  expect((hlcWall(hlcs[65536]), hlcCounter(hlcs[65536])), (wall + 1, 0));

  // Back on the real clock (now behind the HLC): the next tick is prev + 1.
  final before = await readState(db);
  await db.customStatement("UPDATE task_time_record_table SET duration = -1 WHERE id = 'ov-000000'");
  expect((await readState(db)).hlc, before.hlc + 1);
  spikeLog('counter overflow: $n cells at wall=$wall in ${sw.elapsedMilliseconds} ms; '
      'cell#65535 = (wall, 0xFFFF), cell#65536 = (wall+1, 0); strictly increasing');
}

/// One measured configuration. [options] null = baseline without sync schema or triggers.
class PerfVariant {
  final String name;
  final SpikeSqlOptions? options;
  final bool cachePreparedStatements;
  const PerfVariant(this.name, this.options, {this.cachePreparedStatements = false});
}

const PerfVariant _baseline = PerfVariant('baseline', null);
const PerfVariant _recommended = PerfVariant('triggers(recommended)', SpikeSqlOptions.recommended);

/// Extra variants measured when `S2_PERF_VARIANTS=all` (exploration; not needed for the verdict).
const List<PerfVariant> explorationVariants = [
  PerfVariant('triggers(D1 literal)', SpikeSqlOptions.literal),
  PerfVariant('baseline+stmt-cache', null, cachePreparedStatements: true),
  PerfVariant('triggers(recommended)+stmt-cache', SpikeSqlOptions.recommended, cachePreparedStatements: true),
];

const int _perfRows = 10000;
const int _perfBlock = 500;

class _PerfDb {
  final PerfVariant variant;
  final AppDatabase db;
  final List<String> ids = List.generate(_perfRows, (i) => 'perf-${i.toString().padLeft(5, '0')}');
  int autocommitUs = 0;
  int inTxUs = 0;
  int bulkUs = 0;
  _PerfDb(this.variant, this.db);

  Future<void> updateOne(int i, String prefix) => db.customUpdate('UPDATE task_table SET title = ? WHERE id = ?',
      variables: [Variable<String>('$prefix$i'), Variable<String>(ids[i])], updates: {db.taskTable});
}

Future<_PerfDb> _openPerfDb(File file, PerfVariant variant) async {
  final db = AppDatabase.withExecutor(NativeDatabase.createInBackground(file,
      setup: configureSqliteConnection, cachePreparedStatements: variant.cachePreparedStatements));
  final triggers = variant.options != null;
  if (triggers) await installSpike(db, variant.options!);
  await db.transaction(() async {
    if (triggers) await db.customStatement('UPDATE sync_state SET apply_mode = 4 WHERE id = 1');
    await db.customStatement('''
WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < ${_perfRows - 1})
INSERT INTO task_table (id, title, created_date) SELECT printf('perf-%05d', i), 'seed', 1000 FROM n''');
    if (triggers) await db.customStatement('UPDATE sync_state SET apply_mode = 0 WHERE id = 1');
  });
  return _PerfDb(variant, db);
}

/// Criterion 5: overhead on WAL file DBs (createInBackground + production setup), with vs without triggers.
///
/// All variants are open at once and the 10,000 single-row updates run in blocks of 500 that alternate between
/// variants, so drift in fsync latency over the run affects every variant alike.
Future<void> runOverheadScenario(Directory dir, {required String platformLabel, bool exploration = false}) async {
  final variants = [_baseline, _recommended, if (exploration) ...explorationVariants];
  final dbs = <_PerfDb>[];
  try {
    for (final v in variants) {
      dbs.add(await _openPerfDb(File(p.join(dir.path, 'perf_${dbs.length}.sqlite')), v));
    }
    final sw = Stopwatch();
    // 10,000 single-row updates, each its own (autocommit) transaction, as the app's repository writes are.
    for (var start = 0; start < _perfRows; start += _perfBlock) {
      for (final d in dbs) {
        sw
          ..reset()
          ..start();
        for (var i = start; i < start + _perfBlock; i++) {
          await d.updateOne(i, 'a');
        }
        d.autocommitUs += sw.elapsedMicroseconds;
      }
    }
    // Same updates batched in transactions of 500: isolates the CPU cost from fsync.
    for (var start = 0; start < _perfRows; start += _perfBlock) {
      for (final d in dbs) {
        sw
          ..reset()
          ..start();
        await d.db.transaction(() async {
          for (var i = start; i < start + _perfBlock; i++) {
            await d.updateOne(i, 'b');
          }
        });
        d.inTxUs += sw.elapsedMicroseconds;
      }
    }
    // One 10,000-row bulk UPDATE.
    for (final d in dbs) {
      sw
        ..reset()
        ..start();
      await d.db.customStatement("UPDATE task_table SET title = title || '!'");
      d.bulkUs += sw.elapsedMicroseconds;
    }
    for (final d in dbs.where((d) => d.variant.options != null)) {
      final cells = (await d.db.customSelect('SELECT COUNT(*) AS c FROM sync_clock').getSingle()).read<int>('c');
      expect(cells, _perfRows, reason: '${d.variant.name}: one title cell per task');
      expect((await readState(d.db)).nextSeq - 1, 3 * _perfRows, reason: '${d.variant.name}: 3 x 10,000 cells');
    }
  } finally {
    for (final d in dbs) {
      await d.db.close();
    }
  }

  String ms(int us) => (us / 1000).toStringAsFixed(0);
  String perOp(int us) => (us / _perfRows).toStringAsFixed(1);
  String ratio(int t, int b) => (t / (b == 0 ? 1 : b)).toStringAsFixed(2);
  final base = dbs.firstWhere((d) => d.variant == _baseline);
  final cachedBase = dbs.where((d) => d.variant.name == 'baseline+stmt-cache').firstOrNull;
  spikeLog('overhead [$platformLabel] variant | 10k single-row autocommit | 10k single-row in tx(500) | 10k-row bulk');
  for (final d in dbs) {
    final b = d.variant.cachePreparedStatements && cachedBase != null ? cachedBase : base;
    spikeLog('overhead [$platformLabel] ${d.variant.name} | '
        '${ms(d.autocommitUs)} ms, ${perOp(d.autocommitUs)} us/op, ${ratio(d.autocommitUs, b.autocommitUs)}x | '
        '${ms(d.inTxUs)} ms, ${perOp(d.inTxUs)} us/op, ${ratio(d.inTxUs, b.inTxUs)}x | '
        '${ms(d.bulkUs)} ms, ${ratio(d.bulkUs, b.bulkUs)}x');
  }
  final trig = dbs.firstWhere((d) => d.variant == _recommended);
  expect(trig.autocommitUs, lessThanOrEqualTo(2 * base.autocommitUs), reason: 'single-row autocommit overhead <= 2x');
  expect(trig.bulkUs, lessThan(3000000), reason: '10k bulk update with triggers < 3 s');
}

/// Registers all S2 scenarios. [tempRoot] gives a writable directory on the target platform.
void defineTriggerSpikeTests(SpikeRegistrar register, {required Future<Directory> Function() tempRoot}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<Directory> freshDir(String name) async {
    final root = await tempRoot();
    return Directory(p.join(root.path, 'whph_s2_${name}_${DateTime.now().microsecondsSinceEpoch}'))
      ..createSync(recursive: true);
  }

  Future<void> withDb(AppDatabase db, Future<void> Function(AppDatabase) body) async {
    try {
      await body(db);
    } finally {
      await db.close();
    }
  }

  register('write paths yield exactly the expected cells (in-memory)', () async {
    await withDb(openMemoryDb(), (db) => runWritePathsScenario(db, 'in-memory'));
  });

  register('write paths yield exactly the expected cells (file, WAL)', () async {
    final dir = await freshDir('paths');
    await withDb(openFileDb(File(p.join(dir.path, 'paths.sqlite'))), (db) => runWritePathsScenario(db, 'file'));
    await dir.delete(recursive: true);
  });

  register('duplicate-rowid delete writes no tombstone while the id remains', () async {
    await withDb(openMemoryDb(), runDuplicateRowidScenario);
  });

  register('apply_mode = 1 remote apply writes verbatim and commits apply_mode 0', () async {
    final dir = await freshDir('remote');
    final file = File(p.join(dir.path, 'remote.sqlite'));
    final db = openFileDb(file);
    AppDatabase? other;
    try {
      other = openBackgroundFileDb(file);
      await runRemoteApplyScenario(db, other);
    } finally {
      await other?.close();
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  register('seqs follow commit order across NativeDatabase, second NativeDatabase and createInBackground', () async {
    final dir = await freshDir('multi');
    await runMultiConnectionScenario(dir);
    await dir.delete(recursive: true);
  });

  register('HLC stays strictly increasing across a counter overflow', () async {
    await withDb(openMemoryDb(), runCounterOverflowScenario);
  });

  register('overhead: 10k single-row updates and one 10k-row bulk update', () async {
    final dir = await freshDir('perf');
    await runOverheadScenario(dir,
        platformLabel: Platform.operatingSystem, exploration: Platform.environment['S2_PERF_VARIANTS'] == 'all');
    await dir.delete(recursive: true);
  });
}
