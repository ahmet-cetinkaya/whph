/// D3 change capture, generated from [SyncTablePolicy]. The SQL shape is the
/// spike-validated PA-3/PA-1 recommendation (S2/S3): one INSERT ... SELECT per
/// statement with row_number() ticks plus one sync_state UPDATE, ON CONFLICT
/// DO UPDATE (never OR REPLACE/OR IGNORE), writing the PA-1 V2 packed clock
/// key (row_id * 256 + col_id).
library;

import 'sync_table_policy.dart';

const int _internKindNode = 1;
const int _internKindOrigin = 2;

/// D3 wall clock in ms, derived inside SQLite so triggers work on every
/// connection and isolate.
const String _wallMs =
    "CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)";

const String _captureEnabled =
    "(SELECT apply_mode FROM sync_state WHERE id = 'singleton') = 0";

String _q(String column) => '"$column"';

class _CellSpec {
  final int colId;
  final String condition;
  final String tombExpr;
  const _CellSpec(this.colId, this.condition, [this.tombExpr = 'NULL']);
  bool get isTomb => colId == tombstoneColId;
}

String _cells(int tblId, String pkExpr, List<_CellSpec> cells) {
  final unconditional = cells.every((c) => c.condition == '1');
  final arms = <String>[];
  for (var i = 0; i < cells.length; i++) {
    final c = cells[i];
    final rn = unconditional ? '${i + 1}' : null;
    final where = c.condition == '1' ? '' : ' WHERE ${c.condition}';
    arms.add(
        'SELECT ${c.colId} AS col_id, ${c.isTomb ? c.tombExpr : 'NULL'} AS tomb'
        '${rn != null ? ', $rn AS rn' : ''}$where');
  }
  final source = unconditional
      ? '(${arms.join(' UNION ALL ')})'
      : '(SELECT col_id, tomb, row_number() OVER (ORDER BY col_id) AS rn FROM (${arms.join(' UNION ALL ')}))';
  final n = unconditional
      ? '${cells.length}'
      : '(${cells.map((c) => '(${c.condition})').join(' + ')})';
  final isTomb = 'c.col_id = $tombstoneColId';
  return '''
  INSERT INTO sync_row (tbl_id, pk) SELECT $tblId, $pkExpr WHERE $n > 0
  ON CONFLICT (tbl_id, pk) DO NOTHING;
  INSERT INTO sync_clock (key, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value, cause_row_id,
                          recorded_at)
  SELECT r.id * $packedKeyFactor + c.col_id, MAX(s.hlc + 1, ($_wallMs) << 16) + c.rn - 1, s.node_id, s.origin_id,
         s.next_seq + c.rn - 1, NULL, c.tomb,
         CASE WHEN $isTomb AND c.tomb IS NOT NULL THEN
           (SELECT cr.id FROM sync_row cr WHERE cr.tbl_id = s.cascade_cause_tbl_id AND cr.pk = s.cascade_cause_pk)
         END,
         $_wallMs
  FROM $source AS c, sync_state AS s, sync_row AS r WHERE s.id = 'singleton' AND r.tbl_id = $tblId AND r.pk = $pkExpr
  ON CONFLICT (key) DO UPDATE SET
    hlc = excluded.hlc, node_id = excluded.node_id, origin_id = excluded.origin_id,
    origin_seq = excluded.origin_seq, manifest_id = NULL, tomb_value = excluded.tomb_value,
    cause_row_id = excluded.cause_row_id, recorded_at = excluded.recorded_at;
  UPDATE sync_state SET hlc = MAX(hlc + 1, ($_wallMs) << 16) + $n - 1, next_seq = next_seq + $n
  WHERE id = 'singleton' AND $n > 0;''';
}

/// The node/origin intern rows for the local identity, seeded by the
/// installer when the sync_state singleton is created (T17/T18 own the real
/// identity; until then a stable local placeholder keeps triggers functional
/// for capture-coverage testing).
List<String> syncInternSeedStatements(
        {required String nodeValue, required String originValue}) =>
    [
      "INSERT OR IGNORE INTO sync_intern (kind, value) VALUES ($_internKindNode, '$nodeValue')",
      "INSERT OR IGNORE INTO sync_intern (kind, value) VALUES ($_internKindOrigin, '$originValue')",
      '''
INSERT INTO sync_state (id, node_id, origin_id, apply_mode, next_seq, hlc, upgrade_cursor)
VALUES ('singleton',
  (SELECT id FROM sync_intern WHERE value = '$nodeValue'),
  (SELECT id FROM sync_intern WHERE value = '$originValue'), 0, 1, 0, 0)
ON CONFLICT (id) DO UPDATE SET node_id = excluded.node_id, origin_id = excluded.origin_id''',
    ];

String triggerName(SyncTablePolicy policy, String op) =>
    'sync_cap_${policy.tableName}_$op';

/// The three D3 triggers (AFTER INSERT/UPDATE/DELETE) for one table.
List<String> syncTriggerStatements(SyncTablePolicy policy) {
  final t = policy.tableName;
  final tbl = policy.tblId;

  final insertCells = [
    if (policy.rowLevel)
      const _CellSpec(rowLevelColId, '1')
    else
      for (final colId in policy.columns.values) _CellSpec(colId, '1'),
    const _CellSpec(tombstoneColId, '1', 'NEW.deleted_date'),
  ];

  final changed = [
    for (final c in policy.columns.keys) 'OLD.${_q(c)} IS NOT NEW.${_q(c)}'
  ];
  final rowChanged = changed.isEmpty ? '1' : changed.join(' OR ');
  final updateCells = [
    if (policy.rowLevel)
      _CellSpec(rowLevelColId, rowChanged)
    else
      for (final e in policy.columns.entries)
        _CellSpec(e.value, 'OLD.${_q(e.key)} IS NOT NEW.${_q(e.key)}'),
    const _CellSpec(tombstoneColId, 'OLD.deleted_date IS NOT NEW.deleted_date',
        'NEW.deleted_date'),
  ];

  final deleteCells = [
    _CellSpec(tombstoneColId, '1',
        "(SELECT ($_wallMs / 1000) FROM sync_state WHERE id = 'singleton')"),
  ];

  return [
    'CREATE TRIGGER IF NOT EXISTS ${triggerName(policy, 'ai')} AFTER INSERT ON $t\n'
        'WHEN $_captureEnabled BEGIN\n${_cells(tbl, 'NEW.id', insertCells)}\nEND',
    'CREATE TRIGGER IF NOT EXISTS ${triggerName(policy, 'au')} AFTER UPDATE ON $t\n'
        'WHEN $_captureEnabled BEGIN\n${_cells(tbl, 'NEW.id', updateCells)}\nEND',
    'CREATE TRIGGER IF NOT EXISTS ${triggerName(policy, 'ad')} AFTER DELETE ON $t\n'
        'WHEN $_captureEnabled AND OLD.deleted_date IS NULL AND NOT EXISTS (SELECT 1 FROM $t WHERE id = OLD.id)\n'
        'BEGIN\n${_cells(tbl, 'OLD.id', deleteCells)}\nEND',
  ];
}

/// Triggers for every synced table, in registry order.
List<String> allSyncTriggerStatements() => [
      for (final policy in syncTablePolicies) ...syncTriggerStatements(policy),
    ];

/// D5b parent-side cascade materialization: when a parent task's
/// `deleted_date` flips, children tombstoned *by that parent* (their winning
/// `~` cell's `cause_row_id` points at the parent's `sync_row`) are
/// materialized to the effective state: revived children get
/// `deleted_date = NULL`, re-deleted children go back to their `tomb_value`.
/// `modified_date` = MAX(old + 1, now in whole seconds). The child UPDATE
/// runs with `apply_mode = 1` so it writes 0 clock rows, and restores 0.
const String _d5bCauseCheck = '''
      EXISTS (
        SELECT 1 FROM sync_row cr, sync_clock cc
        WHERE cr.tbl_id = 1 AND cr.pk = task_table.id
          AND cc.key = cr.id * 256 AND cc.cause_row_id IS NOT NULL
          AND cc.cause_row_id = (SELECT pr.id FROM sync_row pr
                                 WHERE pr.tbl_id = 1 AND pr.pk = NEW.id)
      )''';

/// The D5b trigger, one per parent table (v38: task_table only).
List<String> syncCascadeStatements() => [
      '''
CREATE TRIGGER IF NOT EXISTS sync_d5b_task_parent_date
AFTER UPDATE OF deleted_date ON task_table
WHEN (SELECT apply_mode FROM sync_state WHERE id = 'singleton') = 0
BEGIN
  UPDATE sync_state SET apply_mode = 1 WHERE id = 'singleton';
  UPDATE task_table SET
    deleted_date = NULL,
    modified_date = MAX(COALESCE(modified_date, 0) + 1, CAST(strftime('%s','now') AS INTEGER))
  WHERE parent_task_id = NEW.id AND deleted_date IS NOT NULL AND NEW.deleted_date IS NULL
    AND $_d5bCauseCheck;
  UPDATE task_table SET
    deleted_date = (SELECT cc.tomb_value FROM sync_row cr, sync_clock cc
                    WHERE cr.tbl_id = 1 AND cr.pk = task_table.id AND cc.key = cr.id * 256),
    modified_date = MAX(COALESCE(modified_date, 0) + 1, CAST(strftime('%s','now') AS INTEGER))
  WHERE parent_task_id = NEW.id AND deleted_date IS NULL AND NEW.deleted_date IS NOT NULL
    AND $_d5bCauseCheck;
  UPDATE sync_state SET apply_mode = 0 WHERE id = 'singleton';
END''',
    ];
