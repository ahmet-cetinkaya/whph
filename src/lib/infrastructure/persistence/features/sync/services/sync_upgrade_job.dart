import 'package:drift/drift.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';

/// D17: the resumable upgrade job. Production port of the S5 spike
/// (`spikes/S5-dedupe.md`). Phases, each chunked in its own transaction with
/// the resume position stored in `sync_state.upgrade_cursor`:
///
/// - `dedupe`: D5 identity groups (survivor rule, FK rewrite, link collapse,
///   loser-edit clock migration) under `apply_mode = 4`;
/// - `bootstrap`: D6 clock rows for every pre-existing cell, `INSERT OR IGNORE`
///   so a user edit made between chunks keeps its newer trigger clock;
/// - `reauthor`: D6b, owned by T18.
///
/// Triggers stamp only at `apply_mode = 0`, so chunk transactions never
/// capture their own writes while user edits between chunks do.
class SyncUpgradeJob implements ISyncUpgradeService {
  static const String _stateId = 'singleton';
  static const int _applyModeCapture = 0;
  static const int _applyModeUpgrade = 4;

  /// D17 bootstrap chunk bound (cells per transaction).
  static const int maxBootstrapCellsPerChunk = 5000;

  /// S5 D-5: several groups per dedupe chunk under a row budget keeps one
  /// chunk transaction within 2 s.
  static const int maxGroupsPerChunk = 250;
  static const int maxMembersPerChunk = 1000;

  static const String _cursorSeparator = '|';
  static const int _secondsToMs = 1000;
  static const int _hlcLogicalBits = 16;

  final GeneratedDatabase _db;
  final int Function() _nowMs;
  final void Function(UpgradeChunkTiming timing)? onChunk;

  final Map<String, List<String>> _columnCache = {};
  Future<void>? _running;
  int _recordedAt = 0;
  int _chunksThisRun = 0;

  SyncUpgradeJob(this._db, {int Function()? nowMs, this.onChunk})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  @override
  Future<SyncUpgradeProgress> getProgress() async {
    final state = await _state();
    return SyncUpgradeProgress(
      phase: _phaseOf(state['upgrade_phase'] as String?),
      cursor: state['upgrade_cursor'] as String?,
    );
  }

  @override
  Future<void> run() =>
      _running ??= runChunks().then((_) {}).whenComplete(() => _running = null);

  /// Runs until `done`, or until [stopAfterChunks] chunk transactions have
  /// committed (a kill between chunks, for tests). Returns whether it is done.
  Future<bool> runChunks({int? stopAfterChunks}) async {
    _chunksThisRun = 0;
    _recordedAt = _nowMs();
    while (true) {
      final state = await _state();
      final phase = _phaseOf(state['upgrade_phase'] as String?);
      if (phase == SyncUpgradePhase.done) return true;
      if (!_hasChunkBudget(stopAfterChunks)) return false;
      final cursor = state['upgrade_cursor'] as String?;
      switch (phase) {
        case SyncUpgradePhase.dedupe:
          await _dedupeStep(cursor, stopAfterChunks);
        case SyncUpgradePhase.bootstrap:
          await _bootstrapStep(cursor, stopAfterChunks);
        case SyncUpgradePhase.reauthor:
          await _reauthorStep(state);
        case SyncUpgradePhase.done:
          return true;
      }
    }
  }

  // -- shared helpers -------------------------------------------------------

  /// A null phase means no upgrade was ever scheduled (fresh database).
  SyncUpgradePhase _phaseOf(String? name) => name == null
      ? SyncUpgradePhase.done
      : SyncUpgradePhase.values.byName(name);

  Future<List<Map<String, Object?>>> _select(String sql,
          [List<Object?> args = const []]) async =>
      (await _db.customSelect(sql,
              variables: [for (final arg in args) _variable(arg)]).get())
          .map((row) => row.data)
          .toList();

  static Variable<Object> _variable(Object? value) {
    if (value == null) return const Variable<Object>(null);
    if (value is int) return Variable<int>(value);
    if (value is String) return Variable<String>(value);
    throw ArgumentError.value(value, 'value');
  }

  Future<Map<String, Object?>> _state() async =>
      (await _select('SELECT * FROM sync_state WHERE id = ?', [_stateId]))
          .single;

  Future<List<String>> _columnsOf(String table) async =>
      _columnCache[table] ??= [
        for (final row in await _select('PRAGMA table_info("$table")'))
          row['name'] as String
      ];

  Future<void> _setPhase(SyncUpgradePhase phase, String? cursor) =>
      _db.customStatement(
          'UPDATE sync_state SET upgrade_phase = ?, upgrade_cursor = ? WHERE id = ?',
          [phase.name, cursor, _stateId]);

  Future<void> _setCursor(String cursor) => _db.customStatement(
      'UPDATE sync_state SET upgrade_cursor = ? WHERE id = ?',
      [cursor, _stateId]);

  bool _hasChunkBudget(int? stopAfterChunks) =>
      stopAfterChunks == null || _chunksThisRun < stopAfterChunks;

  (int, String) _splitCursor(String? cursor) {
    if (cursor == null) return (0, '');
    final separatorAt = cursor.indexOf(_cursorSeparator);
    return (
      int.parse(cursor.substring(0, separatorAt)),
      cursor.substring(separatorAt + 1)
    );
  }

  Future<T> _inChunk<T>(SyncUpgradePhase phase, String label,
      int Function(T) unitsOf, Future<T> Function() body) async {
    _chunksThisRun++;
    final stopwatch = Stopwatch()..start();
    final result = await _db.transaction(() async {
      await _setApplyMode(_applyModeUpgrade);
      final value = await body();
      await _setApplyMode(_applyModeCapture);
      return value;
    });
    stopwatch.stop();
    onChunk?.call(
        UpgradeChunkTiming(phase, label, stopwatch.elapsed, unitsOf(result)));
    return result;
  }

  Future<void> _setApplyMode(int mode) => _db.customStatement(
      'UPDATE sync_state SET apply_mode = ? WHERE id = ?', [mode, _stateId]);

  // -- dedupe ---------------------------------------------------------------

  Future<List<_Group>> _pendingGroups(
      DedupeFamily family, String afterKey) async {
    final groups = <String, _Group>{};
    final keyParts = <String, (String, String?)>{};
    for (final row in await _select(family.selectSql)) {
      final k1 = row['k1'] as String;
      final k2 = row['k2'] as String?;
      final key = k2 == null ? k1 : '$k1$_cursorSeparator$k2';
      keyParts[key] = (k1, k2);
      groups.putIfAbsent(key, () => _Group(key)).members.add(_Member(
            row['id'] as String,
            row['created_date'] as int,
            row['modified_date'] as int?,
            row['deleted_date'] as int?,
            (row['is_root'] as int) == 1,
          ));
    }
    final pending = <_Group>[];
    for (final group in groups.values) {
      if (group.key.compareTo(afterKey) <= 0) continue;
      final roots = group.members.where((member) => member.isRoot).toList();
      if (roots.length > 1)
        throw StateError('Two series roots in ${group.key}');
      group.rootId = roots.isEmpty ? null : roots.single.id;
      final (k1, k2) = keyParts[group.key]!;
      group.survivorId = group.rootId ?? family.survivorIdOf(k1, k2);
      group.sourceId =
          (List.of(group.members)..sort(_compareSurvivorCandidates)).first.id;
      if (group.isPending) pending.add(group);
    }
    return pending..sort((a, b) => a.key.compareTo(b.key));
  }

  Future<void> _dedupeStep(String? cursor, int? stopAfterChunks) async {
    final (familyIndex, afterKey) = _splitCursor(cursor);
    if (familyIndex >= dedupeFamilies.length) {
      await _setPhase(SyncUpgradePhase.bootstrap, null);
      return;
    }
    final family = dedupeFamilies[familyIndex];
    final pending = await _pendingGroups(family, afterKey);
    var next = 0;
    while (next < pending.length) {
      if (!_hasChunkBudget(stopAfterChunks)) return;
      final batch = _nextBatch(pending, next);
      await _inChunk<int>(SyncUpgradePhase.dedupe,
          '${family.name}:${batch.first.key}', (count) => count, () async {
        for (final group in batch) {
          await _mergeGroup(family, group);
        }
        await _setCursor('$familyIndex$_cursorSeparator${batch.last.key}');
        return batch.length;
      });
      next += batch.length;
    }
    await _setCursor('${familyIndex + 1}$_cursorSeparator');
  }

  List<_Group> _nextBatch(List<_Group> pending, int start) {
    var members = 0;
    var end = start;
    while (end < pending.length && end - start < maxGroupsPerChunk) {
      members += pending[end].members.length;
      end++;
      if (members >= maxMembersPerChunk) break;
    }
    return pending.sublist(start, end);
  }

  /// One identity group: write the survivor under its deterministic id with
  /// the source row's values, move loser clock rows, rewrite FKs, delete losers.
  Future<void> _mergeGroup(DedupeFamily family, _Group group) async {
    final table = family.table;
    final columns = await _columnsOf(table);
    final memberIds = group.members.map((member) => member.id).toSet();
    final survivor = group.survivorId;

    final existing =
        await _select('SELECT id FROM "$table" WHERE id = ?', [survivor]);
    if (existing.isNotEmpty && !memberIds.contains(survivor)) {
      throw StateError(
          'Deterministic id $survivor of ${group.key} is taken by a non-member');
    }
    if (group.sourceId != survivor) {
      await _writeSurvivor(family, group, columns,
          survivorExists: existing.isNotEmpty);
    }

    final losers = memberIds.where((id) => id != survivor).toList()..sort();
    if (losers.isEmpty) return;
    await _moveLoserClocks(family, group, columns, losers);
    final marks = List.filled(losers.length, '?').join(', ');
    for (final (childTable, column)
        in fkRewriteList[table] ?? const <(String, String)>[]) {
      await _db.customStatement(
          'UPDATE "$childTable" SET "$column" = ? WHERE "$column" IN ($marks)',
          [survivor, ...losers]);
    }
    await _db.customStatement(
        'DELETE FROM "$table" WHERE id IN ($marks)', losers);
  }

  Future<void> _writeSurvivor(
      DedupeFamily family, _Group group, List<String> columns,
      {required bool survivorExists}) async {
    final table = family.table;
    if (!survivorExists) {
      final list = columns.map((column) => '"$column"').join(', ');
      final select = columns
          .map((column) => column == 'id' ? '?' : '"$column"')
          .join(', ');
      await _db.customStatement(
          'INSERT INTO "$table" ($list) SELECT $select FROM "$table" WHERE id = ?',
          [group.survivorId, group.sourceId]);
      return;
    }
    final prefix =
        group.rootId != null ? family.preserveRootColumnsPrefix : null;
    final copied = columns.where((column) =>
        column != 'id' && (prefix == null || !column.startsWith(prefix)));
    await _copyColumns(table, copied.toList(),
        from: group.sourceId, to: group.survivorId);
  }

  Future<void> _copyColumns(String table, List<String> columns,
      {required String from, required String to}) {
    final targets = columns.map((column) => '"$column"').join(', ');
    final assignment = columns.length == 1
        ? '$targets = (SELECT $targets FROM "$table" WHERE id = ?)'
        : '($targets) = (SELECT $targets FROM "$table" WHERE id = ?)';
    return _db.customStatement(
        'UPDATE "$table" SET $assignment WHERE id = ?', [from, to]);
  }

  /// D17 "User edits to a dedupe loser": per cell, the survivor takes the
  /// value and clock of the highest `(hlc, node)` among itself and its losers.
  Future<void> _moveLoserClocks(DedupeFamily family, _Group group,
      List<String> columns, List<String> losers) async {
    final policy = _policyOf(family.table);
    if (policy == null) return;
    final memberRows =
        await _clockRowsOf(policy.tblId, {...losers, group.survivorId});
    if (memberRows.isEmpty) return;

    final survivorRowId = await _ensureSyncRow(policy.tblId, group.survivorId);
    final winners = await _winningCells(memberRows.keys);
    final protectedPrefix =
        group.rootId != null ? family.preserveRootColumnsPrefix : null;
    for (final cell in winners.values) {
      final winnerPk = memberRows[cell.rowId]!;
      if (winnerPk != group.survivorId) {
        final copied =
            _cellColumns(policy, cell.colId, columns, protectedPrefix);
        if (copied.isNotEmpty)
          await _copyColumns(family.table, copied,
              from: winnerPk, to: group.survivorId);
      }
      if (cell.rowId != survivorRowId)
        await _relocateClock(
            cell.key, survivorRowId * packedKeyFactor + cell.colId);
    }
    for (final loserRowId
        in memberRows.keys.where((id) => id != survivorRowId)) {
      await _db.customStatement(
          'UPDATE sync_clock SET cause_row_id = ? WHERE cause_row_id = ?',
          [survivorRowId, loserRowId]);
      await _db.customStatement(
          'DELETE FROM sync_clock WHERE key >= ? AND key < ?',
          [loserRowId * packedKeyFactor, (loserRowId + 1) * packedKeyFactor]);
      await _db
          .customStatement('DELETE FROM sync_row WHERE id = ?', [loserRowId]);
    }
  }

  SyncTablePolicy? _policyOf(String table) {
    for (final policy in syncTablePolicies) {
      if (policy.tableName == table) return policy;
    }
    return null;
  }

  /// Interned row id -> pk for those of [pks] that have a `sync_row`.
  Future<Map<int, String>> _clockRowsOf(int tblId, Set<String> pks) async {
    final marks = List.filled(pks.length, '?').join(', ');
    final rows = await _select(
        'SELECT id, pk FROM sync_row WHERE tbl_id = ? AND pk IN ($marks)',
        [tblId, ...pks]);
    return {for (final row in rows) row['id'] as int: row['pk'] as String};
  }

  Future<int> _ensureSyncRow(int tblId, String pk) async {
    await _db.customStatement(
        'INSERT OR IGNORE INTO sync_row (tbl_id, pk) VALUES (?, ?)',
        [tblId, pk]);
    return (await _select(
            'SELECT id FROM sync_row WHERE tbl_id = ? AND pk = ?', [tblId, pk]))
        .single['id'] as int;
  }

  Future<Map<int, _ClockCell>> _winningCells(Iterable<int> rowIds) async {
    final winners = <int, _ClockCell>{};
    for (final rowId in rowIds) {
      final rows = await _select(
          'SELECT key, hlc, node_id FROM sync_clock WHERE key >= ? AND key < ?',
          [rowId * packedKeyFactor, (rowId + 1) * packedKeyFactor]);
      for (final row in rows) {
        final cell = _ClockCell(
            row['key'] as int, row['hlc'] as int, row['node_id'] as int);
        final current = winners[cell.colId];
        if (current == null || cell.beats(current)) winners[cell.colId] = cell;
      }
    }
    return winners;
  }

  /// Columns of the survivor row that the winning cell [colId] governs.
  List<String> _cellColumns(SyncTablePolicy policy, int colId,
      List<String> columns, String? protectedPrefix) {
    if (colId == tombstoneColId) return ['deleted_date'];
    if (!policy.rowLevel) {
      return [
        for (final entry in policy.columns.entries)
          if (entry.value == colId) entry.key
      ];
    }
    return [
      for (final column in columns)
        if (!SyncTablePolicy.excludedColumns.contains(column) &&
            (protectedPrefix == null || !column.startsWith(protectedPrefix)))
          column
    ];
  }

  Future<void> _relocateClock(int fromKey, int toKey) async {
    await _db.customStatement('''
INSERT INTO sync_clock (key, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value, cause_row_id, recorded_at)
SELECT ?, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value, cause_row_id, recorded_at
FROM sync_clock WHERE key = ?
ON CONFLICT (key) DO UPDATE SET
  hlc = excluded.hlc, node_id = excluded.node_id, origin_id = excluded.origin_id,
  origin_seq = excluded.origin_seq, manifest_id = excluded.manifest_id, tomb_value = excluded.tomb_value,
  cause_row_id = excluded.cause_row_id, recorded_at = excluded.recorded_at''',
        [toKey, fromKey]);
  }

  // -- bootstrap ------------------------------------------------------------

  Future<void> _bootstrapStep(String? cursor, int? stopAfterChunks) async {
    final (tblId, afterPk) = cursor == null
        ? (syncTablePolicies.first.tblId, '')
        : _splitCursor(cursor);
    final policyIndex =
        syncTablePolicies.indexWhere((policy) => policy.tblId >= tblId);
    if (policyIndex < 0) {
      await _setPhase(SyncUpgradePhase.reauthor, null);
      return;
    }
    final policy = syncTablePolicies[policyIndex];
    final colIds = _bootstrapColumnIds(policy);
    final rowsPerChunk = (maxBootstrapCellsPerChunk ~/ colIds.length)
        .clamp(1, maxBootstrapCellsPerChunk);

    var lastPk = afterPk;
    while (_hasChunkBudget(stopAfterChunks)) {
      final window = (await _select(
        'SELECT MAX(id) AS last_id, COUNT(*) AS n FROM (SELECT id FROM "${policy.tableName}" WHERE id > ? ORDER BY id LIMIT ?)',
        [lastPk, rowsPerChunk],
      ))
          .single;
      if ((window['n'] as int) == 0) {
        await _setCursor('${policy.tblId + 1}$_cursorSeparator');
        return;
      }
      final windowEnd = window['last_id'] as String;
      await _inChunk<int>(
          SyncUpgradePhase.bootstrap,
          '${policy.tableName}@$lastPk',
          (cells) => cells,
          () => _bootstrapChunk(policy, colIds, from: lastPk, to: windowEnd));
      lastPk = windowEnd;
    }
  }

  List<int> _bootstrapColumnIds(SyncTablePolicy policy) => [
        tombstoneColId,
        if (policy.rowLevel) rowLevelColId else ...policy.columns.values
      ];

  /// Clock rows for rows of [policy] with `from < id <= to`; returns cells inserted.
  Future<int> _bootstrapChunk(SyncTablePolicy policy, List<int> colIds,
      {required String from, required String to}) async {
    final table = policy.tableName;
    final liveState = await _state();
    final baseSeq = liveState['next_seq'] as int;
    final lastTouchedSeconds =
        'MAX(t.created_date, COALESCE(t.modified_date, 0), COALESCE(t.deleted_date, 0))';
    final hlcOf = '($lastTouchedSeconds * $_secondsToMs) << $_hlcLogicalBits';
    final colValues = colIds.map((colId) => '($colId)').join(', ');

    await _db.customStatement(
        'INSERT OR IGNORE INTO sync_row (tbl_id, pk) SELECT ?, id FROM "$table" WHERE id > ? AND id <= ?',
        [policy.tblId, from, to]);
    await _db.customStatement('''
WITH cols(col_id) AS (VALUES $colValues),
cells AS (
  SELECT r.id * $packedKeyFactor + cols.col_id AS key, $hlcOf AS hlc,
         CASE WHEN cols.col_id = $tombstoneColId THEN t.deleted_date END AS tomb_value
  FROM "$table" AS t
  JOIN sync_row AS r ON r.tbl_id = ? AND r.pk = t.id
  CROSS JOIN cols
  WHERE t.id > ? AND t.id <= ?
    AND NOT EXISTS (SELECT 1 FROM sync_clock c WHERE c.key = r.id * $packedKeyFactor + cols.col_id)
)
INSERT OR IGNORE INTO sync_clock
  (key, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value, cause_row_id, recorded_at)
SELECT key, hlc, ?, ?, ? + ROW_NUMBER() OVER (ORDER BY key) - 1, NULL, tomb_value, NULL, ?
FROM cells ORDER BY key''', [
      policy.tblId,
      from,
      to,
      liveState['node_id'] as int,
      liveState['origin_id'] as int,
      baseSeq,
      _recordedAt,
    ]);
    final inserted = (await _select('SELECT changes() AS inserted'))
        .single['inserted'] as int;
    final maxHlc = (await _select(
      'SELECT MAX($hlcOf) AS max_hlc FROM "$table" AS t WHERE t.id > ? AND t.id <= ?',
      [from, to],
    ))
        .single['max_hlc'] as int;
    await _db.customStatement(
        'UPDATE sync_state SET next_seq = next_seq + ?, hlc = MAX(hlc, ?), upgrade_cursor = ? WHERE id = ?',
        [inserted, maxHlc, '${policy.tblId}$_cursorSeparator$to', _stateId]);
    return inserted;
  }

  // -- reauthor -------------------------------------------------------------

  /// D6b `reauthor` belongs to T18. Without a spec there is nothing to do;
  /// with one this job cannot honour it yet, so it refuses instead of
  /// declaring `done` over unprocessed rows.
  Future<void> _reauthorStep(Map<String, Object?> state) async {
    if (state['reauthor_spec'] != null) {
      throw UnsupportedError(
          'reauthor_spec is processed by the T18 reauthor phase');
    }
    await _setPhase(SyncUpgradePhase.done, null);
  }
}

/// Timing of one committed chunk transaction (D17: each <= 2 s).
class UpgradeChunkTiming {
  final SyncUpgradePhase phase;

  /// Family and first key for dedupe chunks, `table@cursor` for bootstrap chunks.
  final String label;
  final Duration elapsed;

  /// Groups (dedupe) or cells (bootstrap) processed.
  final int units;

  UpgradeChunkTiming(this.phase, this.label, this.elapsed, this.units);
}

// ---------------------------------------------------------------------------
// Dedupe families (D5, S5 D-1..D-8)
// ---------------------------------------------------------------------------

class _Member {
  final String id;
  final int created;
  final int? modified;
  final int? deleted;
  final bool isRoot;

  _Member(this.id, this.created, this.modified, this.deleted, this.isRoot);

  int get effectiveModified => modified ?? created;
  bool get isLive => deleted == null;
}

class _Group {
  final String key;
  final List<_Member> members = [];
  late String survivorId;
  late String sourceId;
  String? rootId;

  _Group(this.key);

  bool get isPending => members.length > 1 || members.single.id != survivorId;
}

class _ClockCell {
  final int key;
  final int hlc;
  final int nodeId;

  _ClockCell(this.key, this.hlc, this.nodeId);

  int get rowId => key ~/ packedKeyFactor;
  int get colId => key % packedKeyFactor;

  bool beats(_ClockCell other) =>
      hlc != other.hlc ? hlc > other.hlc : nodeId > other.nodeId;
}

/// D5 survivor rule: live beats soft-deleted, then latest
/// `modified_date ?? created_date`, then smallest old id.
int _compareSurvivorCandidates(_Member a, _Member b) {
  if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
  final byDate = b.effectiveModified.compareTo(a.effectiveModified);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

class DedupeFamily {
  final String name;
  final String table;

  /// Selects `id, created_date, modified_date, deleted_date, k1, k2, is_root`
  /// (k2 may be NULL, is_root 0/1).
  final String selectSql;
  final String Function(String k1, String? k2) survivorIdOf;

  /// For groups containing a recurring series root: the root keeps its id and
  /// its columns with this prefix (the series definition).
  final String? preserveRootColumnsPrefix;

  const DedupeFamily({
    required this.name,
    required this.table,
    required this.selectSql,
    required this.survivorIdOf,
    this.preserveRootColumnsPrefix,
  });
}

String _linkId(String kind, String k1, String? k2) =>
    syncIdentityId(kind, [k1, k2!]);

DedupeFamily _linkFamily(
        String name, String kind, String firstKey, String secondKey) =>
    DedupeFamily(
      name: name,
      table: '${name}_table',
      selectSql:
          'SELECT id, created_date, modified_date, deleted_date, $firstKey AS k1, $secondKey AS k2, '
          '0 AS is_root FROM ${name}_table',
      survivorIdOf: (k1, k2) => _linkId(kind, k1, k2),
    );

/// U9/PA-5: the re-key day is the UTC calendar day (SQLite `strftime` on
/// unix seconds is UTC).
String _utcDayOf(String column) => "strftime('%Y-%m-%d', $column, 'unixepoch')";

/// Fixed family order. Later families' keys depend on earlier families' ids
/// (links use re-keyed task ids), so groups are computed when the job enters
/// a family.
final List<DedupeFamily> dedupeFamilies = [
  DedupeFamily(
    name: 'builtin_task_status',
    table: 'task_status_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, '
        "CASE WHEN is_done_status = 1 THEN 'done' ELSE 'todo' END AS k1, NULL AS k2, 0 AS is_root "
        'FROM task_status_table WHERE is_built_in = 1',
    survivorIdOf: (k1, _) =>
        k1 == 'done' ? TaskStatusConstants.doneId : TaskStatusConstants.todoId,
  ),
  DedupeFamily(
    name: 'setting',
    table: 'setting_table',
    selectSql:
        'SELECT id, created_date, modified_date, deleted_date, key AS k1, NULL AS k2, 0 AS is_root '
        'FROM setting_table',
    survivorIdOf: (k1, _) => syncIdentityId(identityKindSetting, [k1]),
  ),
  DedupeFamily(
    name: 'legacy_sync_device',
    table: 'sync_device_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, '
        'MIN(from_device_id, to_device_id) AS k1, MAX(from_device_id, to_device_id) AS k2, 0 AS is_root '
        'FROM sync_device_table',
    survivorIdOf: (k1, k2) => _linkId(identityKindPairedDevice, k1, k2),
  ),
  DedupeFamily(
    name: 'recurring_occurrence',
    table: 'task_table',
    selectSql: 'SELECT id, created_date, modified_date, deleted_date, '
        'COALESCE(recurrence_parent_id, id) AS k1, ${_utcDayOf('planned_date')} AS k2, '
        '(recurrence_parent_id IS NULL) AS is_root '
        'FROM task_table '
        'WHERE planned_date IS NOT NULL AND (recurrence_parent_id IS NOT NULL OR recurrence_type <> 0)',
    survivorIdOf: (k1, k2) => _linkId(identityKindRecurringTask, k1, k2),
    preserveRootColumnsPrefix: 'recurrence_',
  ),
  DedupeFamily(
    name: 'habit_record_day',
    table: 'habit_record_table',
    selectSql:
        'SELECT r.id, r.created_date, r.modified_date, r.deleted_date, r.habit_id AS k1, '
        "${_utcDayOf('r.occurred_at')} AS k2, 0 AS is_root "
        'FROM habit_record_table r JOIN habit_table h ON h.id = r.habit_id '
        'WHERE COALESCE(h.daily_target, 1) = 1',
    survivorIdOf: (k1, k2) => _linkId(identityKindHabitRecord, k1, k2),
  ),
  _linkFamily('task_tag', identityKindTaskTag, 'task_id', 'tag_id'),
  _linkFamily('habit_tag', identityKindHabitTag, 'habit_id', 'tag_id'),
  _linkFamily('note_tag', identityKindNoteTag, 'note_id', 'tag_id'),
  _linkFamily(
      'app_usage_tag', identityKindAppUsageTag, 'app_usage_id', 'tag_id'),
  _linkFamily(
      'tag_tag', identityKindTagTag, 'primary_tag_id', 'secondary_tag_id'),
];

/// Columns rewritten when a row of the key table is re-keyed or merged. Only
/// tables the dedupe phase re-keys can be keys (S5 schema scan).
const Map<String, List<(String, String)>> fkRewriteList = {
  'task_table': [
    ('task_table', 'parent_task_id'),
    ('task_table', 'recurrence_parent_id'),
    ('task_tag_table', 'task_id'),
    ('task_time_record_table', 'task_id'),
  ],
  'task_status_table': [('task_table', 'status_id')],
};
