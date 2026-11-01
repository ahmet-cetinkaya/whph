// S2 spike (plan T4) only: SQL for the D1 clock schema and the D3 capture triggers on `task_table`
// (field-level) and `task_time_record_table` (row-level). The production generator is T14; nothing here is
// used by src/lib.
//
// Pure Dart (no Flutter imports), so the unit test, the integration test and the VM concurrency test can all
// share it.

/// `~` existence cell (D1).
const int tombstoneColId = 0;

/// `*` cell of a row-level table.
const int rowLevelColId = 1;

const int taskTblId = 1;
const int taskTimeRecordTblId = 2;

/// `sync_intern.kind` values.
const int internKindNode = 1;
const int internKindOrigin = 2;

const String localNodeValue = 'spike-member-local';
const String localOriginValue = 'spike-origin-local-00000000000000';

/// D3 wall clock in ms. `test_wall_ms` is a SPIKE-ONLY override (NULL in production, never shipped) that lets the
/// counter-overflow test pin the wall clock. Column references resolve against `sync_state`.
const String wallMsSql = "COALESCE(test_wall_ms, CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER))";

class SpikeTablePolicy {
  final String tableName;
  final int tblId;
  final bool rowLevel;

  /// Synced columns (excluding `id`, `created_date`, `modified_date`, `deleted_date`) with their fixed col ids.
  final Map<String, int> columns;

  const SpikeTablePolicy({
    required this.tableName,
    required this.tblId,
    required this.rowLevel,
    required this.columns,
  });

  /// Columns every table has but that are never regular cells.
  static const Set<String> excludedColumns = {'id', 'created_date', 'modified_date', 'deleted_date'};
}

const SpikeTablePolicy taskPolicy = SpikeTablePolicy(
  tableName: 'task_table',
  tblId: taskTblId,
  rowLevel: false,
  columns: {
    'parent_task_id': 1,
    'title': 2,
    'description': 3,
    'priority': 4,
    'planned_date': 5,
    'deadline_date': 6,
    'estimated_time': 7,
    'completed_at': 8,
    'status_id': 9,
    'order': 10,
    'planned_date_reminder_time': 11,
    'deadline_date_reminder_time': 12,
    'planned_date_reminder_custom_offset': 13,
    'deadline_date_reminder_custom_offset': 14,
    'recurrence_type': 15,
    'recurrence_interval': 16,
    'recurrence_days_string': 17,
    'recurrence_start_date': 18,
    'recurrence_end_date': 19,
    'recurrence_count': 20,
    'recurrence_parent_id': 21,
    'recurrence_configuration': 22,
  },
);

const SpikeTablePolicy taskTimeRecordPolicy = SpikeTablePolicy(
  tableName: 'task_time_record_table',
  tblId: taskTimeRecordTblId,
  rowLevel: true,
  columns: {'task_id': 1, 'duration': 2},
);

const List<SpikeTablePolicy> spikePolicies = [taskPolicy, taskTimeRecordPolicy];

/// Physical row key of `sync_clock` (S3 re-run, plan amendment PA-1). The logical model (D1) is the same in all.
enum ClockRowKey {
  /// D1 as written: `PRIMARY KEY (tbl_id, pk, col_id)`, cause stored as `(cause_tbl_id, cause_pk)`.
  text,

  /// V1: `(tbl_id, pk)` interned in `sync_row(id INTEGER PRIMARY KEY, tbl_id, pk, UNIQUE(tbl_id, pk))`;
  /// `sync_clock PRIMARY KEY (row_id, col_id)`; cause stored as `cause_row_id`.
  interned,

  /// V2: like [interned], but `sync_clock` is a rowid table whose INTEGER PRIMARY KEY packs
  /// `key = row_id * 256 + col_id` (every col id < 256), so the key needs no separate index.
  packed,
}

/// `key = row_id * packedKeyFactor + col_id` in the [ClockRowKey.packed] shape.
const int packedKeyFactor = 256;

/// Physical and trigger-shape variants measured by the spike. The defaults are the recommended shape.
class SpikeSqlOptions {
  /// `sync_clock ... WITHOUT ROWID` (one b-tree) instead of a rowid table plus its PRIMARY KEY autoindex.
  final bool withoutRowid;

  /// Cause index only over rows that have a cause (`WHERE cause_pk IS NOT NULL`).
  final bool partialCauseIndex;

  /// One INSERT ... SELECT per trigger (changed cells numbered with row_number) plus one sync_state UPDATE, instead
  /// of a tick UPDATE + upsert pair per column.
  final bool compactTriggers;

  /// Physical row key; [ClockRowKey.interned] and [ClockRowKey.packed] require [compactTriggers].
  final ClockRowKey rowKey;

  const SpikeSqlOptions({
    this.withoutRowid = true,
    this.partialCauseIndex = true,
    this.compactTriggers = true,
    this.rowKey = ClockRowKey.text,
  });

  /// D1 written literally: rowid table, full cause index, one statement pair per cell.
  static const SpikeSqlOptions literal =
      SpikeSqlOptions(withoutRowid: false, partialCauseIndex: false, compactTriggers: false);

  static const SpikeSqlOptions recommended = SpikeSqlOptions();

  String get label => 'withoutRowid=$withoutRowid partialCauseIndex=$partialCauseIndex compact=$compactTriggers'
      '${rowKey == ClockRowKey.text ? '' : ' rowKey=${rowKey.name}'}';
}

/// `sync_row` (interned shapes), `sync_clock` and its cause index for [options]. The `(origin_id, origin_seq)`
/// cursor index is created by the caller (S5/S3 install).
List<String> clockSchemaStatements([SpikeSqlOptions options = SpikeSqlOptions.recommended]) {
  if (options.rowKey == ClockRowKey.text) {
    return [
      '''
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
)${options.withoutRowid ? ' WITHOUT ROWID' : ''}''',
      'CREATE INDEX IF NOT EXISTS sync_clock_cause_idx ON sync_clock (cause_tbl_id, cause_pk)'
          '${options.partialCauseIndex ? ' WHERE cause_pk IS NOT NULL' : ''}',
    ];
  }
  final packed = options.rowKey == ClockRowKey.packed;
  return [
    '''
CREATE TABLE IF NOT EXISTS sync_row (
  id INTEGER PRIMARY KEY,
  tbl_id INTEGER NOT NULL,
  pk TEXT NOT NULL,
  UNIQUE (tbl_id, pk)
)''',
    '''
CREATE TABLE IF NOT EXISTS sync_clock (
${packed ? '  key INTEGER PRIMARY KEY,' : '  row_id INTEGER NOT NULL,\n  col_id INTEGER NOT NULL,'}
  hlc INTEGER NOT NULL,
  node_id INTEGER NOT NULL,
  origin_id INTEGER NOT NULL,
  origin_seq INTEGER NOT NULL,
  manifest_id INTEGER NULL,
  tomb_value INTEGER NULL,
  cause_row_id INTEGER NULL,
  recorded_at INTEGER NOT NULL${packed ? '' : ',\n  PRIMARY KEY (row_id, col_id)'}
)${!packed && options.withoutRowid ? ' WITHOUT ROWID' : ''}''',
    'CREATE INDEX IF NOT EXISTS sync_clock_cause_idx ON sync_clock (cause_row_id)'
        '${options.partialCauseIndex ? ' WHERE cause_row_id IS NOT NULL' : ''}',
  ];
}

/// D1 tables plus the single-row `sync_state` (D2/D3). Idempotent.
List<String> spikeSchemaStatements([SpikeSqlOptions options = SpikeSqlOptions.recommended]) => [
      '''
CREATE TABLE IF NOT EXISTS sync_intern (
  id INTEGER PRIMARY KEY,
  kind INTEGER NOT NULL,
  value TEXT NOT NULL UNIQUE
)''',
      ...clockSchemaStatements(options),
      '''
CREATE TABLE IF NOT EXISTS sync_state (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  hlc INTEGER NOT NULL DEFAULT 0,
  next_seq INTEGER NOT NULL DEFAULT 1,
  apply_mode INTEGER NOT NULL DEFAULT 0,
  node_id INTEGER NOT NULL,
  origin_id INTEGER NOT NULL,
  cascade_cause_tbl_id INTEGER NULL,
  cascade_cause_pk TEXT NULL,
  test_wall_ms INTEGER NULL
)''',
      "INSERT OR IGNORE INTO sync_intern (kind, value) VALUES ($internKindNode, '$localNodeValue')",
      "INSERT OR IGNORE INTO sync_intern (kind, value) VALUES ($internKindOrigin, '$localOriginValue')",
      '''
INSERT OR IGNORE INTO sync_state (id, node_id, origin_id)
VALUES (1,
  (SELECT id FROM sync_intern WHERE value = '$localNodeValue'),
  (SELECT id FROM sync_intern WHERE value = '$localOriginValue'))''',
    ];

String _q(String column) => '"$column"';

const String _captureEnabled = '(SELECT apply_mode FROM sync_state WHERE id = 1) = 0';

const String _upsertTail = '''
  ON CONFLICT (tbl_id, pk, col_id) DO UPDATE SET
    hlc = excluded.hlc, node_id = excluded.node_id, origin_id = excluded.origin_id,
    origin_seq = excluded.origin_seq, manifest_id = NULL, tomb_value = excluded.tomb_value,
    cause_tbl_id = excluded.cause_tbl_id, cause_pk = excluded.cause_pk, recorded_at = excluded.recorded_at;''';

const String _clockColumns = 'tbl_id, pk, col_id, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value, '
    'cause_tbl_id, cause_pk, recorded_at';

/// One cell to stamp: [condition] decides whether it is written; [tombExpr] is the `~` value (NULL otherwise).
class _CellSpec {
  final int colId;
  final String condition;
  final String tombExpr;
  const _CellSpec(this.colId, this.condition, [this.tombExpr = 'NULL']);
  bool get isTomb => colId == tombstoneColId;
}

/// Cause of a `~` cell: the cascade cause from sync_state, only when the cell is a tombstone.
String _causeExpr(String stateAlias, String column, String tombExpr) =>
    'CASE WHEN $tombExpr IS NOT NULL THEN $stateAlias.$column END';

// --- Per-cell style: a tick UPDATE and an upsert per cell.

String _perCell(int tblId, String pkExpr, _CellSpec cell) {
  final tomb = cell.isTomb ? cell.tombExpr : 'NULL';
  final ctbl = cell.isTomb ? _causeExpr('s', 'cascade_cause_tbl_id', tomb) : 'NULL';
  final cpk = cell.isTomb ? _causeExpr('s', 'cascade_cause_pk', tomb) : 'NULL';
  return '''
  UPDATE sync_state SET hlc = MAX(hlc + 1, ($wallMsSql) << 16), next_seq = next_seq + 1
  WHERE id = 1 AND (${cell.condition});
  INSERT INTO sync_clock ($_clockColumns)
  SELECT $tblId, $pkExpr, ${cell.colId}, s.hlc, s.node_id, s.origin_id, s.next_seq - 1, NULL, $tomb, $ctbl, $cpk,
         $wallMsSql
  FROM sync_state s WHERE s.id = 1 AND (${cell.condition})
$_upsertTail''';
}

// --- Compact style: all cells in one INSERT ... SELECT, then one sync_state UPDATE reserving n ticks and seqs.
//     Cells are numbered 1..n by row_number(); cell k gets hlc = MAX(prev + 1, wall << 16) + k - 1 and
//     seq = next_seq + k - 1, which is exactly n consecutive D2 local ticks.

String _compact(SpikeSqlOptions options, int tblId, String pkExpr, List<_CellSpec> cells) {
  final unconditional = cells.every((c) => c.condition == '1');
  final arms = <String>[];
  for (var i = 0; i < cells.length; i++) {
    final c = cells[i];
    final rn = unconditional ? '${i + 1}' : null;
    final where = c.condition == '1' ? '' : ' WHERE ${c.condition}';
    arms.add('SELECT ${c.colId} AS col_id, ${c.isTomb ? c.tombExpr : 'NULL'} AS tomb'
        '${rn != null ? ', $rn AS rn' : ''}$where');
  }
  final source = unconditional
      ? '(${arms.join(' UNION ALL ')})'
      : '(SELECT col_id, tomb, row_number() OVER (ORDER BY col_id) AS rn FROM (${arms.join(' UNION ALL ')}))';
  final n = unconditional ? '${cells.length}' : '(${cells.map((c) => '(${c.condition})').join(' + ')})';
  final isTomb = 'c.col_id = $tombstoneColId';
  if (options.rowKey != ClockRowKey.text) return _compactInterned(options, tblId, pkExpr, source, n, isTomb);
  return '''
  INSERT INTO sync_clock ($_clockColumns)
  SELECT $tblId, $pkExpr, c.col_id, MAX(s.hlc + 1, ($wallMsSql) << 16) + c.rn - 1, s.node_id, s.origin_id,
         s.next_seq + c.rn - 1, NULL, c.tomb,
         CASE WHEN $isTomb AND c.tomb IS NOT NULL THEN s.cascade_cause_tbl_id END,
         CASE WHEN $isTomb AND c.tomb IS NOT NULL THEN s.cascade_cause_pk END,
         $wallMsSql
  FROM $source AS c, sync_state AS s WHERE s.id = 1
$_upsertTail
  UPDATE sync_state SET hlc = MAX(hlc + 1, ($wallMsSql) << 16) + $n - 1, next_seq = next_seq + $n
  WHERE id = 1 AND $n > 0;''';
}

/// Interned shapes (PA-1): intern `(tbl_id, pk)` in `sync_row` with `ON CONFLICT DO NOTHING` (only when a cell is
/// written), then one `INSERT … SELECT` joined to that `sync_row` row, then the `sync_state` UPDATE. The cascade
/// cause `(cascade_cause_tbl_id, cascade_cause_pk)` is resolved to its `sync_row` id (the cause item is itself a
/// synced row, so it is interned). PA-3: `ON CONFLICT DO NOTHING/DO UPDATE`, never `OR REPLACE/OR IGNORE`.
String _compactInterned(SpikeSqlOptions options, int tblId, String pkExpr, String source, String n, String isTomb) {
  final packed = options.rowKey == ClockRowKey.packed;
  final keyColumns = packed ? 'key' : 'row_id, col_id';
  final keyValues = packed ? 'r.id * $packedKeyFactor + c.col_id' : 'r.id, c.col_id';
  return '''
  INSERT INTO sync_row (tbl_id, pk) SELECT $tblId, $pkExpr WHERE $n > 0
  ON CONFLICT (tbl_id, pk) DO NOTHING;
  INSERT INTO sync_clock ($keyColumns, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value, cause_row_id,
                          recorded_at)
  SELECT $keyValues, MAX(s.hlc + 1, ($wallMsSql) << 16) + c.rn - 1, s.node_id, s.origin_id,
         s.next_seq + c.rn - 1, NULL, c.tomb,
         CASE WHEN $isTomb AND c.tomb IS NOT NULL THEN
           (SELECT cr.id FROM sync_row cr WHERE cr.tbl_id = s.cascade_cause_tbl_id AND cr.pk = s.cascade_cause_pk)
         END,
         $wallMsSql
  FROM $source AS c, sync_state AS s, sync_row AS r WHERE s.id = 1 AND r.tbl_id = $tblId AND r.pk = $pkExpr
  ON CONFLICT ($keyColumns) DO UPDATE SET
    hlc = excluded.hlc, node_id = excluded.node_id, origin_id = excluded.origin_id,
    origin_seq = excluded.origin_seq, manifest_id = NULL, tomb_value = excluded.tomb_value,
    cause_row_id = excluded.cause_row_id, recorded_at = excluded.recorded_at;
  UPDATE sync_state SET hlc = MAX(hlc + 1, ($wallMsSql) << 16) + $n - 1, next_seq = next_seq + $n
  WHERE id = 1 AND $n > 0;''';
}

String _cells(SpikeSqlOptions options, int tblId, String pkExpr, List<_CellSpec> cells) {
  if (!options.compactTriggers && options.rowKey != ClockRowKey.text) {
    throw UnsupportedError('Interned clock shapes are only generated with compactTriggers');
  }
  return options.compactTriggers
      ? _compact(options, tblId, pkExpr, cells)
      : cells.map((c) => _perCell(tblId, pkExpr, c)).join('\n');
}

String triggerName(SpikeTablePolicy policy, String op) => 'sync_spike_${policy.tableName}_$op';

List<String> spikeTriggerStatements(SpikeTablePolicy policy, [SpikeSqlOptions options = SpikeSqlOptions.recommended]) {
  final t = policy.tableName;
  final tbl = policy.tblId;

  // INSERT: every synced column (or `*`) plus `~` = NEW.deleted_date.
  final insertCells = [
    if (policy.rowLevel)
      const _CellSpec(rowLevelColId, '1')
    else
      for (final colId in policy.columns.values) _CellSpec(colId, '1'),
    const _CellSpec(tombstoneColId, '1', 'NEW.deleted_date'),
  ];

  // UPDATE: changed columns only; `deleted_date` only through `~`; `modified_date` never.
  final changed = [for (final c in policy.columns.keys) 'OLD.${_q(c)} IS NOT NEW.${_q(c)}'];
  final updateCells = [
    if (policy.rowLevel)
      _CellSpec(rowLevelColId, changed.join(' OR '))
    else
      for (final e in policy.columns.entries) _CellSpec(e.value, 'OLD.${_q(e.key)} IS NOT NEW.${_q(e.key)}'),
    const _CellSpec(tombstoneColId, 'OLD.deleted_date IS NOT NEW.deleted_date', 'NEW.deleted_date'),
  ];

  // DELETE (hard): `~` = now (seconds, like drift DateTime columns) only if the row was live and no row with the
  // same id remains (duplicate-rowid cleanup).
  // The value is a scalar subquery so it resolves in both styles (compact cells are built in a FROM subquery).
  final deleteCells = [
    const _CellSpec(tombstoneColId, '1', '(SELECT ($wallMsSql) / 1000 FROM sync_state WHERE id = 1)'),
  ];

  return [
    'CREATE TRIGGER IF NOT EXISTS ${triggerName(policy, 'ai')} AFTER INSERT ON $t\n'
        'WHEN $_captureEnabled BEGIN\n${_cells(options, tbl, 'NEW.id', insertCells)}\nEND',
    'CREATE TRIGGER IF NOT EXISTS ${triggerName(policy, 'au')} AFTER UPDATE ON $t\n'
        'WHEN $_captureEnabled BEGIN\n${_cells(options, tbl, 'NEW.id', updateCells)}\nEND',
    'CREATE TRIGGER IF NOT EXISTS ${triggerName(policy, 'ad')} AFTER DELETE ON $t\n'
        'WHEN $_captureEnabled AND OLD.deleted_date IS NULL AND NOT EXISTS (SELECT 1 FROM $t WHERE id = OLD.id)\n'
        'BEGIN\n${_cells(options, tbl, 'OLD.id', deleteCells)}\nEND',
  ];
}

/// Schema plus triggers for both spike tables, in execution order.
List<String> spikeInstallStatements([SpikeSqlOptions options = SpikeSqlOptions.recommended]) => [
      ...spikeSchemaStatements(options),
      for (final policy in spikePolicies) ...spikeTriggerStatements(policy, options),
    ];

int hlcWall(int hlc) => hlc >> 16;
int hlcCounter(int hlc) => hlc & 0xFFFF;
