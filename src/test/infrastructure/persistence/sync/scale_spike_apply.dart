/// S3 spike (plan T6): test-only helpers for the scale and performance spike on the synthetic `large_usage`
/// fixture. Used by `src/integration_test/sync_scale_spike_test.dart`; nothing in `src/lib` uses this file.
///
/// Contents:
/// - [ScaleClockShape]: the physical `sync_clock` shapes measured by the PA-1 re-run (D1 literal, the S2
///   recommended text key, and the interned row-key shapes V1/V2).
/// - [ScaleSpikeSchema]: the D1/D3 spike schema on top of [SpikeSyncSchema] (S5) in one of those shapes, plus
///   capture triggers (S2 generator) and the `sync_origin_batch` / `sync_vector` tables the apply writes.
/// - [bootstrapWriterFor] / [measureShapeGrowth]: the D6 bootstrap and the DB-growth measurement per shape.
/// - [verifyShape]: trigger capture and query-plan checks for a shape.
/// - [measureDbSize]: raw (main + WAL after a TRUNCATE checkpoint) and `VACUUM INTO` sizes.
/// - A prototype D7 per-change pipeline (canonical encoding, BLAKE2b-256, manifests of ≤ 1,000 seqs with one
///   Ed25519 signature, XChaCha20-Poly1305 envelopes) and a binary wire record, so sizes and CPU are measured on
///   values drawn from the fixture rows.
/// - [_runScaleWorker]: prepares synthetic remote changes from the fixture (sender side), then applies them in
///   batches (receiver side: verify manifest, decrypt, rehash, then one transaction per batch with a SAVEPOINT per
///   item and `apply_mode = 1`, D4/D15). Runs in a worker isolate either on the shared drift connection
///   ([spawnSharedConnectionRun], `computeWithDatabase`) or on its own connection ([spawnSeparateConnectionRun]).
///
/// Key material is generated inside the worker and never printed or returned. Output is numbers only.
library;

// `cryptography` is resolved through the `whph_sync_core` path dependency (S4); pubspec edits are out of scope
// for this spike.
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sqlite_connection_setup.dart';

import '../../../drift/app_database/generated/schema_v37.dart';
import 'dedupe_spike.dart';
import 'trigger_spike_sql.dart' as trig;

// ---------------------------------------------------------------------------
// Constants (non-secret synthetic identities)
// ---------------------------------------------------------------------------

const String scaleLocalMemberId = 'a0000000000000000000000000000001';
const String scaleLocalOriginHex = 'b0000000000000000000000000000001';
const int scaleProtocolVersion = 2;

/// Cells per manifest (D7) and the D8 batch limit.
const int manifestSize = 1000;

// ---------------------------------------------------------------------------
// Statistics
// ---------------------------------------------------------------------------

/// n, mean, p50, p95, max of [values] (empty → n = 0).
Map<String, num> summarize(List<num> values) {
  if (values.isEmpty) return {'n': 0};
  final sorted = List<num>.of(values)..sort();
  num at(double q) => sorted[min(sorted.length - 1, (q * sorted.length).ceil() - 1).clamp(0, sorted.length - 1)];
  final sum = sorted.fold<num>(0, (a, b) => a + b);
  return {'n': sorted.length, 'mean': sum / sorted.length, 'p50': at(0.5), 'p95': at(0.95), 'max': sorted.last};
}

String formatSummary(Map<String, num> s, {int digits = 1}) {
  if (s['n'] == 0) return 'n=0';
  String f(num v) => v is int ? '$v' : v.toStringAsFixed(digits);
  return 'n=${s['n']} mean=${f(s['mean']!)} p50=${f(s['p50']!)} p95=${f(s['p95']!)} max=${f(s['max']!)}';
}

// ---------------------------------------------------------------------------
// Physical clock shapes (plan PA-1)
// ---------------------------------------------------------------------------

/// Physical `sync_clock` shapes. Every shape keeps the `(origin_id, origin_seq)` index for the sender's cursor
/// read, a primary-key lookup per cell for the merge, and a partial cause index (D5b); the D1 logical model and the
/// wire (names and pk text) are unchanged.
enum ScaleClockShape {
  /// D1 as written: rowid table + `(tbl_id, pk, col_id)` autoindex, full cause index, per-cell triggers.
  d1Literal('d1_literal', trig.SpikeSqlOptions.literal),

  /// S2 recommendation and the previous S3 run: `(tbl_id, pk, col_id)` `WITHOUT ROWID`, partial cause index.
  baseline('baseline', trig.SpikeSqlOptions.recommended),

  /// V1: `sync_row` intern; `sync_clock (row_id, col_id) WITHOUT ROWID`; `cause_row_id` partial index.
  v1Intern('v1_intern', trig.SpikeSqlOptions(rowKey: trig.ClockRowKey.interned)),

  /// V2: `sync_row` intern; rowid `sync_clock` with `key = row_id * 256 + col_id` as INTEGER PRIMARY KEY.
  v2Packed('v2_packed', trig.SpikeSqlOptions(rowKey: trig.ClockRowKey.packed));

  const ScaleClockShape(this.label, this.sqlOptions);
  final String label;
  final trig.SpikeSqlOptions sqlOptions;

  bool get interned => sqlOptions.rowKey != trig.ClockRowKey.text;
  bool get packed => sqlOptions.rowKey == trig.ClockRowKey.packed;

  static ScaleClockShape byLabel(String label) => values.firstWhere((s) => s.label == label);

  /// FROM clause that exposes the clock row as `c` and, for interned shapes, its `sync_row` as `r`.
  String get cellFrom => switch (sqlOptions.rowKey) {
        trig.ClockRowKey.text => 'sync_clock c',
        trig.ClockRowKey.interned => 'sync_clock c JOIN sync_row r ON r.id = c.row_id',
        trig.ClockRowKey.packed => 'sync_clock c JOIN sync_row r ON r.id = c.key >> 8',
      };
  String get tblExpr => interned ? 'r.tbl_id' : 'c.tbl_id';
  String get pkExpr => interned ? 'r.pk' : 'c.pk';
  String get colExpr => packed ? '(c.key & 255)' : 'c.col_id';

  /// Join condition from a `sync_row r` to its clock rows `c` (interned shapes).
  String get rowToClock => packed
      ? 'c.key BETWEEN r.id * ${trig.packedKeyFactor} AND r.id * ${trig.packedKeyFactor} + ${trig.packedKeyFactor - 1}'
      : 'c.row_id = r.id';
}

/// Table-level policy variants for the growth measurement (plan fallback (i)).
enum ScalePolicyVariant {
  /// D1 as written (field-level: task, habit, note, tag, task_status, setting, app_usage).
  d1('d1'),

  /// `setting` row-level: its only user-editable synced column besides the identity key is `value` (`value_type`
  /// is written together with it). Every other field-level table has several independently editable columns.
  settingRowLevel('setting_row_level'),

  /// Every table row-level (`*` + `~`). Information only: violates FR-002 / Scenario 1.1.
  allRowLevel('all_row_level');

  const ScalePolicyVariant(this.label);
  final String label;

  List<SpikeTablePolicy> get tables => [
        for (final p in spikeSyncedTables)
          switch (this) {
            d1 => p,
            settingRowLevel => p.table == 'setting_table' ? SpikeTablePolicy(p.tblId, p.table, fieldLevel: false) : p,
            allRowLevel => SpikeTablePolicy(p.tblId, p.table, fieldLevel: false),
          }
      ];
}

// ---------------------------------------------------------------------------
// Schema
// ---------------------------------------------------------------------------

abstract final class ScaleSpikeSchema {
  /// Installs the spike sync schema in [shape]. Text shapes reuse [SpikeSyncSchema.install] (S5) and, for
  /// [ScaleClockShape.baseline], replace its clock table and cause index by the S2 recommendation; interned shapes
  /// create `sync_row` + `sync_clock` from the S2 generator ([trig.clockSchemaStatements]). All shapes add the
  /// `(origin_id, origin_seq)` cursor index. With [withTriggers] the S2 capture triggers (same shape) are installed
  /// on `task_table` and the row-level tables the apply writes, using the S5 table ids and the levels of [tables].
  static Future<void> install(GeneratedDatabase db,
      {required ScaleClockShape shape,
      required bool withTriggers,
      List<SpikeTablePolicy> tables = spikeSyncedTables}) async {
    if (shape == ScaleClockShape.baseline) {
      for (final sql in trig.clockSchemaStatements(shape.sqlOptions)) {
        await db.customStatement(sql);
      }
    }
    await SpikeSyncSchema.install(db,
        memberId: scaleLocalMemberId, originId: scaleLocalOriginHex, withClockTable: !shape.interned);
    if (shape == ScaleClockShape.baseline) {
      // S5 created its full cause index on the existing table; the partial one above replaces it.
      await db.customStatement('DROP INDEX IF EXISTS sync_clock_cause');
    }
    if (shape.interned) {
      for (final sql in trig.clockSchemaStatements(shape.sqlOptions)) {
        await db.customStatement(sql);
      }
      await db.customStatement('CREATE INDEX IF NOT EXISTS sync_clock_origin ON sync_clock (origin_id, origin_seq)');
    }
    await db.customStatement('''
CREATE TABLE IF NOT EXISTS sync_origin_batch (
  manifest_id INTEGER PRIMARY KEY,
  origin_id INTEGER NOT NULL,
  from_seq INTEGER NOT NULL,
  to_seq INTEGER NOT NULL,
  hashes BLOB NOT NULL,
  sig BLOB NOT NULL
)''');
    await db.customStatement(
        'CREATE TABLE IF NOT EXISTS sync_vector (origin_id INTEGER PRIMARY KEY, cursor INTEGER NOT NULL)');
    if (!withTriggers) return;

    // The S2 triggers read node_id/origin_id/cascade cause/test_wall_ms from sync_state.
    for (final column in const [
      'node_id INTEGER',
      'origin_id INTEGER',
      'cascade_cause_tbl_id INTEGER',
      'cascade_cause_pk TEXT',
      'test_wall_ms INTEGER',
    ]) {
      await db.customStatement('ALTER TABLE sync_state ADD COLUMN $column');
    }
    await db.customStatement('UPDATE sync_state SET node_id = member_node_id, origin_id = local_origin_id');
    final policies = <trig.SpikeTablePolicy>[];
    for (final p in tables.where((p) => p.table == 'task_table' || const {8, 9, 10}.contains(p.tblId))) {
      if (p.table == 'task_table' && p.fieldLevel) {
        policies.add(trig.taskPolicy);
        continue;
      }
      final columns = await _syncedColumns(db, p.table);
      policies.add(trig.SpikeTablePolicy(
        tableName: p.table,
        tblId: p.tblId,
        rowLevel: !p.fieldLevel,
        columns: {for (var i = 0; i < columns.length; i++) columns[i]: i + 1},
      ));
    }
    for (final policy in policies) {
      if (shape.packed && policy.columns.values.any((c) => c >= trig.packedKeyFactor)) {
        throw StateError('${policy.tableName}: col id >= ${trig.packedKeyFactor} does not fit the packed key');
      }
      for (final sql in trig.spikeTriggerStatements(policy, shape.sqlOptions)) {
        await db.customStatement(sql);
      }
    }
  }
}

/// D6 bootstrap writer for the interned shapes (null for text shapes: [DedupeSpikeJob]'s own SQL). Per chunk: intern
/// the chunk's rows in pk order (`ON CONFLICT DO NOTHING`), then one `INSERT … SELECT` of every cell joined to its
/// `sync_row` id, seqs in `(pk, col_id)` order as in the text shape.
BootstrapChunkWriter? bootstrapWriterFor(ScaleClockShape shape) {
  if (!shape.interned) return null;
  return (db, chunk) async {
    final table = chunk.policy.table;
    if (shape.packed && chunk.colIds.any((c) => c >= trig.packedKeyFactor)) {
      throw StateError('$table: col id >= ${trig.packedKeyFactor} does not fit the packed key');
    }
    await db.customStatement(
        'INSERT INTO sync_row (tbl_id, pk) SELECT ?, id FROM "$table" WHERE id > ? AND id <= ? ORDER BY id '
        'ON CONFLICT (tbl_id, pk) DO NOTHING',
        [chunk.policy.tblId, chunk.from, chunk.lastId]);
    final exists = shape.packed
        ? 's.key = r.row_id * ${trig.packedKeyFactor} + cols.col_id'
        : 's.row_id = r.row_id AND s.col_id = cols.col_id';
    final keyColumns = shape.packed ? 'key' : 'row_id, col_id';
    final keyValues = shape.packed ? 'row_id * ${trig.packedKeyFactor} + col_id' : 'row_id, col_id';
    await db.customStatement('''
WITH r AS (
  SELECT b.id, sr.id AS row_id, b.created_date, b.modified_date, b.deleted_date
  FROM "$table" b JOIN sync_row sr ON sr.tbl_id = ? AND sr.pk = b.id
  WHERE b.id > ? AND b.id <= ?
),
cols(col_id) AS (VALUES ${chunk.colIds.map((c) => '($c)').join(', ')}),
cells AS (
  SELECT r.id AS pk, r.row_id AS row_id, cols.col_id AS col_id,
         (MAX(r.created_date, COALESCE(r.modified_date, 0), COALESCE(r.deleted_date, 0)) * 1000) << 16 AS hlc,
         CASE WHEN cols.col_id = $tombstoneColId THEN r.deleted_date END AS tomb
  FROM r CROSS JOIN cols
  WHERE NOT EXISTS (SELECT 1 FROM sync_clock s WHERE $exists)
)
INSERT INTO sync_clock
  ($keyColumns, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value, cause_row_id, recorded_at)
SELECT $keyValues, hlc, ?, ?, ? + ROW_NUMBER() OVER (ORDER BY pk, col_id) - 1, NULL, tomb, NULL, ?
FROM cells ORDER BY pk, col_id''', [
      chunk.policy.tblId,
      chunk.from,
      chunk.lastId,
      chunk.nodeId,
      chunk.originId,
      chunk.baseSeq,
      chunk.recordedAt,
    ]);
    final inserted = (await db.customSelect('SELECT changes() AS c').get()).single.data['c'] as int;
    if (inserted == 0) return (0, 0);
    final maxHlc = (await db.customSelect(
      'SELECT MAX((MAX(created_date, COALESCE(modified_date, 0), COALESCE(deleted_date, 0)) * 1000) << 16) AS h '
      'FROM "$table" WHERE id > ? AND id <= ?',
      variables: [Variable<String>(chunk.from), Variable<String>(chunk.lastId)],
    ).get())
        .single
        .data['h'] as int;
    return (inserted, maxHlc);
  };
}

/// Clock rows per S5 table id.
Future<Map<int, int>> clockRowsPerTable(GeneratedDatabase db, ScaleClockShape shape) async => {
      for (final r in await db
          .customSelect('SELECT ${shape.tblExpr} AS tbl_id, COUNT(*) AS n FROM ${shape.cellFrom} GROUP BY 1 ORDER BY 1')
          .get())
        r.data['tbl_id'] as int: r.data['n'] as int
    };

/// FK indexes that S5 (spike note, "Timings") recommends for the v38 DDL; the fresh-install v37 schema of the
/// fixture has none. Without `task_time_record_table(task_id)` the task list's total-duration subquery scans the
/// whole time-record table per task.
const List<String> v38FkIndexStatements = [
  'CREATE INDEX IF NOT EXISTS s3_task_tag_task_id ON task_tag_table (task_id)',
  'CREATE INDEX IF NOT EXISTS s3_task_time_record_task_id ON task_time_record_table (task_id)',
  'CREATE INDEX IF NOT EXISTS s3_task_parent_task_id ON task_table (parent_task_id)',
  'CREATE INDEX IF NOT EXISTS s3_task_recurrence_parent_id ON task_table (recurrence_parent_id)',
  'CREATE INDEX IF NOT EXISTS s3_task_status_id ON task_table (status_id)',
];

/// Bytes per table/index from the `dbstat` virtual table, largest first; null when SQLite lacks DBSTAT.
Future<List<(String, int)>?> dbstatBreakdown(GeneratedDatabase db) async {
  try {
    final rows =
        await db.customSelect('SELECT name, SUM(pgsize) AS bytes FROM dbstat GROUP BY name ORDER BY bytes DESC').get();
    return [for (final r in rows) (r.data['name'] as String, r.data['bytes'] as int)];
  } catch (_) {
    return null;
  }
}

Future<List<String>> _columns(GeneratedDatabase db, String table) async =>
    [for (final r in await db.customSelect('PRAGMA table_info("$table")').get()) r.data['name'] as String];

Future<List<String>> _syncedColumns(GeneratedDatabase db, String table) async =>
    (await _columns(db, table)).where((c) => !auditColumns.contains(c)).toList();

// ---------------------------------------------------------------------------
// Sizes
// ---------------------------------------------------------------------------

class DbSize {
  DbSize(this.mainBytes, this.walBytes, this.vacuumBytes);
  final int mainBytes;
  final int walBytes;
  final int vacuumBytes;
  int get rawBytes => mainBytes + walBytes;
}

/// TRUNCATE checkpoint, then the main file + WAL sizes, then the size of a `VACUUM INTO` copy (deleted again).
Future<DbSize> measureDbSize(GeneratedDatabase db, String dbPath, String scratchPath) async {
  await db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
  final main = File(dbPath).lengthSync();
  final walFile = File('$dbPath-wal');
  final wal = walFile.existsSync() ? walFile.lengthSync() : 0;
  final target = File(scratchPath);
  if (target.existsSync()) target.deleteSync();
  await db.customStatement("VACUUM INTO '${scratchPath.replaceAll("'", "''")}'");
  final vacuum = target.lengthSync();
  target.deleteSync();
  return DbSize(main, wal, vacuum);
}

/// Stores one manifest row per [manifestSize] own seqs (random 32-byte hashes, random 64-byte signature; only the
/// size matters) and points every own clock row at it, like the state after the first send (D7).
Future<int> addOwnManifestsForSize(GeneratedDatabase db) async {
  final state = (await db.customSelect('SELECT local_origin_id, next_seq FROM sync_state WHERE id = 1').get()).single;
  final origin = state.data['local_origin_id'] as int;
  final lastSeq = (state.data['next_seq'] as int) - 1;
  var manifests = 0;
  await db.transaction(() async {
    for (var from = 0; from < lastSeq; from += manifestSize) {
      final to = min(from + manifestSize, lastSeq);
      await db.customStatement(
        'INSERT INTO sync_origin_batch (origin_id, from_seq, to_seq, hashes, sig) '
        'VALUES (?, ?, ?, randomblob(?), randomblob(64))',
        [origin, from, to, 32 * (to - from)],
      );
      manifests++;
    }
    final first = (await db.customSelect('SELECT MIN(manifest_id) AS m FROM sync_origin_batch WHERE origin_id = ?',
            variables: [Variable<int>(origin)]).get())
        .single
        .data['m'] as int;
    // Manifest k (0-based) covers seqs (k * size, (k + 1) * size], and ids were assigned consecutively above.
    await db.customStatement(
      'UPDATE sync_clock SET manifest_id = ? + (origin_seq - 1) / ? WHERE origin_id = ?',
      [first, manifestSize, origin],
    );
  });
  return manifests;
}

/// Bytes per table/index of the `VACUUM INTO` copy of [db] (attached as `vac`, measured with `dbstat`, deleted
/// again); null when SQLite lacks DBSTAT. These are the per-object bytes behind the VACUUM growth ratio.
Future<List<(String, int)>?> dbstatOfVacuumCopy(GeneratedDatabase db, String scratchPath) async {
  final target = File(scratchPath);
  if (target.existsSync()) target.deleteSync();
  await db.customStatement("VACUUM INTO '${scratchPath.replaceAll("'", "''")}'");
  await db.customStatement("ATTACH DATABASE '${scratchPath.replaceAll("'", "''")}' AS vac");
  try {
    final rows = await db
        .customSelect("SELECT name, SUM(pgsize) AS bytes FROM dbstat('vac') GROUP BY name ORDER BY bytes DESC")
        .get();
    return [for (final r in rows) (r.data['name'] as String, r.data['bytes'] as int)];
  } catch (_) {
    return null;
  } finally {
    await db.customStatement('DETACH DATABASE vac');
    target.deleteSync();
  }
}

/// Sync-side objects of a [dbstatOfVacuumCopy] breakdown (`sync_*` tables/indexes, their autoindexes and the
/// schema table) plus the sum of every other object as `user_tables_and_indexes`.
Map<String, int> syncObjectBytes(List<(String, int)> breakdown) {
  final out = <String, int>{};
  var user = 0;
  for (final (name, bytes) in breakdown) {
    final sync = name.startsWith('sync_') && name != 'sync_device_table' ||
        name.startsWith('sqlite_autoindex_sync_') && !name.startsWith('sqlite_autoindex_sync_device_table') ||
        name == 'sqlite_schema' ||
        name == 'sqlite_master';
    if (sync) {
      out[name] = bytes;
    } else {
      user += bytes;
    }
  }
  out['user_tables_and_indexes'] = user;
  return out;
}

/// DB growth of [shape] × [policy] on a copy of [fixture]: install (with triggers and the v38 FK indexes), D17 job
/// (dedupe + bootstrap), then sizes after bootstrap and after storing own manifests, as in the first S3 run.
Future<Map<String, Object?>> measureShapeGrowth({
  required File fixture,
  required ScaleClockShape shape,
  required ScalePolicyVariant policy,
  required Directory scratch,
  required int groupsPerChunk,
}) async {
  final path = '${scratch.path}/growth_${shape.label}_${policy.label}.sqlite';
  fixture.copySync(path);
  final db = DatabaseAtV37(
      NativeDatabase.createInBackground(File(path), setup: configureSqliteConnection, cachePreparedStatements: true));
  final m = <String, Object?>{'shape': shape.label, 'policy': policy.label};
  try {
    final pre = await measureDbSize(db, path, '$path.vac');
    await ScaleSpikeSchema.install(db, shape: shape, withTriggers: true, tables: policy.tables);
    for (final sql in v38FkIndexStatements) {
      await db.customStatement(sql);
    }
    final timings = <ChunkTiming>[];
    await DedupeSpikeJob(db,
            nowMs: DateTime.now().millisecondsSinceEpoch,
            groupsPerChunk: groupsPerChunk,
            onChunk: timings.add,
            syncedTables: policy.tables,
            bootstrapWriter: bootstrapWriterFor(shape))
        .run();
    final summary = ChunkTimingSummary(timings);
    final clockRows = (await db.customSelect('SELECT COUNT(*) AS n FROM sync_clock').get()).single.data['n'] as int;
    final post = await measureDbSize(db, path, '$path.vac');
    final breakdown = await dbstatOfVacuumCopy(db, '$path.vac');
    final manifests = await addOwnManifestsForSize(db);
    final withManifests = await measureDbSize(db, path, '$path.vac');
    m.addAll({
      'clock_rows': clockRows,
      'bootstrap_ms': summary.total(SpikeSyncSchema.phaseBootstrap).inMilliseconds,
      'bootstrap_max_chunk_ms': (summary.slowest(SpikeSyncSchema.phaseBootstrap)?.elapsed.inMicroseconds ?? 0) / 1000,
      'pre_vacuum_bytes': pre.vacuumBytes,
      'post_raw_bytes': post.rawBytes,
      'post_vacuum_bytes': post.vacuumBytes,
      'raw_ratio': post.rawBytes / pre.rawBytes,
      'vacuum_ratio': post.vacuumBytes / pre.vacuumBytes,
      'bytes_per_clock_row': (post.vacuumBytes - pre.vacuumBytes) / clockRows,
      'manifests': manifests,
      'with_manifests_vacuum_bytes': withManifests.vacuumBytes,
      'with_manifests_vacuum_ratio': withManifests.vacuumBytes / pre.vacuumBytes,
      'dbstat': breakdown == null
          ? 'unavailable'
          : syncObjectBytes(breakdown).entries.map((e) => '${e.key}:${e.value}').join(' '),
    });
    return m;
  } finally {
    await db.close();
    for (final suffix in ['', '-wal', '-shm', '.vac']) {
      final f = File('$path$suffix');
      if (f.existsSync()) f.deleteSync();
    }
  }
}

class _Rollback implements Exception {}

/// Checks [shape] on a bootstrapped DB and leaves it unchanged (everything runs in a rolled-back transaction):
/// - query plans: the sender's cursor read by `(origin_id, origin_seq > cursor)` uses `sync_clock_origin` without a
///   sort; the per-cell lookup and the merge prefetch search by key; the cause lookup (D5b) uses the partial index;
/// - trigger capture (S2, PA-3 shape): an edit writes exactly the changed cell of that row; an insert interns the new
///   row and writes every cell; a soft delete under a cascade cause writes `~` with the cause resolved to the cause
///   row; `apply_mode = 1` writes nothing.
/// Returns the plans and observations; throws [StateError] on the first failed check.
Future<Map<String, Object?>> verifyShape(GeneratedDatabase db, ScaleClockShape shape) async {
  final out = <String, Object?>{};
  Future<String> plan(String sql, List<Object?> args) async => [
        for (final r
            in await db.customSelect('EXPLAIN QUERY PLAN $sql', variables: [for (final a in args) _variable(a)]).get())
          r.data['detail'] as String
      ].join(' | ');
  void check(bool ok, String what) {
    if (!ok) throw StateError('verifyShape(${shape.label}): $what');
  }

  final sender = await plan(
      'SELECT ${shape.tblExpr}, ${shape.pkExpr}, ${shape.colExpr}, c.hlc, c.node_id, c.origin_seq, c.manifest_id '
      'FROM ${shape.cellFrom} WHERE c.origin_id = ? AND c.origin_seq > ? ORDER BY c.origin_seq LIMIT 1000',
      [1, 5]);
  out['plan.sender_cursor'] = sender;
  check(sender.contains('sync_clock_origin') && !sender.contains('TEMP B-TREE'), 'sender cursor read: $sender');

  final String lookupSql;
  if (!shape.interned) {
    lookupSql = 'SELECT c.hlc FROM sync_clock c WHERE c.tbl_id = ? AND c.pk = ? AND c.col_id = ?';
  } else if (shape.packed) {
    lookupSql = 'SELECT c.hlc FROM sync_row r JOIN sync_clock c ON c.key = r.id * ${trig.packedKeyFactor} + ? '
        'WHERE r.tbl_id = ? AND r.pk = ?';
  } else {
    lookupSql = 'SELECT c.hlc FROM sync_row r JOIN sync_clock c ON c.row_id = r.id AND c.col_id = ? '
        'WHERE r.tbl_id = ? AND r.pk = ?';
  }
  final lookup = await plan(lookupSql, shape.interned ? [2, 1, 'x'] : [1, 'x', 2]);
  out['plan.cell_lookup'] = lookup;
  check(!lookup.contains('SCAN'), 'cell lookup: $lookup');

  final cause = await plan(
      shape.interned
          ? 'SELECT ${shape.colExpr} FROM sync_clock c WHERE c.cause_row_id = '
              '(SELECT id FROM sync_row WHERE tbl_id = ? AND pk = ?)'
          : 'SELECT c.col_id FROM sync_clock c WHERE c.cause_tbl_id = ? AND c.cause_pk = ?',
      [1, 'x']);
  out['plan.cause_lookup'] = cause;
  check(cause.contains('sync_clock_cause_idx') || cause.contains('sync_clock_cause '), 'cause lookup: $cause');

  if (shape.interned) {
    final prefetch = await plan(
        'SELECT r.pk, r.id, ${shape.colExpr}, c.hlc FROM sync_row r LEFT JOIN sync_clock c ON ${shape.rowToClock} '
        'WHERE r.tbl_id = ? AND r.pk IN (?, ?)',
        [1, 'x', 'y']);
    out['plan.merge_prefetch'] = prefetch;
    check(!prefetch.contains('SCAN'), 'merge prefetch: $prefetch');
  }

  Future<int> scalar(String sql, [List<Object?> args = const []]) async =>
      (await db.customSelect(sql, variables: [for (final a in args) _variable(a)]).get()).single.data.values.first
          as int;
  Future<List<(int, String, int, Object?)>> cellsFrom(int seq) async => [
        for (final r in await db.customSelect(
            'SELECT ${shape.tblExpr} AS t, ${shape.pkExpr} AS p, ${shape.colExpr} AS col, '
            '${shape.interned ? '(SELECT cr.pk FROM sync_row cr WHERE cr.id = c.cause_row_id)' : 'c.cause_pk'} AS cause '
            'FROM ${shape.cellFrom} WHERE c.origin_seq >= ? ORDER BY c.origin_seq',
            variables: [Variable<int>(seq)]).get())
          (r.data['t'] as int, r.data['p'] as String, r.data['col'] as int, r.data['cause'])
      ];

  try {
    await db.transaction(() async {
      final existing =
          (await db.customSelect('SELECT id FROM task_table WHERE deleted_date IS NULL ORDER BY id LIMIT 1').get())
              .single
              .data['id'] as String;
      var seq = await scalar('SELECT next_seq FROM sync_state WHERE id = 1');

      await db.customStatement('UPDATE task_table SET title = title || ? WHERE id = ?', [' (s3 check)', existing]);
      var cells = await cellsFrom(seq);
      out['capture.edit'] = cells.map((c) => '${c.$1}/${c.$3}').join(',');
      check(cells.length == 1 && cells.single.$2 == existing && cells.single.$3 == trig.taskPolicy.columns['title'],
          'edit capture: $cells');

      seq = await scalar('SELECT next_seq FROM sync_state WHERE id = 1');
      const newId = 's3-verify-new-task';
      await db.customStatement(
          'INSERT INTO task_table (id, title, created_date, planned_date_reminder_time, deadline_date_reminder_time, '
          'recurrence_type, "order") VALUES (?, ?, 1, 0, 0, 0, ?)',
          [newId, 'S3 verify', 'zzzz']);
      cells = await cellsFrom(seq);
      out['capture.insert_cells'] = cells.length;
      check(cells.length == trig.taskPolicy.columns.length + 1 && cells.every((c) => c.$2 == newId),
          'insert capture: ${cells.length} cells');
      if (shape.interned) {
        check(await scalar('SELECT COUNT(*) FROM sync_row WHERE tbl_id = 1 AND pk = ?', [newId]) == 1,
            'insert did not intern the row');
      }

      seq = await scalar('SELECT next_seq FROM sync_state WHERE id = 1');
      await db.customStatement(
          'UPDATE sync_state SET cascade_cause_tbl_id = 1, cascade_cause_pk = ? WHERE id = 1', [existing]);
      await db.customStatement('UPDATE task_table SET deleted_date = 2 WHERE id = ?', [newId]);
      await db
          .customStatement('UPDATE sync_state SET cascade_cause_tbl_id = NULL, cascade_cause_pk = NULL WHERE id = 1');
      cells = await cellsFrom(seq);
      out['capture.cascade_delete'] = cells.map((c) => '${c.$3}<-${c.$4}').join(',');
      check(cells.length == 1 && cells.single.$3 == tombstoneColId && cells.single.$4 == existing,
          'cascade delete capture: $cells');

      seq = await scalar('SELECT next_seq FROM sync_state WHERE id = 1');
      await db.customStatement('UPDATE sync_state SET apply_mode = 1 WHERE id = 1');
      await db.customStatement('UPDATE task_table SET title = ? WHERE id = ?', ['remote', existing]);
      await db.customStatement('UPDATE sync_state SET apply_mode = 0 WHERE id = 1');
      check((await cellsFrom(seq)).isEmpty, 'apply_mode = 1 captured cells');
      throw _Rollback();
    });
  } on _Rollback {
    // Expected: the checks leave the database unchanged.
  }
  return out;
}

// ---------------------------------------------------------------------------
// Binary codec (prototype; T10 owns the real canonical encoding)
// ---------------------------------------------------------------------------

int varintLength(int v) {
  var n = 1;
  while (v >= 0x80) {
    v >>= 7;
    n++;
  }
  return n;
}

class _Writer {
  final BytesBuilder _b = BytesBuilder(copy: false);
  final Uint8List _u64 = Uint8List(8);

  void varint(int v) {
    while (v >= 0x80) {
      _b.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    _b.addByte(v);
  }

  void bytes(List<int> v) {
    varint(v.length);
    _b.add(v);
  }

  void raw(List<int> v) => _b.add(v);
  void str(String s) => bytes(utf8.encode(s));

  void u64(int v) {
    ByteData.sublistView(_u64).setUint64(0, v);
    _b.add(Uint8List.fromList(_u64));
  }

  Uint8List take() => _b.takeBytes();
}

class _Reader {
  _Reader(this.data);
  final Uint8List data;
  int offset = 0;

  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final byte = data[offset++];
      result |= (byte & 0x7f) << shift;
      if (byte < 0x80) return result;
      shift += 7;
    }
  }

  Uint8List raw(int n) {
    final v = Uint8List.sublistView(data, offset, offset + n);
    offset += n;
    return v;
  }

  Uint8List bytes() => raw(varint());
  String str() => utf8.decode(bytes());

  int u64() {
    final v = ByteData.sublistView(data, offset, offset + 8).getUint64(0);
    offset += 8;
    return v;
  }
}

/// Canonical change (D7): group ‖ tbl ‖ pk ‖ col ‖ value ‖ hlc ‖ node ‖ origin ‖ seq ‖ cause(absent).
Uint8List _canonical(Uint8List group, String tbl, String pk, String col, List<int> value, int hlc, String node,
    Uint8List origin, int seq) {
  final w = _Writer()
    ..raw(group)
    ..str(tbl)
    ..str(pk)
    ..str(col)
    ..bytes(value)
    ..u64(hlc)
    ..str(node)
    ..raw(origin)
    ..varint(seq)
    ..varint(0);
  return w.take();
}

/// Envelope AD (D7): group ‖ epoch ‖ tbl ‖ pk ‖ col ‖ hlc ‖ origin ‖ seq ‖ cause(absent) ‖ protocol version.
Uint8List _ad(Uint8List group, int epochCounter, String epochCreator, String tbl, String pk, String col, int hlc,
    Uint8List origin, int seq) {
  final w = _Writer()
    ..raw(group)
    ..varint(epochCounter)
    ..str(epochCreator)
    ..str(tbl)
    ..str(pk)
    ..str(col)
    ..u64(hlc)
    ..raw(origin)
    ..varint(seq)
    ..varint(0)
    ..varint(scaleProtocolVersion);
  return w.take();
}

/// Bytes of one wire record without the ciphertext: tbl, pk, col, hlc, node, origin(16), seq, cause(absent),
/// epoch (counter, creator), nonce(24), ciphertext length prefix. Ciphertext = value + 16-byte tag.
int wireRecordLength(String tbl, String pk, String col, int valueLength, String node, int seq, String epochCreator) {
  int strLen(String s) {
    final n = utf8.encode(s).length;
    return varintLength(n) + n;
  }

  final ct = valueLength + 16;
  return strLen(tbl) +
      strLen(pk) +
      strLen(col) +
      8 +
      strLen(node) +
      16 +
      varintLength(seq) +
      1 +
      varintLength(1) +
      strLen(epochCreator) +
      24 +
      varintLength(ct) +
      ct;
}

/// Wire bytes of one manifest: origin(16) ‖ from ‖ to ‖ hashes ‖ signature(64).
int manifestWireLength(int from, int to) => 16 + 8 + 8 + 32 * (to - from) + 64;

// ---------------------------------------------------------------------------
// Worker configuration and messages
// ---------------------------------------------------------------------------

/// Sendable parameters of one apply run.
class ScaleRunConfig {
  const ScaleRunConfig({
    required this.label,
    required this.runIndex,
    required this.changes,
    required this.batchSize,
    required this.shape,
    this.measureFullState = false,
  });

  final String label;

  /// Physical clock shape of the database (the apply interns row keys for the interned shapes).
  final ScaleClockShape shape;

  /// Distinguishes the synthetic remote origin, sampled cells and new-row ids of each run.
  final int runIndex;
  final int changes;
  final int batchSize;

  /// Also computes the exact wire size of the whole bootstrapped state (every own cell).
  final bool measureFullState;
}

/// Worker → main events: `{'event': 'applyStart'|'applyDone', 'us': Timeline-free wall µs}`.
const String eventApplyStart = 'applyStart';
const String eventApplyDone = 'applyDone';

/// Runs [cfg] in a new isolate on the **same** drift connection as [db] (drift `computeWithDatabase`): the worker
/// does the CPU work, and its batch transactions serialize with every other statement on that connection.
Future<Map<String, Object?>> spawnSharedConnectionRun(DatabaseAtV37 db, ScaleRunConfig cfg, SendPort events) =>
    db.computeWithDatabase(connect: DatabaseAtV37.new, computation: _sharedComputation(cfg, events));

Future<Map<String, Object?>> Function(DatabaseAtV37) _sharedComputation(ScaleRunConfig cfg, SendPort events) =>
    (db) => _runScaleWorker(db, cfg, events, _SharedTx(db));

/// Runs [cfg] in a new isolate with its **own** connection to [dbPath] (production `setup:`; WAL, busy_timeout).
Future<Map<String, Object?>> spawnSeparateConnectionRun(String dbPath, ScaleRunConfig cfg, SendPort events) =>
    Isolate.run(() => _separateRun(dbPath, cfg, events));

Future<Map<String, Object?>> _separateRun(String dbPath, ScaleRunConfig cfg, SendPort events) async {
  final db =
      DatabaseAtV37(NativeDatabase(File(dbPath), setup: configureSqliteConnection, cachePreparedStatements: true));
  try {
    return await _runScaleWorker(db, cfg, events, _SeparateTx(db));
  } finally {
    await db.close();
  }
}

class _Stmt {
  const _Stmt(this.sql, this.args);
  final String sql;
  final List<Object?> args;
}

abstract class _ApplyTx {
  Future<void> run(Future<void> Function() body);
  Future<void> item(List<_Stmt> statements);
  int busyRetries = 0;
}

/// Shared drift connection: drift transaction + one drift batch (one isolate round trip) per item.
class _SharedTx extends _ApplyTx {
  _SharedTx(this.db);
  final GeneratedDatabase db;

  @override
  Future<void> run(Future<void> Function() body) => db.transaction(body);

  @override
  Future<void> item(List<_Stmt> statements) => db.batch((b) {
        for (final s in statements) {
          b.customStatement(s.sql, s.args);
        }
      });
}

bool isBusyError(Object e) =>
    (e is SqliteException && e.resultCode == 5) ||
    e.toString().contains('database is locked') ||
    e.toString().contains('SQLITE_BUSY');

/// Own connection: `BEGIN IMMEDIATE` (retried on SQLITE_BUSY at the Dart level, see the busy_timeout caveat),
/// statements executed directly on the worker isolate.
class _SeparateTx extends _ApplyTx {
  _SeparateTx(this.db);
  final GeneratedDatabase db;

  Future<void> _retryBusy(String sql) async {
    final sw = Stopwatch()..start();
    while (true) {
      try {
        await db.customStatement(sql);
        return;
      } catch (e) {
        if (!isBusyError(e) || sw.elapsed > const Duration(seconds: 30)) rethrow;
        busyRetries++;
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }
  }

  @override
  Future<void> run(Future<void> Function() body) async {
    await _retryBusy('BEGIN IMMEDIATE');
    try {
      await body();
    } catch (_) {
      await db.customStatement('ROLLBACK');
      rethrow;
    }
    await _retryBusy('COMMIT');
  }

  @override
  Future<void> item(List<_Stmt> statements) async {
    for (final s in statements) {
      await db.customStatement(s.sql, s.args);
    }
  }
}

// ---------------------------------------------------------------------------
// Worker
// ---------------------------------------------------------------------------

class _TableMeta {
  _TableMeta(this.policy, this.synced);
  final SpikeTablePolicy policy;
  final List<String> synced;
  int get tblId => policy.tblId;
  String get table => policy.table;
  bool get fieldLevel => policy.fieldLevel;

  String colName(int colId) => colId == tombstoneColId ? '~' : (fieldLevel ? synced[colId - 1] : '*');
}

class _Source {
  _Source(this.meta, this.pk, this.colId, this.value);
  final _TableMeta meta;
  final String pk;
  final int colId;
  final Uint8List value;
}

class _Manifest {
  _Manifest(this.from, this.to, this.body, this.signature);
  final int from;
  final int to;

  /// Signed bytes: group ‖ origin ‖ from ‖ to ‖ hashes.
  final Uint8List body;
  final List<int> signature;
  int? storedId;
  bool verified = false;
}

const int _manifestHeader = 16 + 16 + 8 + 8;

Uint8List _manifestBody(Uint8List group, Uint8List origin, int from, int to, List<Uint8List> hashes) {
  final out = Uint8List(_manifestHeader + (to - from) * 32);
  out.setRange(0, 16, group);
  out.setRange(16, 32, origin);
  final view = ByteData.sublistView(out);
  view.setUint64(32, from);
  view.setUint64(40, to);
  for (var s = from; s < to; s++) {
    out.setRange(_manifestHeader + (s - from) * 32, _manifestHeader + (s - from + 1) * 32, hashes[s]);
  }
  return out;
}

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Object? _jsonSafe(Object? v) => v is Uint8List ? base64.encode(v) : v;

const DartBlake2b _blake2b256 = DartBlake2b(hashLengthInBytes: 32);
const DartXchacha20 _xchacha = DartXchacha20.poly1305Aead();
final DartEd25519 _ed25519 = DartEd25519(sha512: const DartSha512());

double _ms(int us) => us / 1000;

/// Prepares [ScaleRunConfig.changes] synthetic remote changes from the fixture and applies them. Half are updates
/// of existing cells (every k-th own clock cell, so every table appears in proportion to its cell count, values =
/// the current cell value, `*` durations + 1); half are inserts of new row-level rows (`*` + `~`, cloned from
/// row-level rows in proportion to row counts). The synthetic peer authors them under a fresh origin with seqs 1..n
/// and HLCs above every local clock.
Future<Map<String, Object?>> _runScaleWorker(
    GeneratedDatabase db, ScaleRunConfig cfg, SendPort events, _ApplyTx tx) async {
  final m = <String, Object?>{'label': cfg.label, 'changes': cfg.changes, 'batch_size': cfg.batchSize};
  final rng = Random(0x53330000 + cfg.runIndex);
  Future<List<Map<String, Object?>>> select(String sql, [List<Object?> args = const []]) async => [
        for (final r in await db.customSelect(sql, variables: [for (final a in args) _variable(a)]).get()) r.data
      ];

  // --- table metadata ---------------------------------------------------------------------------------------
  final metas = <int, _TableMeta>{};
  for (final p in spikeSyncedTables) {
    metas[p.tblId] = _TableMeta(p, await _syncedColumns(db, p.table));
  }
  final state = (await select('SELECT local_origin_id FROM sync_state WHERE id = 1')).single;
  final localOrigin = state['local_origin_id'] as int;

  Uint8List jsonBytes(Object? v) => Uint8List.fromList(utf8.encode(jsonEncode(v)));
  Map<String, Object?> rowValue(_TableMeta t, Map<String, Object?> row, {int bump = 0}) => {
        'created_date': row['created_date'],
        for (final c in t.synced) c: (c == 'duration' && row[c] is int) ? (row[c] as int) + bump : _jsonSafe(row[c]),
      };
  Uint8List cellValue(_TableMeta t, int colId, Map<String, Object?> row) {
    if (colId == tombstoneColId) return jsonBytes(row['deleted_date']);
    if (!t.fieldLevel) return jsonBytes(rowValue(t, row, bump: 1));
    return jsonBytes(_jsonSafe(row[t.synced[colId - 1]]));
  }

  // --- sender: source read (proxy for the sender's paged read by origin seq) --------------------------------
  final readSw = Stopwatch()..start();
  final updates = <_Source>[];
  final nUpdates = cfg.changes ~/ 2;
  final ownCells =
      ((await select('SELECT COUNT(*) AS n FROM sync_clock WHERE origin_id = ?', [localOrigin])).single['n'] as int);
  final stride = max(1, ownCells ~/ max(1, nUpdates));
  final shape = cfg.shape;
  final picked = await select(
    'SELECT ${shape.tblExpr} AS tbl_id, ${shape.pkExpr} AS pk, ${shape.colExpr} AS col_id FROM ${shape.cellFrom} '
    'WHERE c.origin_id = ? AND c.origin_seq % ? = ? ORDER BY c.origin_seq LIMIT ?',
    [localOrigin, stride, cfg.runIndex % stride, nUpdates],
  );
  final byTable = <int, List<(String, int)>>{};
  for (final r in picked) {
    byTable.putIfAbsent(r['tbl_id'] as int, () => []).add((r['pk'] as String, r['col_id'] as int));
  }
  for (final e in byTable.entries) {
    final t = metas[e.key]!;
    final pks = e.value.map((c) => c.$1).toSet().toList();
    final rows = <String, Map<String, Object?>>{};
    for (var i = 0; i < pks.length; i += 500) {
      final chunk = pks.sublist(i, min(i + 500, pks.length));
      for (final r in await select(
          'SELECT * FROM "${t.table}" WHERE id IN (${List.filled(chunk.length, '?').join(',')})', chunk)) {
        rows[r['id'] as String] = r;
      }
    }
    for (final (pk, colId) in e.value) {
      final row = rows[pk];
      if (row != null) updates.add(_Source(t, pk, colId, cellValue(t, colId, row)));
    }
  }
  final inserts = <_Source>[];
  final newRows = (cfg.changes - updates.length) ~/ 2;
  final rowLevel = metas.values.where((t) => !t.fieldLevel && t.synced.isNotEmpty).toList();
  final rowCounts = <int, int>{
    for (final t in rowLevel) t.tblId: (await select('SELECT COUNT(*) AS n FROM "${t.table}"')).single['n'] as int
  };
  final totalRowLevel = rowCounts.values.fold(0, (a, b) => a + b);
  final insertMix = <String, int>{};
  var remaining = newRows;
  for (var i = 0; i < rowLevel.length && remaining > 0; i++) {
    final t = rowLevel[i];
    final share = i == rowLevel.length - 1 ? remaining : (newRows * rowCounts[t.tblId]! / totalRowLevel).round();
    final count = min(share, remaining);
    if (count <= 0 || rowCounts[t.tblId]! == 0) continue;
    remaining -= count;
    insertMix[t.table] = count;
    var made = 0;
    var offset = 0;
    while (made < count) {
      final page =
          await select('SELECT * FROM "${t.table}" ORDER BY id LIMIT ? OFFSET ?', [min(1000, count - made), offset]);
      if (page.isEmpty) {
        offset = 0;
        continue;
      }
      offset += page.length;
      for (final row in page) {
        final pk = 's3r${cfg.runIndex}-${_hex(List.generate(12, (_) => rng.nextInt(256)))}';
        final live = Map<String, Object?>.of(row)..['deleted_date'] = null;
        inserts.add(_Source(t, pk, rowColId, jsonBytes(rowValue(t, live))));
        inserts.add(_Source(t, pk, tombstoneColId, jsonBytes(null)));
        made++;
      }
    }
  }
  // Interleave: update, insert pair, update, ... (`*` stays directly before its `~`).
  final sources = <_Source>[];
  var ui = 0;
  var ii = 0;
  while (ui < updates.length || ii < inserts.length) {
    if (ui < updates.length) sources.add(updates[ui++]);
    if (ii < inserts.length) {
      sources.add(inserts[ii++]);
      sources.add(inserts[ii++]);
    }
  }
  readSw.stop();
  final n = sources.length;
  m['source_read_ms'] = readSw.elapsedMilliseconds;
  m['changes_prepared'] = n;
  m['updates'] = updates.length;
  m['inserts'] = inserts.length;
  final updateMix = <String, int>{};
  for (final s in updates) {
    updateMix[s.meta.table] = (updateMix[s.meta.table] ?? 0) + 1;
  }
  m['update_mix'] = updateMix.toString();
  m['insert_mix'] = insertMix.toString();

  // --- full-state wire size (every own cell of the bootstrapped DB) -----------------------------------------
  const epochCreator = scaleLocalMemberId;
  final peerMember = _hex(List.generate(16, (_) => rng.nextInt(256)));
  if (cfg.measureFullState) {
    final sw = Stopwatch()..start();
    var cells = 0;
    var bytes = 0;
    var valueBytes = 0;
    var maxValue = 0;
    var seq = 0;
    for (final t in metas.values) {
      var after = '';
      while (true) {
        final page = await select('SELECT * FROM "${t.table}" WHERE id > ? ORDER BY id LIMIT 2000', [after]);
        if (page.isEmpty) break;
        after = page.last['id'] as String;
        for (final row in page) {
          final colIds = t.fieldLevel ? [tombstoneColId, for (var i = 1; i <= t.synced.length; i++) i] : [0, 1];
          for (final colId in colIds) {
            final v = cellValue(t, colId, row).length;
            seq++;
            cells++;
            valueBytes += v;
            maxValue = max(maxValue, v);
            bytes += 2 +
                wireRecordLength(
                    t.table, row['id'] as String, t.colName(colId), v, scaleLocalMemberId, seq, epochCreator);
          }
        }
      }
    }
    for (var from = 0; from < cells; from += manifestSize) {
      bytes += manifestWireLength(from, min(from + manifestSize, cells));
    }
    m['full_state_cells'] = cells;
    m['full_state_wire_bytes'] = bytes;
    m['full_state_value_bytes'] = valueBytes;
    m['full_state_max_value_bytes'] = maxValue;
    m['full_state_calc_ms'] = sw.elapsedMilliseconds;
  }

  // --- sender crypto: canonical + BLAKE2b, manifests + Ed25519, XChaCha20-Poly1305, wire encode ----------------
  final group = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
  final origin = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
  final groupKey = SecretKeyData.random(length: 32);
  final signingKey = await _ed25519.newKeyPair();
  final publicKey = await signingKey.extractPublicKey();
  final baseHlc = DateTime.now().millisecondsSinceEpoch << 16;
  final hashes = List<Uint8List>.filled(n, Uint8List(0));
  final records = List<Uint8List>.filled(n, Uint8List(0));
  final manifests = <_Manifest>[];
  var hashUs = 0, signUs = 0, encUs = 0, encodeUs = 0;
  var valueTotal = 0, canonicalTotal = 0, recordTotal = 0, maxValue = 0;
  final lap = Stopwatch()..start();
  for (var i = 0; i < n; i++) {
    final s = sources[i];
    final seq = i + 1;
    final hlc = baseHlc + i;
    final col = s.meta.colName(s.colId);
    lap.reset();
    final canonical = _canonical(group, s.meta.table, s.pk, col, s.value, hlc, peerMember, origin, seq);
    hashes[i] = Uint8List.fromList(_blake2b256.hashSync(canonical).bytes);
    hashUs += lap.elapsedMicroseconds;
    canonicalTotal += canonical.length;
    valueTotal += s.value.length;
    maxValue = max(maxValue, s.value.length);
    if ((i + 1) % manifestSize == 0 || i == n - 1) {
      lap.reset();
      final from = manifests.isEmpty ? 0 : manifests.last.to;
      final body = _manifestBody(group, origin, from, i + 1, hashes);
      final sig = await _ed25519.sign(body, keyPair: signingKey);
      manifests.add(_Manifest(from, i + 1, body, sig.bytes));
      signUs += lap.elapsedMicroseconds;
    }
    lap.reset();
    final ad = _ad(group, 1, epochCreator, s.meta.table, s.pk, col, hlc, origin, seq);
    final box = _xchacha.encryptSync(s.value, secretKey: groupKey, aad: ad);
    encUs += lap.elapsedMicroseconds;
    lap.reset();
    final w = _Writer()
      ..str(s.meta.table)
      ..str(s.pk)
      ..str(col)
      ..u64(hlc)
      ..str(peerMember)
      ..raw(origin)
      ..varint(seq)
      ..varint(0)
      ..varint(1)
      ..str(epochCreator)
      ..raw(box.nonce)
      ..varint(box.cipherText.length + box.mac.bytes.length)
      ..raw(box.cipherText)
      ..raw(box.mac.bytes);
    records[i] = w.take();
    encodeUs += lap.elapsedMicroseconds;
    recordTotal += records[i].length;
  }
  sources.clear();
  updates.clear();
  inserts.clear();
  final manifestWire = manifests.fold<int>(0, (a, mf) => a + manifestWireLength(mf.from, mf.to));
  var maxFrame = 0;
  for (var b = 0; b < n; b += cfg.batchSize) {
    final end = min(b + cfg.batchSize, n);
    var frame = 16; // batch header: covered range (origin, from, to)
    for (var i = b; i < end; i++) {
      frame += varintLength(records[i].length) + records[i].length;
    }
    frame += manifests
        .where((mf) => mf.from < end && mf.to > b)
        .fold<int>(0, (a, mf) => a + manifestWireLength(mf.from, mf.to));
    maxFrame = max(maxFrame, frame);
  }
  final senderUs = hashUs + signUs + encUs + encodeUs;
  m.addAll({
    'sender_hash_ms': _ms(hashUs),
    'sender_sign_ms': _ms(signUs),
    'sender_encrypt_ms': _ms(encUs),
    'sender_encode_ms': _ms(encodeUs),
    'sender_cpu_ms': _ms(senderUs),
    'sender_per_change_us': senderUs / n,
    'manifests': manifests.length,
    'avg_value_bytes': valueTotal / n,
    'max_value_bytes': maxValue,
    'avg_canonical_bytes': canonicalTotal / n,
    'avg_wire_record_bytes': recordTotal / n,
    'manifest_wire_bytes': manifestWire,
    'wire_bytes_total': recordTotal + manifestWire + n * 2,
    'avg_wire_bytes_per_change': (recordTotal + manifestWire + n * 2) / n,
    'max_frame_bytes': maxFrame,
  });

  // --- receiver: intern the peer, then apply in batches -------------------------------------------------------
  await db.customStatement("INSERT OR IGNORE INTO sync_intern (kind, value) VALUES ('node', ?)", [peerMember]);
  await db.customStatement("INSERT OR IGNORE INTO sync_intern (kind, value) VALUES ('origin', ?)", [_hex(origin)]);
  final peerNodeId = (await select('SELECT id FROM sync_intern WHERE value = ?', [peerMember])).single['id'] as int;
  final peerOriginId = (await select('SELECT id FROM sync_intern WHERE value = ?', [_hex(origin)])).single['id'] as int;
  final metaByName = {for (final t in metas.values) t.table: t};
  final upsertSql = <int, String>{};
  String rowUpsert(_TableMeta t) => upsertSql.putIfAbsent(t.tblId, () {
        final cols = ['id', 'created_date', 'modified_date', ...t.synced];
        final sets = [
          for (final c in t.synced) '"$c" = excluded."$c"',
          'modified_date = MAX(COALESCE("${t.table}".modified_date, "${t.table}".created_date) + 1, excluded.modified_date)',
        ];
        return 'INSERT INTO "${t.table}" (${cols.map((c) => '"$c"').join(', ')}) '
            'VALUES (${List.filled(cols.length, '?').join(', ')}) ON CONFLICT(id) DO UPDATE SET ${sets.join(', ')}';
      });
  const clockUpsert = 'INSERT INTO sync_clock (tbl_id, pk, col_id, hlc, node_id, origin_id, origin_seq, manifest_id, '
      'tomb_value, cause_tbl_id, cause_pk, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?) '
      'ON CONFLICT (tbl_id, pk, col_id) DO UPDATE SET hlc = excluded.hlc, node_id = excluded.node_id, '
      'origin_id = excluded.origin_id, origin_seq = excluded.origin_seq, manifest_id = excluded.manifest_id, '
      'tomb_value = excluded.tomb_value, cause_tbl_id = NULL, cause_pk = NULL, recorded_at = excluded.recorded_at';
  // Interned shapes: the key is the local sync_row id (known from the prefetch, or interned in the item for a row
  // the receiver has never seen). Values after the key: hlc, node, origin, seq, manifest, tomb, recorded_at.
  final internKeyColumns = shape.packed ? 'key' : 'row_id, col_id';
  final internSet = 'ON CONFLICT ($internKeyColumns) DO UPDATE SET hlc = excluded.hlc, node_id = excluded.node_id, '
      'origin_id = excluded.origin_id, origin_seq = excluded.origin_seq, manifest_id = excluded.manifest_id, '
      'tomb_value = excluded.tomb_value, cause_row_id = NULL, recorded_at = excluded.recorded_at';
  final internValuesUpsert = 'INSERT INTO sync_clock ($internKeyColumns, hlc, node_id, origin_id, origin_seq, '
      'manifest_id, tomb_value, cause_row_id, recorded_at) '
      'VALUES (${shape.packed ? '?' : '?, ?'}, ?, ?, ?, ?, ?, ?, NULL, ?) $internSet';
  final internSelectUpsert = 'INSERT INTO sync_clock ($internKeyColumns, hlc, node_id, origin_id, origin_seq, '
      'manifest_id, tomb_value, cause_row_id, recorded_at) '
      'SELECT ${shape.packed ? 'id * ${trig.packedKeyFactor} + ?' : 'id, ?'}, ?, ?, ?, ?, ?, ?, NULL, ? '
      'FROM sync_row WHERE tbl_id = ? AND pk = ? $internSet';
  const internRow = 'INSERT INTO sync_row (tbl_id, pk) VALUES (?, ?) ON CONFLICT (tbl_id, pk) DO NOTHING';

  var verifyUs = 0, decryptUs = 0;
  final batchTotalMs = <double>[];
  final batchTxMs = <double>[];
  final batchCryptoMs = <double>[];
  var applied = 0, lost = 0, failed = 0;
  var sqlItemUs = 0, prefetchUs = 0;
  events.send({'event': eventApplyStart, 'label': cfg.label});
  final applySw = Stopwatch()..start();
  for (var b = 0; b < n; b += cfg.batchSize) {
    final end = min(b + cfg.batchSize, n);
    final batchSw = Stopwatch()..start();

    // Crypto before the transaction: verify each manifest once, decrypt, rebuild canonical, rehash, check.
    final cryptoSw = Stopwatch()..start();
    final decoded = <(_TableMeta, String, int, int, int, Object?, _Manifest)>[];
    for (var i = b; i < end; i++) {
      final r = _Reader(records[i]);
      final tbl = r.str(), pk = r.str(), col = r.str(), hlc = r.u64(), node = r.str();
      final org = r.raw(16);
      final seq = r.varint();
      r.varint(); // cause absent
      final epoch = r.varint();
      final creator = r.str();
      final nonce = r.raw(24);
      final ct = r.bytes();
      final mf = manifests[(seq - 1) ~/ manifestSize];
      if (!mf.verified) {
        final v = Stopwatch()..start();
        if (!await _ed25519.verify(mf.body, signature: Signature(mf.signature, publicKey: publicKey))) {
          throw StateError('manifest signature');
        }
        mf.verified = true;
        verifyUs += v.elapsedMicroseconds;
      }
      final d = Stopwatch()..start();
      final value = _xchacha.decryptSync(
        SecretBox(Uint8List.sublistView(ct, 0, ct.length - 16),
            nonce: nonce, mac: Mac(Uint8List.sublistView(ct, ct.length - 16))),
        secretKey: groupKey,
        aad: _ad(group, epoch, creator, tbl, pk, col, hlc, org, seq),
      );
      final h = _blake2b256.hashSync(_canonical(group, tbl, pk, col, value, hlc, node, org, seq)).bytes;
      final at = _manifestHeader + (seq - 1 - mf.from) * 32;
      for (var k = 0; k < 32; k++) {
        if (h[k] != mf.body[at + k]) throw StateError('hash not in manifest');
      }
      decryptUs += d.elapsedMicroseconds;
      final t = metaByName[tbl]!;
      final colId = col == '~' ? tombstoneColId : (col == '*' ? rowColId : t.synced.indexOf(col) + 1);
      decoded.add((t, pk, colId, hlc, seq, jsonDecode(utf8.decode(value)), mf));
    }
    cryptoSw.stop();

    final txSw = Stopwatch()..start();
    await tx.run(() async {
      await db.customStatement('UPDATE sync_state SET apply_mode = 1 WHERE id = 1');
      for (final mf in decoded.map((d) => d.$7).toSet()) {
        mf.storedId ??= await db.customInsert(
          'INSERT INTO sync_origin_batch (origin_id, from_seq, to_seq, hashes, sig) VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable<int>(peerOriginId),
            Variable<int>(mf.from),
            Variable<int>(mf.to),
            Variable<Uint8List>(Uint8List.sublistView(mf.body, _manifestHeader)),
            Variable<Uint8List>(Uint8List.fromList(mf.signature)),
          ],
        );
      }
      // Merge check: prefetch the local clocks of the batch, compare (hlc, node) in Dart.
      final pre = Stopwatch()..start();
      final local = <String, (int, String)>{};
      final rowIds = <String, int>{};
      final pksByTable = <int, Set<String>>{};
      for (final d in decoded) {
        pksByTable.putIfAbsent(d.$1.tblId, () => {}).add(d.$2);
      }
      for (final e in pksByTable.entries) {
        final pks = e.value.toList();
        for (var i = 0; i < pks.length; i += 500) {
          final chunk = pks.sublist(i, min(i + 500, pks.length));
          final marks = List.filled(chunk.length, '?').join(',');
          final rows = await select(
            shape.interned
                ? 'SELECT r.pk, r.id AS row_id, ${shape.colExpr} AS col_id, c.hlc, n.value AS node '
                    'FROM sync_row r LEFT JOIN sync_clock c ON ${shape.rowToClock} '
                    'LEFT JOIN sync_intern n ON n.id = c.node_id WHERE r.tbl_id = ? AND r.pk IN ($marks)'
                : 'SELECT c.pk, c.col_id, c.hlc, n.value AS node FROM sync_clock c JOIN sync_intern n ON n.id = c.node_id '
                    'WHERE c.tbl_id = ? AND c.pk IN ($marks)',
            [e.key, ...chunk],
          );
          for (final r in rows) {
            if (shape.interned) rowIds['${e.key}|${r['pk']}'] = r['row_id'] as int;
            if (r['hlc'] == null) continue;
            local['${e.key}|${r['pk']}|${r['col_id']}'] = (r['hlc'] as int, r['node'] as String);
          }
        }
      }
      prefetchUs += pre.elapsedMicroseconds;
      final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      var maxHlc = 0;
      final itemSw = Stopwatch()..start();
      for (final (t, pk, colId, hlc, seq, value, mf) in decoded) {
        final existing = local['${t.tblId}|$pk|$colId'];
        if (existing != null && (existing.$1 > hlc || (existing.$1 == hlc && existing.$2.compareTo(peerMember) >= 0))) {
          lost++;
          continue;
        }
        maxHlc = max(maxHlc, hlc);
        final _Stmt base;
        if (colId == tombstoneColId) {
          base = _Stmt(
              'UPDATE "${t.table}" SET deleted_date = ?, '
              'modified_date = MAX(COALESCE(modified_date, created_date) + 1, ?) WHERE id = ?',
              [value, nowS, pk]);
        } else if (!t.fieldLevel) {
          final map = value as Map<String, Object?>;
          base = _Stmt(rowUpsert(t), [pk, map['created_date'], nowS, for (final c in t.synced) map[c]]);
        } else {
          base = _Stmt(
              'UPDATE "${t.table}" SET "${t.synced[colId - 1]}" = ?, '
              'modified_date = MAX(COALESCE(modified_date, created_date) + 1, ?) WHERE id = ?',
              [value, nowS, pk]);
        }
        final tomb = colId == tombstoneColId ? value : null;
        final clockValues = [hlc, peerNodeId, peerOriginId, seq, mf.storedId, tomb, nowMs];
        final List<_Stmt> clock;
        if (!shape.interned) {
          clock = [
            _Stmt(clockUpsert, [t.tblId, pk, colId, ...clockValues])
          ];
        } else {
          final rowId = rowIds['${t.tblId}|$pk'];
          if (rowId != null) {
            clock = [
              _Stmt(internValuesUpsert, [
                if (shape.packed) rowId * trig.packedKeyFactor + colId else ...[rowId, colId],
                ...clockValues,
              ])
            ];
          } else {
            clock = [
              _Stmt(internRow, [t.tblId, pk]),
              _Stmt(internSelectUpsert, [colId, ...clockValues, t.tblId, pk]),
            ];
          }
        }
        try {
          await tx.item([
            const _Stmt('SAVEPOINT s3_item', []),
            base,
            ...clock,
            const _Stmt('RELEASE s3_item', []),
          ]);
          applied++;
        } catch (e) {
          failed++;
          await db.customStatement('ROLLBACK TO s3_item');
          await db.customStatement('RELEASE s3_item');
        }
      }
      sqlItemUs += itemSw.elapsedMicroseconds;
      await db.customStatement('UPDATE sync_state SET hlc = MAX(hlc, ?), apply_mode = 0 WHERE id = 1', [maxHlc]);
      await db.customStatement(
          'INSERT INTO sync_vector (origin_id, cursor) VALUES (?, ?) '
          'ON CONFLICT(origin_id) DO UPDATE SET cursor = excluded.cursor',
          [peerOriginId, end]);
    });
    txSw.stop();
    batchSw.stop();
    batchTotalMs.add(batchSw.elapsedMicroseconds / 1000);
    batchTxMs.add(txSw.elapsedMicroseconds / 1000);
    batchCryptoMs.add(cryptoSw.elapsedMicroseconds / 1000);
  }
  applySw.stop();
  events.send({'event': eventApplyDone, 'label': cfg.label});
  final applyMode = (await select('SELECT apply_mode FROM sync_state WHERE id = 1')).single['apply_mode'];
  m.addAll({
    'apply_total_ms': applySw.elapsedMilliseconds,
    'apply_changes_per_s': n / (applySw.elapsedMicroseconds / 1e6),
    'apply_per_change_us': applySw.elapsedMicroseconds / n,
    'applied': applied,
    'lost': lost,
    'failed': failed,
    'receiver_verify_ms': _ms(verifyUs),
    'receiver_decrypt_hash_check_ms': _ms(decryptUs),
    'receiver_crypto_per_change_us': (verifyUs + decryptUs) / n,
    'receiver_sql_prefetch_ms': _ms(prefetchUs),
    'receiver_sql_items_ms': _ms(sqlItemUs),
    'batch_total_ms': summarize(batchTotalMs),
    'batch_tx_ms': summarize(batchTxMs),
    'batch_crypto_ms': summarize(batchCryptoMs),
    'busy_retries': tx.busyRetries,
    'apply_mode_after': applyMode,
  });
  return m;
}

Variable<Object> _variable(Object? value) {
  if (value == null) return const Variable<Object>(null);
  if (value is int) return Variable<int>(value);
  if (value is String) return Variable<String>(value);
  if (value is double) return Variable<double>(value);
  if (value is Uint8List) return Variable<Uint8List>(value);
  throw ArgumentError.value(value, 'value');
}
