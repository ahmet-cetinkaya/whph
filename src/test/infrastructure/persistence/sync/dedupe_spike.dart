/// S5 spike (plan T7): prototype of the D17 upgrade job phases `dedupe` (D5
/// deterministic identities, survivor rule, FK rewrite, link collapse) and
/// `bootstrap` (D6 clock bootstrap), as chunked and resumable steps.
///
/// Test-only code. The production job is T17
/// (`sync_upgrade_job.dart`), the identity helper is T15 (`sync_identity.dart`).
/// Everything here runs on plain SQL through a drift [GeneratedDatabase], so the
/// same class can later be driven from an on-device integration test that opens
/// a fixture with `NativeDatabase` (Android timing, acceptance 6).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// UUIDv5 and deterministic identities (D5)
// ---------------------------------------------------------------------------

/// RFC 4122 URL namespace, only used to derive [whphSyncNamespace].
const String rfc4122UrlNamespace = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';

/// Name hashed under [rfc4122UrlNamespace] to derive [whphSyncNamespace].
const String whphSyncNamespaceName = 'https://github.com/ahmet-cetinkaya/whph/sync/identity/v1';

/// Fixed WHPH namespace for every deterministic sync identity.
/// `= uuidV5(rfc4122UrlNamespace, whphSyncNamespaceName)` (asserted by the
/// spike test). T15 must adopt this value verbatim.
const String whphSyncNamespace = 'c26322fa-390b-53c7-92ba-b001998dc342';

List<int> _uuidBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  if (hex.length != 32) throw ArgumentError.value(uuid, 'uuid');
  return [for (var i = 0; i < 32; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
}

String _formatUuid(List<int> b) {
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

/// RFC 4122 §4.3 name-based UUID, version 5 (SHA-1).
String uuidV5(String namespace, String name) {
  final digest = sha1.convert([..._uuidBytes(namespace), ...utf8.encode(name)]).bytes;
  final b = Uint8List.fromList(digest.sublist(0, 16));
  b[6] = (b[6] & 0x0f) | 0x50;
  b[8] = (b[8] & 0x3f) | 0x80;
  return _formatUuid(b);
}

/// Identity kinds (the first segment of the hashed name). The hashed name is
/// `<kind>|<part1>|<part2>...`; parts are ids (nanoid/UUID alphabets never
/// contain `|`), `yyyy-MM-dd` days or, for settings, the key (single part).
abstract final class SyncIdentityKind {
  static const habitRecord = 'habit_record';
  static const setting = 'setting';
  static const recurringOccurrence = 'task_occurrence';
  static const taskTag = 'task_tag';
  static const habitTag = 'habit_tag';
  static const noteTag = 'note_tag';
  static const appUsageTag = 'app_usage_tag';
  static const tagTag = 'tag_tag';
  static const legacySyncDevice = 'sync_device';
  static const syncMember = 'sync_member';
}

String syncIdentityId(String kind, List<String> parts) => uuidV5(whphSyncNamespace, [kind, ...parts].join('|'));

/// Built-in statuses keep the fixed v37 ids (`TaskStatusConstants`, seeded
/// with the same value on every device since v34): the "fixed kind constant".
const String builtInTodoStatusId = 'task-status-builtin-todo';
const String builtInDoneStatusId = 'task-status-builtin-done';

// ---------------------------------------------------------------------------
// FK rewrite list (finalized by the S5 schema scan)
// ---------------------------------------------------------------------------

/// Columns rewritten when a row of the key table is re-keyed or merged. Only
/// tables the dedupe phase re-keys can appear as keys; the scan test checks
/// that this equals "every `*_id` column whose target table is re-keyed".
const Map<String, List<(String, String)>> fkRewriteList = {
  'task_table': [
    ('task_table', 'parent_task_id'),
    ('task_table', 'recurrence_parent_id'),
    ('task_tag_table', 'task_id'),
    ('task_time_record_table', 'task_id'),
  ],
  'task_status_table': [('task_table', 'status_id')],
};

// ---------------------------------------------------------------------------
// Table policy for the bootstrap (D1 levels, spike constants)
// ---------------------------------------------------------------------------

const int tombstoneColId = 0;

/// `*` cell of row-level tables.
const int rowColId = 1;

class SpikeTablePolicy {
  const SpikeTablePolicy(this.tblId, this.table, {required this.fieldLevel});
  final int tblId;
  final String table;
  final bool fieldLevel;
}

/// Synced v37 tables in bootstrap order. `sync_device_table` is local-only
/// (legacy, D13) and gets no clock rows.
const List<SpikeTablePolicy> spikeSyncedTables = [
  SpikeTablePolicy(1, 'task_table', fieldLevel: true),
  SpikeTablePolicy(2, 'habit_table', fieldLevel: true),
  SpikeTablePolicy(3, 'note_table', fieldLevel: true),
  SpikeTablePolicy(4, 'tag_table', fieldLevel: true),
  SpikeTablePolicy(5, 'task_status_table', fieldLevel: true),
  SpikeTablePolicy(6, 'setting_table', fieldLevel: true),
  SpikeTablePolicy(7, 'app_usage_table', fieldLevel: true),
  SpikeTablePolicy(8, 'app_usage_time_record_table', fieldLevel: false),
  SpikeTablePolicy(9, 'task_time_record_table', fieldLevel: false),
  SpikeTablePolicy(10, 'habit_record_table', fieldLevel: false),
  SpikeTablePolicy(11, 'habit_time_record_table', fieldLevel: false),
  SpikeTablePolicy(12, 'app_usage_tag_rule_table', fieldLevel: false),
  SpikeTablePolicy(13, 'app_usage_ignore_rule_table', fieldLevel: false),
  SpikeTablePolicy(14, 'task_tag_table', fieldLevel: false),
  SpikeTablePolicy(15, 'habit_tag_table', fieldLevel: false),
  SpikeTablePolicy(16, 'note_tag_table', fieldLevel: false),
  SpikeTablePolicy(17, 'app_usage_tag_table', fieldLevel: false),
  SpikeTablePolicy(18, 'tag_tag_table', fieldLevel: false),
];

const Set<String> auditColumns = {'id', 'created_date', 'modified_date', 'deleted_date'};

// ---------------------------------------------------------------------------
// Spike sync tables (D1 / T13 shape, reduced to what the job touches)
// ---------------------------------------------------------------------------

abstract final class SpikeSyncSchema {
  static const phaseDedupe = 'dedupe';
  static const phaseBootstrap = 'bootstrap';
  static const phaseDone = 'done';
  static const applyModeUpgrade = 4;

  /// Creates the spike sync tables and, like the v38 migration, sets
  /// `upgrade_phase = 'dedupe'` (only when the singleton does not exist yet).
  /// With [withClockTable] false, `sync_clock` and its indexes are left to the
  /// caller (S3 physical-shape variants, plan PA-1).
  static Future<void> install(GeneratedDatabase db,
      {required String memberId, required String originId, bool withClockTable = true}) async {
    await db.transaction(() async {
      await db.customStatement('''
CREATE TABLE IF NOT EXISTS sync_intern (
  id INTEGER PRIMARY KEY,
  kind TEXT NOT NULL,
  value TEXT NOT NULL UNIQUE
)''');
      if (withClockTable) {
        await db.customStatement('''
CREATE TABLE IF NOT EXISTS sync_clock (
  tbl_id INTEGER NOT NULL,
  pk TEXT NOT NULL,
  col_id INTEGER NOT NULL,
  hlc INTEGER NOT NULL,
  node_id INTEGER NOT NULL,
  origin_id INTEGER NOT NULL,
  origin_seq INTEGER NOT NULL,
  manifest_id INTEGER NULL,
  tomb_value INTEGER NULL,
  cause_tbl_id INTEGER NULL,
  cause_pk TEXT NULL,
  recorded_at INTEGER NOT NULL,
  PRIMARY KEY (tbl_id, pk, col_id)
)''');
        await db.customStatement('CREATE INDEX IF NOT EXISTS sync_clock_cause ON sync_clock (cause_tbl_id, cause_pk)');
        await db.customStatement('CREATE INDEX IF NOT EXISTS sync_clock_origin ON sync_clock (origin_id, origin_seq)');
      }
      await db.customStatement('''
CREATE TABLE IF NOT EXISTS sync_state (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  member_node_id INTEGER NOT NULL,
  local_origin_id INTEGER NOT NULL,
  hlc INTEGER NOT NULL DEFAULT 0,
  next_seq INTEGER NOT NULL DEFAULT 1,
  apply_mode INTEGER NOT NULL DEFAULT 0,
  upgrade_phase TEXT NOT NULL,
  upgrade_cursor TEXT NULL,
  upgrade_started_at INTEGER NULL
)''');
      await db.customStatement("INSERT OR IGNORE INTO sync_intern (kind, value) VALUES ('node', ?)", [memberId]);
      await db.customStatement("INSERT OR IGNORE INTO sync_intern (kind, value) VALUES ('origin', ?)", [originId]);
      await db.customStatement('''
INSERT OR IGNORE INTO sync_state (id, member_node_id, local_origin_id, upgrade_phase)
VALUES (1, (SELECT id FROM sync_intern WHERE value = ?), (SELECT id FROM sync_intern WHERE value = ?), ?)''',
          [memberId, originId, phaseDedupe]);
    });
  }
}

// ---------------------------------------------------------------------------
// Timing (acceptance 6; reusable by a later on-device integration test)
// ---------------------------------------------------------------------------

/// One bootstrap chunk: rows `from < id <= lastId` of [policy]'s table get the cells [colIds], with seqs
/// `baseSeq, baseSeq + 1, …` in `(pk, col_id)` order.
class BootstrapChunk {
  BootstrapChunk({
    required this.policy,
    required this.colIds,
    required this.from,
    required this.lastId,
    required this.nodeId,
    required this.originId,
    required this.baseSeq,
    required this.recordedAt,
  });
  final SpikeTablePolicy policy;
  final List<int> colIds;
  final String from;
  final String lastId;
  final int nodeId;
  final int originId;
  final int baseSeq;
  final int recordedAt;
}

/// Writes the clock cells of one bootstrap chunk inside the chunk transaction and returns (cells inserted, max HLC
/// of the chunk's cells, 0 if none). Lets S3 (plan PA-1) bootstrap other physical `sync_clock` shapes; null in
/// [DedupeSpikeJob] means the D1 `sync_clock (tbl_id, pk, col_id, …)` statements.
typedef BootstrapChunkWriter = Future<(int, int)> Function(GeneratedDatabase db, BootstrapChunk chunk);

class ChunkTiming {
  ChunkTiming(this.phase, this.label, this.elapsed, this.units);
  final String phase;

  /// Family/key for dedupe chunks, `table@cursor` for bootstrap chunks.
  final String label;
  final Duration elapsed;

  /// Groups (dedupe) or cells (bootstrap) processed.
  final int units;
}

class ChunkTimingSummary {
  ChunkTimingSummary(this.timings);
  final List<ChunkTiming> timings;

  Iterable<ChunkTiming> _of(String phase) => timings.where((t) => t.phase == phase);
  int count(String phase) => _of(phase).length;
  int units(String phase) => _of(phase).fold(0, (a, t) => a + t.units);
  Duration total(String phase) => _of(phase).fold(Duration.zero, (a, t) => a + t.elapsed);
  ChunkTiming? slowest(String phase) =>
      _of(phase).fold<ChunkTiming?>(null, (a, t) => a == null || t.elapsed > a.elapsed ? t : a);
  ChunkTiming? get slowestOverall =>
      timings.fold<ChunkTiming?>(null, (a, t) => a == null || t.elapsed > a.elapsed ? t : a);

  String describe() {
    final buffer = StringBuffer();
    for (final phase in [SpikeSyncSchema.phaseDedupe, SpikeSyncSchema.phaseBootstrap]) {
      final s = slowest(phase);
      buffer.writeln('$phase: ${count(phase)} chunks, ${units(phase)} units, '
          'total ${total(phase).inMilliseconds} ms, '
          'max chunk ${s == null ? 0 : s.elapsed.inMicroseconds / 1000} ms${s == null ? '' : ' (${s.label})'}');
    }
    return buffer.toString().trimRight();
  }
}

// ---------------------------------------------------------------------------
// Dedupe families
// ---------------------------------------------------------------------------

class _Member {
  _Member(this.id, this.created, this.modified, this.deleted, this.isRoot);
  final String id;
  final int created;
  final int? modified;
  final int? deleted;
  final bool isRoot;
  int get effectiveModified => modified ?? created;
  bool get live => deleted == null;
}

class _Group {
  _Group(this.key);
  final String key;
  final List<_Member> members = [];
  late String survivorId;
  late String sourceId;
  String? rootId;

  bool get pending => members.length > 1 || members.single.id != survivorId;
}

/// Survivor rule (D5, FR-033): a live row always beats soft-deleted rows; then
/// the latest `modified_date ?? created_date`; ties → smallest old id.
int _compareSurvivorCandidates(_Member a, _Member b) {
  if (a.live != b.live) return a.live ? -1 : 1;
  final byDate = b.effectiveModified.compareTo(a.effectiveModified);
  if (byDate != 0) return byDate;
  return a.id.compareTo(b.id);
}

class DedupeFamily {
  const DedupeFamily({
    required this.name,
    required this.table,
    required this.selectSql,
    required this.survivorIdOf,
    this.usesDayOffset = false,
    this.preserveRootColumnsPrefix,
  });

  final String name;
  final String table;

  /// Must select `id, created_date, modified_date, deleted_date, k1, k2, is_root`
  /// (k2/is_root may be NULL/0). A `?` is bound to the day offset when
  /// [usesDayOffset].
  final String selectSql;
  final String Function(String k1, String? k2) survivorIdOf;
  final bool usesDayOffset;

  /// For groups containing a recurring series root: the root keeps its id and
  /// its columns with this prefix (the series definition).
  final String? preserveRootColumnsPrefix;
}

String _link(String kind, String k1, String? k2) => syncIdentityId(kind, [k1, k2!]);

/// Fixed family order. Later families' keys depend on earlier families' ids
/// (links use re-keyed task ids), so each family's groups are computed only
/// when the job enters it.
final List<DedupeFamily> dedupeFamilies = [
  DedupeFamily(
    name: 'builtin_task_status',
    table: 'task_status_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, '
        "CASE WHEN is_done_status = 1 THEN 'done' ELSE 'todo' END AS k1, NULL AS k2, 0 AS is_root "
        'FROM task_status_table WHERE is_built_in = 1',
    survivorIdOf: (k1, _) => k1 == 'done' ? builtInDoneStatusId : builtInTodoStatusId,
  ),
  DedupeFamily(
    name: 'setting',
    table: 'setting_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, key AS k1, NULL AS k2, 0 AS is_root '
        'FROM setting_table',
    survivorIdOf: (k1, _) => syncIdentityId(SyncIdentityKind.setting, [k1]),
  ),
  DedupeFamily(
    name: 'legacy_sync_device',
    table: 'sync_device_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, '
        'MIN(from_device_id, to_device_id) AS k1, MAX(from_device_id, to_device_id) AS k2, 0 AS is_root '
        'FROM sync_device_table',
    survivorIdOf: (k1, k2) => _link(SyncIdentityKind.legacySyncDevice, k1, k2),
  ),
  DedupeFamily(
    name: 'recurring_occurrence',
    table: 'task_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, '
        'COALESCE(recurrence_parent_id, id) AS k1, '
        "strftime('%Y-%m-%d', planned_date + ?, 'unixepoch') AS k2, "
        '(recurrence_parent_id IS NULL) AS is_root '
        'FROM task_table '
        'WHERE planned_date IS NOT NULL AND (recurrence_parent_id IS NOT NULL OR recurrence_type <> 0)',
    survivorIdOf: (k1, k2) => _link(SyncIdentityKind.recurringOccurrence, k1, k2),
    usesDayOffset: true,
    preserveRootColumnsPrefix: 'recurrence_',
  ),
  DedupeFamily(
    name: 'habit_record_day',
    table: 'habit_record_table',
    selectSql: 'SELECT r.id, r.created_date, r.modified_date, r.deleted_date, r.habit_id AS k1, '
        "strftime('%Y-%m-%d', r.occurred_at + ?, 'unixepoch') AS k2, 0 AS is_root "
        'FROM habit_record_table r JOIN habit_table h ON h.id = r.habit_id '
        'WHERE COALESCE(h.daily_target, 1) = 1',
    survivorIdOf: (k1, k2) => _link(SyncIdentityKind.habitRecord, k1, k2),
    usesDayOffset: true,
  ),
  DedupeFamily(
    name: 'task_tag',
    table: 'task_tag_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, tag_id AS k1, task_id AS k2, 0 AS is_root '
        'FROM task_tag_table',
    survivorIdOf: (k1, k2) => _link(SyncIdentityKind.taskTag, k1, k2),
  ),
  DedupeFamily(
    name: 'habit_tag',
    table: 'habit_tag_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, tag_id AS k1, habit_id AS k2, 0 AS is_root '
        'FROM habit_tag_table',
    survivorIdOf: (k1, k2) => _link(SyncIdentityKind.habitTag, k1, k2),
  ),
  DedupeFamily(
    name: 'note_tag',
    table: 'note_tag_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, tag_id AS k1, note_id AS k2, 0 AS is_root '
        'FROM note_tag_table',
    survivorIdOf: (k1, k2) => _link(SyncIdentityKind.noteTag, k1, k2),
  ),
  DedupeFamily(
    name: 'app_usage_tag',
    table: 'app_usage_tag_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, tag_id AS k1, app_usage_id AS k2, '
        '0 AS is_root FROM app_usage_tag_table',
    survivorIdOf: (k1, k2) => _link(SyncIdentityKind.appUsageTag, k1, k2),
  ),
  DedupeFamily(
    name: 'tag_tag',
    table: 'tag_tag_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, primary_tag_id AS k1, '
        'secondary_tag_id AS k2, 0 AS is_root FROM tag_tag_table',
    survivorIdOf: (k1, k2) => _link(SyncIdentityKind.tagTag, k1, k2),
  ),
];

/// Tables whose rows the dedupe phase may re-key or merge.
Set<String> get reKeyedTables => {for (final f in dedupeFamilies) f.table};

// ---------------------------------------------------------------------------
// The job
// ---------------------------------------------------------------------------

class JobRunResult {
  JobRunResult({required this.done, required this.chunks});
  final bool done;
  final int chunks;
}

/// Thrown by [DedupeSpikeJob.failInsideChunk] to simulate a kill in the
/// middle of a chunk transaction.
class SimulatedCrash implements Exception {
  @override
  String toString() => 'SimulatedCrash';
}

class DedupeSpikeJob {
  DedupeSpikeJob(
    this.db, {
    required this.nowMs,
    this.dayOffsetSeconds = 0,
    this.groupsPerChunk = 1,
    this.maxCellsPerChunk = 5000,
    this.failInsideChunk,
    this.onChunk,
    this.syncedTables = spikeSyncedTables,
    this.bootstrapWriter,
  });

  final GeneratedDatabase db;

  /// Wall clock of this run; stored once as `upgrade_started_at` and used for
  /// `recorded_at`, so resumed runs stay deterministic.
  final int nowMs;

  /// Offset added to unix seconds before taking the calendar day (habit
  /// records, recurring occurrences). Production: the device's local offset
  /// (see spike note, open question on time zones).
  final int dayOffsetSeconds;

  /// D17 says one identity group per chunk; > 1 batches groups (measured).
  final int groupsPerChunk;
  final int maxCellsPerChunk;

  /// 1-based chunk index (within this run) whose transaction throws after its
  /// writes, before commit.
  final int? failInsideChunk;
  final void Function(ChunkTiming timing)? onChunk;

  /// Bootstrap tables and levels (S3 measures policy variants; default: D1).
  final List<SpikeTablePolicy> syncedTables;

  /// Physical clock shape of the bootstrap; null = D1 `sync_clock`.
  final BootstrapChunkWriter? bootstrapWriter;

  final List<ChunkTiming> timings = [];
  int _chunksThisRun = 0;
  final Map<String, List<String>> _columnCache = {};

  Future<List<Map<String, Object?>>> _select(String sql, [List<Object?> args = const []]) async =>
      (await db.customSelect(sql, variables: [for (final a in args) _variable(a)]).get()).map((r) => r.data).toList();

  static Variable<Object> _variable(Object? value) {
    if (value == null) return const Variable<Object>(null);
    if (value is int) return Variable<int>(value);
    if (value is String) return Variable<String>(value);
    throw ArgumentError.value(value, 'value');
  }

  Future<List<String>> columnsOf(String table) async =>
      _columnCache[table] ??= [for (final row in await _select('PRAGMA table_info("$table")')) row['name'] as String];

  Future<Map<String, Object?>> _state() async => (await _select('SELECT * FROM sync_state WHERE id = 1')).single;

  /// Runs until done, or until [stopAfterChunks] chunk transactions have
  /// committed (simulated kill between chunks).
  Future<JobRunResult> run({int? stopAfterChunks}) async {
    _chunksThisRun = 0;
    await db.customStatement(
        'UPDATE sync_state SET upgrade_started_at = COALESCE(upgrade_started_at, ?) WHERE id = 1', [nowMs]);
    while (true) {
      final state = await _state();
      final phase = state['upgrade_phase'] as String;
      if (phase == SpikeSyncSchema.phaseDone) return JobRunResult(done: true, chunks: _chunksThisRun);
      if (stopAfterChunks != null && _chunksThisRun >= stopAfterChunks) {
        return JobRunResult(done: false, chunks: _chunksThisRun);
      }
      final cursor = state['upgrade_cursor'] as String?;
      if (phase == SpikeSyncSchema.phaseDedupe) {
        await _dedupeStep(cursor, stopAfterChunks);
      } else if (phase == SpikeSyncSchema.phaseBootstrap) {
        await _bootstrapStep(cursor, state, stopAfterChunks);
      } else {
        throw StateError('Unknown phase $phase');
      }
    }
  }

  (int, String) _splitCursor(String? cursor) {
    if (cursor == null) return (0, '');
    final i = cursor.indexOf('|');
    return (int.parse(cursor.substring(0, i)), cursor.substring(i + 1));
  }

  Future<void> _setPhase(String phase, String? cursor) =>
      db.customStatement('UPDATE sync_state SET upgrade_phase = ?, upgrade_cursor = ? WHERE id = 1', [phase, cursor]);

  bool _budgetLeft(int? stopAfterChunks) => stopAfterChunks == null || _chunksThisRun < stopAfterChunks;

  Future<T> _chunk<T>(String phase, String label, int Function(T) units, Future<T> Function() body) async {
    final index = ++_chunksThisRun;
    final sw = Stopwatch()..start();
    final result = await db.transaction(() async {
      await db.customStatement('UPDATE sync_state SET apply_mode = ? WHERE id = 1', [SpikeSyncSchema.applyModeUpgrade]);
      final r = await body();
      await db.customStatement('UPDATE sync_state SET apply_mode = 0 WHERE id = 1');
      if (failInsideChunk == index) throw SimulatedCrash();
      return r;
    });
    sw.stop();
    final timing = ChunkTiming(phase, label, sw.elapsed, units(result));
    timings.add(timing);
    onChunk?.call(timing);
    return result;
  }

  // -- dedupe ---------------------------------------------------------------

  Future<List<_Group>> _pendingGroups(DedupeFamily family, String afterKey) async {
    final rows = await _select(family.selectSql, family.usesDayOffset ? [dayOffsetSeconds] : const []);
    final groups = <String, _Group>{};
    final k1s = <String, (String, String?)>{};
    for (final row in rows) {
      final k1 = row['k1'] as String;
      final k2 = row['k2'] as String?;
      final key = k2 == null ? k1 : '$k1|$k2';
      k1s[key] = (k1, k2);
      groups.putIfAbsent(key, () => _Group(key)).members.add(_Member(
            row['id'] as String,
            row['created_date'] as int,
            row['modified_date'] as int?,
            row['deleted_date'] as int?,
            (row['is_root'] as int) == 1,
          ));
    }
    final result = <_Group>[];
    for (final group in groups.values) {
      if (group.key.compareTo(afterKey) <= 0) continue;
      final roots = group.members.where((m) => m.isRoot).toList();
      if (roots.length > 1) throw StateError('Two series roots in ${group.key}');
      group.rootId = roots.isEmpty ? null : roots.single.id;
      final (k1, k2) = k1s[group.key]!;
      group.survivorId = group.rootId ?? family.survivorIdOf(k1, k2);
      final sorted = List.of(group.members)..sort(_compareSurvivorCandidates);
      group.sourceId = sorted.first.id;
      if (group.pending) result.add(group);
    }
    result.sort((a, b) => a.key.compareTo(b.key));
    return result;
  }

  Future<void> _dedupeStep(String? cursor, int? stopAfterChunks) async {
    final (familyIndex, afterKey) = _splitCursor(cursor);
    if (familyIndex >= dedupeFamilies.length) {
      await _setPhase(SpikeSyncSchema.phaseBootstrap, null);
      return;
    }
    final family = dedupeFamilies[familyIndex];
    final pending = await _pendingGroups(family, afterKey);
    var i = 0;
    while (i < pending.length) {
      if (!_budgetLeft(stopAfterChunks)) return;
      final batch = pending.sublist(i, (i + groupsPerChunk).clamp(0, pending.length));
      await _chunk<int>(SpikeSyncSchema.phaseDedupe, '${family.name}:${batch.first.key}', (n) => n, () async {
        for (final group in batch) {
          await _mergeGroup(family, group);
        }
        await db.customStatement(
            'UPDATE sync_state SET upgrade_cursor = ? WHERE id = 1', ['$familyIndex|${batch.last.key}']);
        return batch.length;
      });
      i += batch.length;
    }
    await db.customStatement('UPDATE sync_state SET upgrade_cursor = ? WHERE id = 1', ['${familyIndex + 1}|']);
  }

  /// One identity group: write the survivor under its deterministic id with
  /// the source row's values, rewrite FKs from every loser, delete losers.
  Future<void> _mergeGroup(DedupeFamily family, _Group group) async {
    final table = family.table;
    final columns = await columnsOf(table);
    final memberIds = group.members.map((m) => m.id).toSet();
    final survivor = group.survivorId;
    final source = group.sourceId;

    final existing = await _select('SELECT id FROM "$table" WHERE id = ?', [survivor]);
    if (existing.isNotEmpty && !memberIds.contains(survivor)) {
      throw StateError('Deterministic id $survivor of ${group.key} is taken by a non-member');
    }

    if (source != survivor) {
      if (existing.isEmpty) {
        final list = columns.map((c) => '"$c"').join(', ');
        final select = columns.map((c) => c == 'id' ? '?' : '"$c"').join(', ');
        await db.customStatement(
            'INSERT INTO "$table" ($list) SELECT $select FROM "$table" WHERE id = ?', [survivor, source]);
      } else {
        final prefix = group.rootId != null ? family.preserveRootColumnsPrefix : null;
        final copy = columns.where((c) => c != 'id' && (prefix == null || !c.startsWith(prefix))).toList();
        final targets = copy.map((c) => '"$c"').join(', ');
        await db.customStatement(
            'UPDATE "$table" SET ($targets) = (SELECT $targets FROM "$table" WHERE id = ?) WHERE id = ?',
            [source, survivor]);
      }
    }

    final losers = memberIds.where((id) => id != survivor).toList()..sort();
    if (losers.isEmpty) return;
    final marks = List.filled(losers.length, '?').join(', ');
    for (final (childTable, column) in fkRewriteList[table] ?? const <(String, String)>[]) {
      await db
          .customStatement('UPDATE "$childTable" SET "$column" = ? WHERE "$column" IN ($marks)', [survivor, ...losers]);
    }
    await db.customStatement('DELETE FROM "$table" WHERE id IN ($marks)', losers);
  }

  // -- bootstrap ------------------------------------------------------------

  Future<void> _bootstrapStep(String? cursor, Map<String, Object?> state, int? stopAfterChunks) async {
    var (tableIndex, afterPk) = (0, '');
    if (cursor != null) {
      final (tblId, pk) = _splitCursor(cursor);
      tableIndex = syncedTables.indexWhere((t) => t.tblId == tblId);
      if (tableIndex < 0) tableIndex = syncedTables.length;
      afterPk = pk;
    }
    if (tableIndex >= syncedTables.length) {
      await _setPhase(SpikeSyncSchema.phaseDone, null);
      return;
    }
    final policy = syncedTables[tableIndex];
    final columns = await columnsOf(policy.table);
    final synced = columns.where((c) => !auditColumns.contains(c)).toList();
    final colIds =
        policy.fieldLevel ? [tombstoneColId, for (var i = 1; i <= synced.length; i++) i] : [tombstoneColId, rowColId];
    final rowsPerChunk = (maxCellsPerChunk ~/ colIds.length).clamp(1, 1 << 30);
    final nodeId = state['member_node_id'] as int;
    final originId = state['local_origin_id'] as int;
    final recordedAt = state['upgrade_started_at'] as int;

    while (true) {
      if (!_budgetLeft(stopAfterChunks)) return;
      final window = (await _select(
        'SELECT MAX(id) AS last_id, COUNT(*) AS n FROM '
        '(SELECT id FROM "${policy.table}" WHERE id > ? ORDER BY id LIMIT ?)',
        [afterPk, rowsPerChunk],
      ))
          .single;
      final n = window['n'] as int;
      if (n == 0) {
        final next = tableIndex + 1 < syncedTables.length ? syncedTables[tableIndex + 1].tblId : 1 << 30;
        await db.customStatement('UPDATE sync_state SET upgrade_cursor = ? WHERE id = 1', ['$next|']);
        return;
      }
      final lastId = window['last_id'] as String;
      final from = afterPk;
      await _chunk<int>(SpikeSyncSchema.phaseBootstrap, '${policy.table}@$from', (c) => c, () async {
        final s = await _state();
        final baseSeq = s['next_seq'] as int;
        final writer = bootstrapWriter;
        if (writer != null) {
          final (inserted, maxHlc) = await writer(
              db,
              BootstrapChunk(
                policy: policy,
                colIds: colIds,
                from: from,
                lastId: lastId,
                nodeId: nodeId,
                originId: originId,
                baseSeq: baseSeq,
                recordedAt: recordedAt,
              ));
          await db.customStatement(
              'UPDATE sync_state SET next_seq = next_seq + ?, hlc = MAX(hlc, ?), upgrade_cursor = ? WHERE id = 1',
              [inserted, maxHlc, '${policy.tblId}|$lastId']);
          return inserted;
        }
        final colValues = colIds.map((c) => '($c)').join(', ');
        await db.customStatement('''
WITH r AS (
  SELECT id, created_date, modified_date, deleted_date FROM "${policy.table}" WHERE id > ? AND id <= ?
),
cols(col_id) AS (VALUES $colValues),
cells AS (
  SELECT r.id AS pk, cols.col_id AS col_id,
         (MAX(r.created_date, COALESCE(r.modified_date, 0), COALESCE(r.deleted_date, 0)) * 1000) << 16 AS hlc,
         CASE WHEN cols.col_id = $tombstoneColId THEN r.deleted_date END AS tomb
  FROM r CROSS JOIN cols
  WHERE NOT EXISTS (SELECT 1 FROM sync_clock s WHERE s.tbl_id = ? AND s.pk = r.id AND s.col_id = cols.col_id)
)
INSERT OR IGNORE INTO sync_clock
  (tbl_id, pk, col_id, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value, cause_tbl_id, cause_pk, recorded_at)
SELECT ?, pk, col_id, hlc, ?, ?, ? + ROW_NUMBER() OVER (ORDER BY pk, col_id) - 1, NULL, tomb, NULL, NULL, ?
FROM cells ORDER BY pk, col_id''', [from, lastId, policy.tblId, policy.tblId, nodeId, originId, baseSeq, recordedAt]);
        final inserted = (await _select('SELECT changes() AS c')).single['c'] as int;
        await db.customStatement('''
UPDATE sync_state SET
  next_seq = next_seq + ?,
  hlc = MAX(hlc, COALESCE((SELECT MAX(hlc) FROM sync_clock WHERE tbl_id = ? AND pk > ? AND pk <= ?), 0)),
  upgrade_cursor = ?
WHERE id = 1''', [inserted, policy.tblId, from, lastId, '${policy.tblId}|$lastId']);
        return inserted;
      });
      afterPk = lastId;
    }
  }
}

// ---------------------------------------------------------------------------
// Checksum (acceptance 3, 4, 5)
// ---------------------------------------------------------------------------

/// Deterministic sha256 over every user table (rows sorted by id, all
/// columns), plus `sync_clock` (sorted by PK), `sync_intern` and `sync_state`
/// unless [includeSync] is false.
Future<String> databaseChecksum(GeneratedDatabase db, {bool includeSync = true}) async {
  final names = (await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
          .get())
      .map((r) => r.data['name'] as String)
      .where((n) => includeSync || !n.startsWith('sync_') || n == 'sync_device_table')
      .toList();
  final sink = _DigestSink();
  final input = sha256.startChunkedConversion(sink);
  void add(String s) => input.add(utf8.encode(s));
  for (final name in names) {
    final order = name == 'sync_clock' ? 'tbl_id, pk, col_id' : 'id';
    add('#$name\n');
    const pageSize = 20000;
    var offset = 0;
    while (true) {
      final rows = await db.customSelect('SELECT * FROM "$name" ORDER BY $order LIMIT $pageSize OFFSET $offset').get();
      for (final row in rows) {
        add(row.data.entries.map((e) => '${e.key}=${_encode(e.value)}').join('\u001f'));
        add('\n');
      }
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
  }
  input.close();
  return sink.value.toString();
}

String _encode(Object? v) => switch (v) {
      null => 'N',
      int i => 'i$i',
      double d => 'd$d',
      String s => 's${jsonEncode(s)}',
      Uint8List b => 'b${base64.encode(b)}',
      _ => 'o$v',
    };

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
