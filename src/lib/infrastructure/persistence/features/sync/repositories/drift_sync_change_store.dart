import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:acore/acore.dart';
import 'package:drift/drift.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_change_store.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/sync_security_cells.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_reauthor_spec.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_generator.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// Wires the Drift change store (T23 calls this from the app bootstrap).
void registerSyncPersistence(IContainer container) {
  final database = AppDatabase.instance(container);
  container.registerSingleton<ISyncChangeStore>(
      (_) => DriftSyncChangeStore(database));
}

const int _applyModeCapture = 0;
const int _applyModeRemote = 1;
const int _applyModeOriginSwitch = 3;
const String _stateId = 'singleton';

const String _heldKindUnknown = 'unknown';
const String _heldKindStaged = 'staged';
const String _heldReasonApplyFailed = 'apply_failed';
const String _savepoint = 'sync_item';
const String _peerResultDuplicateIdentity = 'duplicated_identity';
const int _hashLength = 32;

/// Wall part of a packed HLC (D2): a wall at or above 2^46 ms is malformed.
const int _hlcCounterBits = 16;
const int _hlcWallLimit = 1 << 46;
const int _msPerSecond = 1000;

/// Columns that are not synced cells (D1, D4).
const Set<String> _bookkeepingColumns = {
  'id',
  'created_date',
  'modified_date',
  'deleted_date'
};

/// Tables that hold the replicated security state (D7, D13). `local_reset`
/// keeps them; `group_switch` clears them.
const List<String> _securityTables = [
  'sync_member_table',
  'sync_origin',
  'sync_revocation',
  'sync_epoch_grant',
  'sync_origin_batch',
];

/// An item failed on a malformed or unusable remote cell (FR-015).
class SyncItemRejected implements Exception {
  final String category;
  const SyncItemRejected(this.category);

  @override
  String toString() => 'SyncItemRejected($category)';
}

/// State shared by the items of one batch.
class _ApplyContext {
  /// Rows whose `modified_date` was already bumped in this batch.
  final Set<String> bumped = {};

  /// Origins with a conflicting canonical change under one `(origin, seq)`.
  final Set<String> duplicateOrigins = {};
}

class _TableShape {
  final Set<String> columns;
  final List<String> requiredColumns;
  const _TableShape(this.columns, this.requiredColumns);
}

class _ClockRow {
  final int rowId;
  final int colId;
  final int hlc;
  final String node;
  final String origin;
  final int originSeq;
  final int? tombValue;
  final int? causeRowId;
  final int? manifestId;

  const _ClockRow(this.rowId, this.colId, this.hlc, this.node, this.origin,
      this.originSeq, this.tombValue, this.causeRowId, this.manifestId);

  bool isVersionOf(CellRecord cell) =>
      hlc == cell.clock &&
      node == cell.node &&
      origin == cell.origin &&
      originSeq == cell.originSeq;
}

/// Drift implementation of [ISyncChangeStore] over the PA-1 physical clock
/// shape (`sync_row` + `sync_clock`, key = row_id * 256 + col_id).
///
/// The package `ReplicaStore` port is synchronous and cannot be implemented
/// over Drift's asynchronous connection (a background isolate in production),
/// so this store exposes the same operations as futures.
class DriftSyncChangeStore implements ISyncChangeStore {
  final GeneratedDatabase _db;
  final int Function() _nowMs;

  final Map<String, _TableShape> _shapes = {};
  final Map<String, SyncTablePolicy> _policyByName = {
    for (final policy in syncTablePolicies) policy.tableName: policy,
  };
  final Map<int, SyncTablePolicy> _policyById = {
    for (final policy in syncTablePolicies) policy.tblId: policy,
  };
  final Map<String, SecurityCellSpec> _securityByWire = {
    for (final spec in securityCellSpecs) spec.wireName: spec,
  };
  final Map<int, SecurityCellSpec> _securityById = {
    for (final spec in securityCellSpecs) spec.tblId: spec,
  };

  DriftSyncChangeStore(this._db, {int Function()? nowMs})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  // -- SQL helpers ----------------------------------------------------------

  Future<List<Map<String, Object?>>> _select(String sql,
          [List<Object?> args = const []]) async =>
      (await _db.customSelect(sql,
              variables: [for (final arg in args) _variable(arg)]).get())
          .map((row) => row.data)
          .toList();

  Future<Map<String, Object?>?> _selectOne(String sql,
      [List<Object?> args = const []]) async {
    final rows = await _select(sql, args);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _exec(String sql, [List<Object?> args = const []]) =>
      _db.customStatement(sql, args);

  static Variable<Object> _variable(Object? value) => switch (value) {
        null => const Variable<Object>(null),
        final int v => Variable<int>(v),
        final String v => Variable<String>(v),
        final Uint8List v => Variable<Uint8List>(v),
        _ => throw ArgumentError.value(value, 'value'),
      };

  int get _nowSeconds => _nowMs() ~/ _msPerSecond;

  Future<Map<String, Object?>> _state() async =>
      (await _selectOne('SELECT * FROM sync_state WHERE id = ?', [_stateId]))!;

  Future<void> _setApplyMode(int mode) => _exec(
      'UPDATE sync_state SET apply_mode = ? WHERE id = ?', [mode, _stateId]);

  Future<int> _intern(int kind, String value) async {
    await _exec('INSERT OR IGNORE INTO sync_intern (kind, value) VALUES (?, ?)',
        [kind, value]);
    final row = await _selectOne(
        'SELECT id FROM sync_intern WHERE kind = ? AND value = ?',
        [kind, value]);
    return row!['id'] as int;
  }

  Future<int> _ensureRow(int tblId, String pk) async {
    await _exec('INSERT OR IGNORE INTO sync_row (tbl_id, pk) VALUES (?, ?)',
        [tblId, pk]);
    final row = await _selectOne(
        'SELECT id FROM sync_row WHERE tbl_id = ? AND pk = ?', [tblId, pk]);
    return row!['id'] as int;
  }

  Future<_TableShape> _shapeOf(String table) async {
    final cached = _shapes[table];
    if (cached != null) return cached;
    final info = await _select('PRAGMA table_info("$table")');
    final columns = {for (final column in info) column['name'] as String};
    final required = [
      for (final column in info)
        if (column['notnull'] == 1 &&
            column['dflt_value'] == null &&
            !_bookkeepingColumns.contains(column['name']))
          column['name'] as String,
    ];
    return _shapes[table] = _TableShape(columns, required);
  }

  // -- vector and reads -----------------------------------------------------

  @override
  Future<Map<String, int>> readVector() async {
    final vector = <String, int>{
      for (final row
          in await _select('SELECT origin_id, cursor FROM sync_vector'))
        row['origin_id'] as String: row['cursor'] as int,
    };
    final own = await _ownOrigin();
    final nextSeq = (await _state())['next_seq'] as int;
    if (nextSeq > 1) vector[own] = nextSeq - 1;
    return vector;
  }

  Future<String> _ownOrigin() async {
    final row = await _selectOne(
        "SELECT i.value AS value FROM sync_state s JOIN sync_intern i ON i.id = s.origin_id WHERE s.id = ?",
        [_stateId]);
    return row!['value'] as String;
  }

  @override
  Future<ChangeBatch> readChanges(String origin,
          {required int afterSeq, int? upToSeq, int limit = 256}) =>
      // One transaction, so a read issued while an apply is in flight (T12
      // pipelining) sees the state before or after the whole batch.
      _db.transaction(() async {
        final bound = upToSeq ?? (await readVector())[origin] ?? afterSeq;
        final clockCells =
            await _readClockCells(origin, afterSeq, bound, limit);
        final heldCells = await _readUnknownCells(origin, afterSeq, bound);
        final cells = [...clockCells, ...heldCells]
          ..sort((a, b) => a.originSeq.compareTo(b.originSeq));
        final truncated = cells.length > limit;
        final page = truncated ? cells.sublist(0, limit) : cells;
        final toSeq = truncated ? page.last.originSeq : bound;
        return ChangeBatch(
            origin: origin,
            fromSeq: afterSeq,
            toSeq: toSeq < afterSeq ? afterSeq : toSeq,
            cells: page);
      });

  // -- AsyncReplicaStore ------------------------------------------------------

  @override
  Future<String> nodeId() async {
    final row = await _selectOne(
        'SELECT i.value AS value FROM sync_state s JOIN sync_intern i ON i.id = s.node_id WHERE s.id = ?',
        [_stateId]);
    return row!['value'] as String;
  }

  @override
  Future<Map<String, int>> vector() => readVector();

  @override
  Future<List<ChangeBatch>> changesSince(Map<String, int> peerVector,
      {int maxCellsPerBatch = 256}) async {
    final batches = <ChangeBatch>[];
    final ours = await readVector();
    for (final origin in ours.keys.toList()..sort()) {
      var peerCursor = peerVector[origin] ?? 0;
      final bound = ours[origin]!;
      while (peerCursor < bound) {
        final batch = await readChanges(origin,
            afterSeq: peerCursor, upToSeq: bound, limit: maxCellsPerBatch);
        if (batch.toSeq <= peerCursor) break;
        batches.add(batch);
        peerCursor = batch.toSeq;
      }
    }
    return batches;
  }

  @override
  Future<bool> mergeBatch(ChangeBatch batch) async {
    final report = await applyBatch(batch);
    return report.applied > 0 || report.cursorAdvanced;
  }

  Future<List<CellRecord>> _readClockCells(
      String origin, int afterSeq, int bound, int limit) async {
    final rows = await _select('''
SELECT c.key AS key, c.hlc AS hlc, n.value AS node, c.origin_seq AS seq, c.tomb_value AS tomb_value,
       r.tbl_id AS tbl_id, r.pk AS pk, cr.tbl_id AS cause_tbl_id, cr.pk AS cause_pk
FROM sync_clock c
JOIN sync_intern o ON o.id = c.origin_id AND o.value = ?
JOIN sync_intern n ON n.id = c.node_id
JOIN sync_row r ON r.id = c.key / $packedKeyFactor
LEFT JOIN sync_row cr ON cr.id = c.cause_row_id
WHERE c.origin_seq > ? AND c.origin_seq <= ?
ORDER BY c.origin_seq, c.key
LIMIT ?''', [origin, afterSeq, bound, limit + 1]);
    final baseRows = <String, Map<String, Object?>?>{};
    final cells = <CellRecord>[];
    for (final row in rows) {
      final security = _securityById[row['tbl_id'] as int];
      if (security != null) {
        final cell = await _readSecurityCell(security, row, origin);
        if (cell != null) cells.add(cell);
        continue;
      }
      final policy = _policyById[row['tbl_id'] as int]!;
      final pk = row['pk'] as String;
      final colId = (row['key'] as int) % packedKeyFactor;
      final value = await _cellValue(
          policy, pk, colId, row['tomb_value'] as int?, baseRows);
      final causeTbl = row['cause_tbl_id'] as int?;
      cells.add(CellRecord(
        key: CellKey(policy.tableName, pk, _wireColumn(policy, colId)),
        value: value,
        clock: row['hlc'] as int,
        node: row['node'] as String,
        origin: origin,
        originSeq: row['seq'] as int,
        cause: causeTbl == null
            ? null
            : RowRef(
                _policyById[causeTbl]!.tableName, row['cause_pk'] as String),
      ));
    }
    return cells;
  }

  Future<CellRecord?> _readSecurityCell(SecurityCellSpec spec,
      Map<String, Object?> clockRow, String origin) async {
    final pk = clockRow['pk'] as String;
    final stored = await _selectOne(
        'SELECT * FROM "${spec.tableName}" WHERE ${spec.pkColumn} = ?', [pk]);
    if (stored == null) return null;
    return CellRecord(
      key: CellKey(spec.wireName, pk, CellKey.rowCol),
      value: spec.fromRow(stored),
      clock: clockRow['hlc'] as int,
      node: clockRow['node'] as String,
      origin: origin,
      originSeq: clockRow['seq'] as int,
    );
  }

  Future<List<CellRecord>> _readUnknownCells(
      String origin, int afterSeq, int bound) async {
    final rows = await _select(
        "SELECT * FROM sync_held_cell WHERE kind = '$_heldKindUnknown' AND origin_id = ? AND origin_seq > ? AND origin_seq <= ?",
        [origin, afterSeq, bound]);
    return [
      for (final row in rows)
        CellRecord(
          key: CellKey(
              row['tbl'] as String, row['pk'] as String, row['col'] as String),
          value: _decodeHeldValue(row['value']),
          clock: row['hlc'] as int,
          node: row['node'] as String,
          origin: origin,
          originSeq: row['origin_seq'] as int,
        ),
    ];
  }

  String _wireColumn(SyncTablePolicy policy, int colId) {
    if (colId == tombstoneColId) return CellKey.existenceCol;
    if (colId == rowLevelColId && policy.rowLevel) return CellKey.rowCol;
    return policy.columns.entries
        .firstWhere((entry) => entry.value == colId)
        .key;
  }

  /// The cell's value: `deleted_date` from the clock row for `~`, otherwise
  /// the base row's column (or the staged value while the row is incomplete).
  Future<Object?> _cellValue(SyncTablePolicy policy, String pk, int colId,
      int? tombValue, Map<String, Map<String, Object?>?> baseRows) async {
    if (colId == tombstoneColId) return tombValue;
    final base = baseRows[policy.tableName + pk] ??= await _selectOne(
        'SELECT * FROM "${policy.tableName}" WHERE id = ?', [pk]);
    if (policy.rowLevel) return base == null ? null : _encodeRowLevel(base);
    final column = _wireColumn(policy, colId);
    if (base != null) return base[column];
    final staged = await _selectOne(
        "SELECT value FROM sync_held_cell WHERE tbl = ? AND pk = ? AND col = ? AND kind = '$_heldKindStaged'",
        [policy.tableName, pk, column]);
    return staged == null ? null : _decodeHeldValue(staged['value']);
  }

  String _encodeRowLevel(Map<String, Object?> base) {
    final content = SplayTreeMap<String, Object?>();
    for (final entry in base.entries) {
      if (!_bookkeepingColumns.contains(entry.key))
        content[entry.key] = entry.value;
    }
    return jsonEncode(content);
  }

  Object? _decodeHeldValue(Object? blob) =>
      blob == null ? null : ChangeValue.decode(blob as Uint8List).toDart();

  Uint8List _encodeHeldValue(Object? value) => ChangeValue.of(value).encode();

  // -- apply ----------------------------------------------------------------

  @override
  Future<SyncApplyReport> applyBatch(ChangeBatch batch,
          {OriginManifest? manifest, String? peerMemberId}) =>
      _db.transaction(() async {
        await _requireIdleCaptureMode();
        await _setApplyMode(_applyModeRemote);
        final context = _ApplyContext();
        var applied = 0, unchanged = 0, held = 0, failed = 0;
        for (final cell in batch.cells) {
          switch (await _applyInSavepoint(cell, context)) {
            case _ItemOutcome.applied:
              applied++;
            case _ItemOutcome.unchanged:
              unchanged++;
            case _ItemOutcome.held:
              held++;
            case _ItemOutcome.failed:
              failed++;
          }
        }
        if (manifest != null) await _attachReceivedManifest(batch, manifest);
        if (context.duplicateOrigins.isNotEmpty && peerMemberId != null)
          await _flagDuplicateIdentity(peerMemberId);
        final advanced = await _advanceCursor(batch);
        await _setApplyMode(_applyModeCapture);
        return SyncApplyReport(
            applied: applied,
            unchanged: unchanged,
            held: held,
            failed: failed,
            cursorAdvanced: advanced,
            duplicateIdentityOrigins: context.duplicateOrigins);
      });

  Future<void> _requireIdleCaptureMode() async {
    final state = await _state();
    if (state['apply_mode'] != _applyModeCapture) {
      throw StateError(
          'apply_mode is ${state['apply_mode']}; a remote apply needs capture mode');
    }
    final phase = state['upgrade_phase'];
    if (phase != null && phase != 'done')
      throw StateError('preparing: upgrade phase $phase is running');
  }

  Future<_ItemOutcome> _applyInSavepoint(
      CellRecord cell, _ApplyContext context) async {
    await _exec('SAVEPOINT $_savepoint');
    try {
      final outcome = await _applyCell(cell, context);
      await _clearHeldEnvelope(cell.key);
      await _exec('RELEASE $_savepoint');
      return outcome;
    } catch (error) {
      await _exec('ROLLBACK TO $_savepoint');
      await _exec('RELEASE $_savepoint');
      await _recordFailure(cell, error);
      return _ItemOutcome.failed;
    }
  }

  /// Keeps the item reachable for refetch and retry (D15). The session layer
  /// owns the sealed envelope bytes; the store keeps the plain value.
  Future<void> _recordFailure(CellRecord cell, Object error) async {
    final category = error is SyncItemRejected
        ? error.category
        : error.runtimeType.toString();
    final key = cell.key;
    final existing = await _selectOne(
        'SELECT id FROM sync_held_envelope WHERE tbl = ? AND pk = ? AND col = ?',
        [key.table, key.pk, key.col]);
    if (existing != null) {
      await _exec(
          'UPDATE sync_held_envelope SET fail_count = fail_count + 1, category = ? WHERE id = ?',
          [category, existing['id']]);
      return;
    }
    await _exec(
        'INSERT INTO sync_held_envelope (tbl, pk, col, peer, reason, fail_count, category, envelope) '
        "VALUES (?, ?, ?, '', ?, 1, ?, ?)",
        [
          key.table,
          key.pk,
          key.col,
          _heldReasonApplyFailed,
          category,
          _encodeHeldValue(cell.value)
        ]);
  }

  Future<bool> _advanceCursor(ChangeBatch batch) async {
    final row = await _selectOne(
        'SELECT cursor FROM sync_vector WHERE origin_id = ?', [batch.origin]);
    final current = row == null ? 0 : row['cursor'] as int;
    if (batch.fromSeq > current || batch.toSeq <= current) return false;
    await _exec(
        'INSERT INTO sync_vector (origin_id, cursor) VALUES (?, ?) ON CONFLICT (origin_id) DO UPDATE SET cursor = excluded.cursor',
        [batch.origin, batch.toSeq]);
    return true;
  }

  Future<_ItemOutcome> _applyCell(
      CellRecord cell, _ApplyContext context) async {
    _validateRepresentable(cell);
    final security = _securityByWire[cell.key.table];
    if (security != null) return _applySecurityCell(security, cell, context);
    final policy = _policyByName[cell.key.table];
    final colId = policy == null ? null : _colIdOf(policy, cell.key.col);
    if (policy == null || colId == null) return _holdUnknown(cell);

    final rowId = await _ensureRow(policy.tblId, cell.key.pk);
    final clockKey = rowId * packedKeyFactor + colId;
    final current = await _clockRow(clockKey);
    await _noteDuplicateIdentity(cell, clockKey, context);
    if (current != null && !_incomingWins(current, cell))
      return _ItemOutcome.unchanged;

    final causeRowId = await _causeRowId(cell);
    final tombValue = colId == tombstoneColId ? _asTombValue(cell.value) : null;
    await _writeClock(clockKey, cell, tombValue, causeRowId);

    final visible = await _writeValue(policy, cell, colId, rowId);
    await _settleRow(policy, cell.key.pk, rowId, <int>{});
    if (visible) await _bumpRevision(policy, cell.key.pk, context.bumped);
    return visible || colId == tombstoneColId
        ? _ItemOutcome.applied
        : _ItemOutcome.held;
  }

  Future<void> _writeClock(
      int clockKey, CellRecord cell, int? tombValue, int? causeRowId) async {
    final nodeId = await _intern(internKindNode, cell.node);
    final originId = await _intern(internKindOrigin, cell.origin);
    await _exec('''
INSERT INTO sync_clock (key, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value, cause_row_id, recorded_at)
VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?)
ON CONFLICT (key) DO UPDATE SET hlc = excluded.hlc, node_id = excluded.node_id, origin_id = excluded.origin_id,
  origin_seq = excluded.origin_seq, manifest_id = NULL, tomb_value = excluded.tomb_value,
  cause_row_id = excluded.cause_row_id, recorded_at = excluded.recorded_at''', [
      clockKey,
      cell.clock,
      nodeId,
      originId,
      cell.originSeq,
      tombValue,
      causeRowId,
      _nowMs()
    ]);
    await _exec('UPDATE sync_state SET hlc = MAX(hlc, ?) WHERE id = ?',
        [cell.clock, _stateId]);
  }

  // -- security rows (D7, D13) ------------------------------------------------

  Future<_ItemOutcome> _applySecurityCell(
      SecurityCellSpec spec, CellRecord cell, _ApplyContext context) async {
    final row = _securityRow(spec, cell);
    final rowId = await _ensureRow(spec.tblId, cell.key.pk);
    final clockKey = rowId * packedKeyFactor + rowLevelColId;
    final current = await _clockRow(clockKey);
    await _noteDuplicateIdentity(cell, clockKey, context);
    if (current != null && !_incomingWins(current, cell))
      return _ItemOutcome.unchanged;

    await _writeClock(clockKey, cell, null, null);
    final columns = row.keys.toList();
    await _exec(
        'INSERT OR REPLACE INTO "${spec.tableName}" (${columns.map((c) => '"$c"').join(', ')}) '
        'VALUES (${List.filled(columns.length, '?').join(', ')})',
        [for (final column in columns) row[column]]);
    return _ItemOutcome.applied;
  }

  @override
  Future<CellRecord> writeSecurityCell(CellKey key, Uint8List record) =>
      _db.transaction(() async {
        final spec = _securityByWire[key.table];
        if (spec == null)
          throw ArgumentError.value(key, 'key', 'not a security table');
        final state = await _state();
        final cell = CellRecord(
          key: CellKey(key.table, key.pk, CellKey.rowCol),
          value: record,
          clock:
              math.max((state['hlc'] as int) + 1, _nowMs() << _hlcCounterBits),
          node: await nodeId(),
          origin: await _ownOrigin(),
          originSeq: state['next_seq'] as int,
        );
        await _applySecurityCell(spec, cell, _ApplyContext());
        await _exec(
            'UPDATE sync_state SET next_seq = next_seq + 1 WHERE id = ?',
            [_stateId]);
        return cell;
      });

  Map<String, Object?> _securityRow(SecurityCellSpec spec, CellRecord cell) {
    if (cell.key.col != CellKey.rowCol)
      throw const SyncItemRejected('unknown_security_column');
    final value = cell.value;
    if (value is! Uint8List)
      throw const SyncItemRejected('malformed_security_cell');
    try {
      return spec.toRow(cell.key.pk, value, cell.clock);
    } on SecurityCellRejected catch (rejected) {
      throw SyncItemRejected(rejected.category);
    } catch (_) {
      throw const SyncItemRejected('malformed_security_cell');
    }
  }

  // -- duplicate identity (D14) -----------------------------------------------

  /// Two different canonical changes under one `(origin, seq)` mean two
  /// devices write that origin (a copied data directory). Only noted; the
  /// merge continues by the usual rules.
  Future<void> _noteDuplicateIdentity(
      CellRecord cell, int clockKey, _ApplyContext context) async {
    final clash = await _selectOne('''
SELECT c.key AS key, c.hlc AS hlc, n.value AS node
FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id JOIN sync_intern n ON n.id = c.node_id
WHERE o.value = ? AND c.origin_seq = ?''', [cell.origin, cell.originSeq]);
    if (clash == null) return;
    final sameVersion = clash['key'] == clockKey &&
        clash['hlc'] == cell.clock &&
        clash['node'] == cell.node;
    if (!sameVersion) context.duplicateOrigins.add(cell.origin);
  }

  Future<void> _flagDuplicateIdentity(String peerMemberId) => _exec(
      "INSERT INTO sync_peer_state_table (member_id, addresses, last_result_category) VALUES (?, '', ?) "
      'ON CONFLICT (member_id) DO UPDATE SET last_result_category = excluded.last_result_category',
      [peerMemberId, _peerResultDuplicateIdentity]);

  // -- held envelopes (FR-010, FR-011) ------------------------------------------

  Future<void> _clearHeldEnvelope(CellKey key) => _exec(
      'DELETE FROM sync_held_envelope WHERE tbl = ? AND pk = ? AND col = ?',
      [key.table, key.pk, key.col]);

  @override
  Future<List<CellKey>> refetchKeys() async => [
        for (final row in await _select(
            "SELECT tbl, pk, col FROM sync_held_envelope WHERE reason = '$_heldReasonApplyFailed' ORDER BY id"))
          CellKey(
              row['tbl'] as String, row['pk'] as String, row['col'] as String),
      ];

  // -- manifests and registrations (D7) -----------------------------------------

  @override
  Future<List<OriginManifest>> signOwnManifests(ManifestSigner signer) async {
    final state = await _state();
    final groupHex = state['group_id'] as String?;
    if (groupHex == null) throw StateError('no group: manifests need group_id');
    final own = await _ownOrigin();
    final signedTo = await _highestSignedSeq(own);
    final top = (state['next_seq'] as int) - 1;
    if (top <= signedTo) return const [];

    final unsigned = await readChanges(own,
        afterSeq: signedTo, upToSeq: top, limit: top - signedTo);
    final groupId = GroupId.fromHex(groupHex);
    final manifests =
        await signer.sign(fromSeq: signedTo, toSeq: top, changes: [
      for (final cell in unsigned.cells)
        Change.fromCellRecord(cell, groupId: groupId),
    ]);
    await _db.transaction(() async {
      for (final manifest in manifests) {
        await _storeManifest(manifest);
      }
    });
    return manifests;
  }

  Future<int> _highestSignedSeq(String origin) async {
    final row = await _selectOne(
        'SELECT MAX(to_seq) AS top FROM sync_origin_batch WHERE origin_id = ?',
        [origin]);
    return (row?['top'] as int?) ?? 0;
  }

  /// Persists [manifest] (once per `(origin, range)`) and links the clock rows
  /// of its origin inside the range.
  Future<int> _storeManifest(OriginManifest manifest) async {
    final origin = manifest.origin.hex;
    final existing = await _selectOne(
        'SELECT manifest_id FROM sync_origin_batch WHERE origin_id = ? AND from_seq = ? AND to_seq = ?',
        [origin, manifest.fromSeq, manifest.toSeq]);
    final manifestId = existing != null
        ? existing['manifest_id'] as int
        : await _insertManifest(manifest);
    final originId = await _intern(internKindOrigin, origin);
    await _exec(
        'UPDATE sync_clock SET manifest_id = ? WHERE origin_id = ? AND origin_seq > ? AND origin_seq <= ? AND manifest_id IS NULL',
        [manifestId, originId, manifest.fromSeq, manifest.toSeq]);
    return manifestId;
  }

  Future<int> _insertManifest(OriginManifest manifest) async {
    final top = await _selectOne(
        'SELECT MAX(manifest_id) AS top FROM sync_origin_batch');
    final manifestId = ((top?['top'] as int?) ?? 0) + 1;
    final hashes = BytesBuilder(copy: false);
    manifest.hashes.forEach(hashes.add);
    await _exec(
        'INSERT INTO sync_origin_batch (manifest_id, origin_id, from_seq, to_seq, hashes, sig) VALUES (?, ?, ?, ?, ?, ?)',
        [
          manifestId,
          manifest.origin.hex,
          manifest.fromSeq,
          manifest.toSeq,
          hashes.takeBytes(),
          hexEncode(manifest.sig),
        ]);
    return manifestId;
  }

  /// Links only the cells of [batch] that the verified [manifest] covers, so
  /// an older copy of a cell never inherits a signature it was not part of.
  Future<void> _attachReceivedManifest(
      ChangeBatch batch, OriginManifest manifest) async {
    if (manifest.origin.hex != batch.origin) return;
    final manifestId = await _storedManifestId(manifest);
    final originId = await _intern(internKindOrigin, batch.origin);
    for (final cell in batch.cells) {
      if (cell.originSeq <= manifest.fromSeq || cell.originSeq > manifest.toSeq)
        continue;
      await _exec(
          'UPDATE sync_clock SET manifest_id = ? WHERE origin_id = ? AND origin_seq = ? AND hlc = ? AND manifest_id IS NULL',
          [manifestId, originId, cell.originSeq, cell.clock]);
    }
  }

  Future<int> _storedManifestId(OriginManifest manifest) async {
    final existing = await _selectOne(
        'SELECT manifest_id FROM sync_origin_batch WHERE origin_id = ? AND from_seq = ? AND to_seq = ?',
        [manifest.origin.hex, manifest.fromSeq, manifest.toSeq]);
    return existing != null
        ? existing['manifest_id'] as int
        : _insertManifest(manifest);
  }

  @override
  Future<List<OriginManifest>> readManifests(String origin,
      {required int afterSeq, required int upToSeq}) async {
    final rows = await _select(
        'SELECT * FROM sync_origin_batch WHERE origin_id = ? AND to_seq > ? AND from_seq < ? ORDER BY from_seq',
        [origin, afterSeq, upToSeq]);
    return [for (final row in rows) _manifestFromRow(row)];
  }

  OriginManifest _manifestFromRow(Map<String, Object?> row) {
    final blob = row['hashes'] as Uint8List;
    return OriginManifest(
      origin: OriginId.fromHex(row['origin_id'] as String),
      fromSeq: row['from_seq'] as int,
      toSeq: row['to_seq'] as int,
      hashes: [
        for (var at = 0; at < blob.length; at += _hashLength)
          Uint8List.sublistView(blob, at, at + _hashLength),
      ],
      sig: hexDecode(row['sig'] as String),
    );
  }

  @override
  Future<List<OriginRegistration>> readRegistrations() async => [
        for (final row
            in await _select('SELECT * FROM sync_origin ORDER BY origin_id'))
          OriginRegistration(
            origin: OriginId.fromHex(row['origin_id'] as String),
            memberPub: hexDecode(row['member_ed25519_pub'] as String),
            createdHlc: row['created_hlc'] as int,
            sig: hexDecode(row['sig'] as String),
          ),
      ];

  @override
  Future<int> mergeRegistrations(
      Iterable<OriginRegistration> registrations) async {
    var inserted = 0;
    for (final registration in registrations) {
      final known = await _selectOne(
          'SELECT 1 AS present FROM sync_origin WHERE origin_id = ?',
          [registration.origin.hex]);
      if (known != null) continue;
      await _exec(
          'INSERT INTO sync_origin (origin_id, member_ed25519_pub, created_hlc, sig, created_date) VALUES (?, ?, ?, ?, ?)',
          [
            registration.origin.hex,
            hexEncode(registration.memberPub),
            registration.createdHlc,
            hexEncode(registration.sig),
            (registration.createdHlc >> _hlcCounterBits) ~/ _msPerSecond,
          ]);
      inserted++;
    }
    return inserted;
  }

  void _validateRepresentable(CellRecord cell) {
    final wall = cell.clock >> _hlcCounterBits;
    if (cell.clock < 0 || wall >= _hlcWallLimit)
      throw const SyncItemRejected('malformed_hlc');
  }

  int? _colIdOf(SyncTablePolicy policy, String column) {
    if (column == CellKey.existenceCol) return tombstoneColId;
    if (column == CellKey.rowCol) return policy.rowLevel ? rowLevelColId : null;
    return policy.rowLevel ? null : policy.columns[column];
  }

  int? _asTombValue(Object? value) {
    if (value == null || value is int) return value as int?;
    throw const SyncItemRejected('malformed_tombstone');
  }

  Future<int?> _causeRowId(CellRecord cell) async {
    final cause = cell.cause;
    if (cause == null) return null;
    final causePolicy = _policyByName[cause.table];
    if (causePolicy == null)
      throw const SyncItemRejected('unknown_cause_table');
    return _ensureRow(causePolicy.tblId, cause.pk);
  }

  Future<_ClockRow?> _clockRow(int key) async {
    final row = await _selectOne('''
SELECT c.hlc AS hlc, n.value AS node, o.value AS origin, c.origin_seq AS seq, c.tomb_value AS tomb_value,
       c.cause_row_id AS cause_row_id, c.manifest_id AS manifest_id
FROM sync_clock c JOIN sync_intern n ON n.id = c.node_id JOIN sync_intern o ON o.id = c.origin_id
WHERE c.key = ?''', [key]);
    if (row == null) return null;
    return _ClockRow(
        key ~/ packedKeyFactor,
        key % packedKeyFactor,
        row['hlc'] as int,
        row['node'] as String,
        row['origin'] as String,
        row['seq'] as int,
        row['tomb_value'] as int?,
        row['cause_row_id'] as int?,
        row['manifest_id'] as int?);
  }

  bool _incomingWins(_ClockRow current, CellRecord incoming) {
    if (current.isVersionOf(incoming)) return false;
    final stored = CellRecord(
        key: incoming.key,
        value: null,
        clock: current.hlc,
        node: current.node,
        origin: current.origin,
        originSeq: current.originSeq);
    return incomingWins(stored, incoming);
  }

  Future<_ItemOutcome> _holdUnknown(CellRecord cell) async {
    final key = cell.key;
    final existing = await _selectOne(
        "SELECT hlc, node, origin_id, origin_seq FROM sync_held_cell WHERE tbl = ? AND pk = ? AND col = ? AND kind = '$_heldKindUnknown'",
        [key.table, key.pk, key.col]);
    if (existing != null) {
      final stored = CellRecord(
          key: key,
          value: null,
          clock: existing['hlc'] as int,
          node: existing['node'] as String,
          origin: existing['origin_id'] as String,
          originSeq: existing['origin_seq'] as int);
      if (!incomingWins(stored, cell)) return _ItemOutcome.unchanged;
    }
    await _exec(
        "DELETE FROM sync_held_cell WHERE tbl = ? AND pk = ? AND col = ? AND kind = '$_heldKindUnknown'",
        [key.table, key.pk, key.col]);
    await _exec(
        'INSERT INTO sync_held_cell (tbl, pk, col, kind, value, hlc, node, origin_id, origin_seq) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          key.table,
          key.pk,
          key.col,
          _heldKindUnknown,
          _encodeHeldValue(cell.value),
          cell.clock,
          cell.node,
          cell.origin,
          cell.originSeq
        ]);
    return _ItemOutcome.held;
  }

  // -- value writes ---------------------------------------------------------

  /// Writes the cell's value to the base row. Returns whether the base row
  /// exists afterwards (`false` while a field-level row is still incomplete).
  Future<bool> _writeValue(
      SyncTablePolicy policy, CellRecord cell, int colId, int rowId) async {
    final pk = cell.key.pk;
    final exists = await _baseRowExists(policy, pk);
    if (colId == tombstoneColId)
      return exists || await _insertWhenComplete(policy, pk, rowId);
    if (policy.rowLevel) return _writeRowLevel(policy, cell, exists);
    final value = _asColumnValue(cell.value);
    if (exists) {
      await _exec(
          'UPDATE "${policy.tableName}" SET "${cell.key.col}" = ? WHERE id = ?',
          [value, pk]);
      return true;
    }
    await _stage(policy, cell, value);
    return _insertWhenComplete(policy, pk, rowId);
  }

  Object? _asColumnValue(Object? value) {
    if (value == null || value is int || value is String) return value;
    throw const SyncItemRejected('unsupported_value_type');
  }

  Future<bool> _baseRowExists(SyncTablePolicy policy, String pk) async =>
      await _selectOne(
          'SELECT 1 AS present FROM "${policy.tableName}" WHERE id = ?',
          [pk]) !=
      null;

  Future<bool> _writeRowLevel(
      SyncTablePolicy policy, CellRecord cell, bool exists) async {
    final content = await _decodeRowLevel(policy, cell.value);
    final columns = content.keys.toList();
    final values = [
      for (final column in columns) _asColumnValue(content[column])
    ];
    if (exists) {
      if (columns.isEmpty) return true;
      await _exec(
          'UPDATE "${policy.tableName}" SET ${columns.map((c) => '"$c" = ?').join(', ')} WHERE id = ?',
          [...values, cell.key.pk]);
      return true;
    }
    final now = _nowSeconds;
    await _exec(
        'INSERT INTO "${policy.tableName}" (id, created_date, modified_date${columns.map((c) => ', "$c"').join()}) '
        'VALUES (?, ?, ?${', ?' * columns.length})',
        [cell.key.pk, now, now, ...values]);
    return true;
  }

  Future<Map<String, Object?>> _decodeRowLevel(
      SyncTablePolicy policy, Object? value) async {
    if (value is! String) throw const SyncItemRejected('malformed_row_cell');
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>)
      throw const SyncItemRejected('malformed_row_cell');
    final allowed = (await _shapeOf(policy.tableName)).columns;
    for (final column in decoded.keys) {
      if (!allowed.contains(column) || _bookkeepingColumns.contains(column))
        throw const SyncItemRejected('unknown_row_column');
    }
    return decoded;
  }

  Future<void> _stage(
      SyncTablePolicy policy, CellRecord cell, Object? value) async {
    final key = cell.key;
    await _exec(
        "DELETE FROM sync_held_cell WHERE tbl = ? AND pk = ? AND col = ? AND kind = '$_heldKindStaged'",
        [key.table, key.pk, key.col]);
    await _exec(
        'INSERT INTO sync_held_cell (tbl, pk, col, kind, value, hlc, node, origin_id, origin_seq) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          key.table,
          key.pk,
          key.col,
          _heldKindStaged,
          _encodeHeldValue(value),
          cell.clock,
          cell.node,
          cell.origin,
          cell.originSeq
        ]);
  }

  /// D15: inserts the base row from the winning cells once `~` and every
  /// NOT NULL column without a default are known, then drops the staged cells.
  Future<bool> _insertWhenComplete(
      SyncTablePolicy policy, String pk, int rowId) async {
    if (policy.rowLevel) return false;
    final known = await _knownColumnIds(rowId);
    final shape = await _shapeOf(policy.tableName);
    final missing = shape.requiredColumns
        .any((column) => !known.contains(policy.columns[column]));
    if (!known.contains(tombstoneColId) || missing) return false;

    final staged = await _select(
        "SELECT col, value FROM sync_held_cell WHERE tbl = ? AND pk = ? AND kind = '$_heldKindStaged'",
        [policy.tableName, pk]);
    final columns = [for (final row in staged) row['col'] as String];
    final now = _nowSeconds;
    await _exec(
        'INSERT INTO "${policy.tableName}" (id, created_date, modified_date${columns.map((c) => ', "$c"').join()}) '
        'VALUES (?, ?, ?${', ?' * columns.length})',
        [
          pk,
          now,
          now,
          for (final row in staged) _decodeHeldValue(row['value'])
        ]);
    await _exec(
        "DELETE FROM sync_held_cell WHERE tbl = ? AND pk = ? AND kind = '$_heldKindStaged'",
        [policy.tableName, pk]);
    return true;
  }

  Future<Set<int>> _knownColumnIds(int rowId) async => {
        for (final row in await _select(
            'SELECT key FROM sync_clock WHERE key >= ? AND key < ?',
            [rowId * packedKeyFactor, (rowId + 1) * packedKeyFactor]))
          (row['key'] as int) % packedKeyFactor,
      };

  /// D4: a remote apply is a local revision of the row; `modified_date`
  /// becomes strictly greater than before and at least now. Once per row and
  /// batch, so a many-cell row does not run ahead of the clock.
  Future<void> _bumpRevision(
      SyncTablePolicy policy, String pk, Set<String> bumped) async {
    if (!bumped.add('${policy.tableName}/$pk')) return;
    await _exec(
        'UPDATE "${policy.tableName}" SET modified_date = MAX(COALESCE(modified_date, created_date) + 1, ?) WHERE id = ?',
        [_nowSeconds, pk]);
  }

  // -- effective existence (D5b) -------------------------------------------------

  /// Writes the effective existence of the row to `deleted_date` and
  /// re-settles every child whose tombstone cause is this row.
  Future<void> _settleRow(
      SyncTablePolicy policy, String pk, int rowId, Set<int> visited) async {
    if (!visited.add(rowId)) return;
    if (await _baseRowExists(policy, pk)) {
      final tomb = await _clockRow(rowId * packedKeyFactor + tombstoneColId);
      final existence = await _existenceOf(policy, pk, rowId);
      final wanted = existence == RowExistence.deleted ? tomb?.tombValue : null;
      await _exec(
          'UPDATE "${policy.tableName}" SET deleted_date = ? WHERE id = ? AND deleted_date IS NOT ?',
          [wanted, pk, wanted]);
    }
    final children = await _select(
        'SELECT c.key / $packedKeyFactor AS row_id, r.tbl_id AS tbl_id, r.pk AS pk FROM sync_clock c '
        'JOIN sync_row r ON r.id = c.key / $packedKeyFactor WHERE c.cause_row_id = ? AND c.key % $packedKeyFactor = $tombstoneColId',
        [rowId]);
    for (final child in children) {
      await _settleRow(_policyById[child['tbl_id'] as int]!,
          child['pk'] as String, child['row_id'] as int, visited);
    }
  }

  Future<RowExistence> _existenceOf(
      SyncTablePolicy policy, String pk, int rowId) async {
    final rows = <RowRef, RowCells>{};
    await _loadCauseChain(RowRef(policy.tableName, pk), rowId, rows);
    return rowExistence(RowRef(policy.tableName, pk), (ref) => rows[ref]);
  }

  Future<void> _loadCauseChain(
      RowRef ref, int rowId, Map<RowRef, RowCells> rows) async {
    if (rows.containsKey(ref)) return;
    final cells = await _select('''
SELECT c.key % $packedKeyFactor AS col_id, c.hlc AS hlc, n.value AS node, o.value AS origin, c.origin_seq AS seq,
       c.tomb_value AS tomb_value, cr.tbl_id AS cause_tbl_id, cr.pk AS cause_pk, c.cause_row_id AS cause_row_id
FROM sync_clock c JOIN sync_intern n ON n.id = c.node_id JOIN sync_intern o ON o.id = c.origin_id
LEFT JOIN sync_row cr ON cr.id = c.cause_row_id
WHERE c.key >= ? AND c.key < ?''',
        [rowId * packedKeyFactor, (rowId + 1) * packedKeyFactor]);
    final records = <CellRecord>[];
    final policy = _policyByName[ref.table]!;
    int? causeRowId;
    for (final cell in cells) {
      final colId = cell['col_id'] as int;
      final causeTbl = cell['cause_tbl_id'] as int?;
      if (colId == tombstoneColId) causeRowId = cell['cause_row_id'] as int?;
      records.add(CellRecord(
        key: CellKey(ref.table, ref.pk, _wireColumn(policy, colId)),
        value: colId == tombstoneColId ? cell['tomb_value'] : null,
        clock: cell['hlc'] as int,
        node: cell['node'] as String,
        origin: cell['origin'] as String,
        originSeq: cell['seq'] as int,
        cause: causeTbl == null
            ? null
            : RowRef(
                _policyById[causeTbl]!.tableName, cell['cause_pk'] as String),
      ));
    }
    rows[ref] = CellListRow(records);
    final cause =
        records.where((r) => r.key.isExistence).map((r) => r.cause).firstOrNull;
    if (cause != null && causeRowId != null)
      await _loadCauseChain(cause, causeRowId, rows);
  }

  // -- origin switch (D6b, D14) -------------------------------------------------

  @override
  Future<SyncOriginSwitchReport> switchOrigin(
    OriginSwitchReason reason, {
    required String newOrigin,
    int? sentMark,
    int hlcFloor = 0,
  }) =>
      _db.transaction(() async {
        await _requireSwitchable(reason);
        await _setApplyMode(_applyModeOriginSwitch);
        final switched = await _sealOldOrigin(newOrigin);
        final report = await _applyReason(reason, switched, sentMark, hlcFloor);
        await _setApplyMode(_applyModeCapture);
        return report;
      });

  @override
  Future<SyncOriginSwitchReport> localReset({
    required String newOrigin,
    Future<void> Function()? clearUserData,
    Future<void> Function()? importRows,
  }) =>
      _db.transaction(() async {
        await _requireSwitchable(OriginSwitchReason.localReset);
        await _setApplyMode(_applyModeOriginSwitch);
        final switched = await _sealOldOrigin(newOrigin);
        final report = await _applyReason(
            OriginSwitchReason.localReset, switched, null, 0);
        await (clearUserData ?? _clearUserTables)();
        await _setApplyMode(_applyModeCapture);
        await importRows?.call();
        return report;
      });

  Future<void> _requireSwitchable(OriginSwitchReason reason) async {
    if (reason == OriginSwitchReason.initial)
      throw ArgumentError.value(reason, 'reason', 'initial is not a switch');
    final state = await _state();
    if (state['apply_mode'] != _applyModeCapture)
      throw StateError('apply_mode is ${state['apply_mode']}');
    final phase = state['upgrade_phase'];
    if (phase != null && phase != 'done')
      throw StateError('preparing: upgrade phase $phase is running');
  }

  Future<_Switched> _sealOldOrigin(String newOrigin) async {
    final oldOrigin = await _ownOrigin();
    final newOriginId = await _intern(internKindOrigin, newOrigin);
    final reused = await _selectOne(
        'SELECT 1 AS used FROM sync_clock WHERE origin_id = ? UNION ALL SELECT 1 FROM sync_vector WHERE origin_id = ? LIMIT 1',
        [newOriginId, newOrigin]);
    if (newOrigin == oldOrigin || reused != null)
      throw ArgumentError.value(newOrigin, 'newOrigin', 'origin already used');
    final oldOriginId = await _intern(internKindOrigin, oldOrigin);
    await _exec(
        'UPDATE sync_state SET origin_id = ?, local_origin_id = ?, next_seq = 1 WHERE id = ?',
        [newOriginId, newOrigin, _stateId]);
    return _Switched(oldOrigin, oldOriginId, newOrigin, newOriginId);
  }

  Future<SyncOriginSwitchReport> _applyReason(OriginSwitchReason reason,
      _Switched switched, int? sentMark, int hlcFloor) async {
    switch (reason) {
      case OriginSwitchReason.restore:
      case OriginSwitchReason.keyLost:
        final cursor = await _sealWithCursor(switched, sentMark);
        final leftBehind = await _countUnsentSecurityCells(switched.oldId);
        if (reason == OriginSwitchReason.restore) await _raiseHlc(hlcFloor);
        await _scheduleReauthor(ReauthorSpec.adopt(
            oldOriginId: switched.oldId,
            newOriginId: switched.newId,
            sentMark: sentMark));
        return _report(switched, cursor,
            reauthor: true, securityLeftBehind: leftBehind);
      case OriginSwitchReason.localReset:
        await _exec(
            'DELETE FROM sync_clock WHERE key / $packedKeyFactor IN (SELECT id FROM sync_row WHERE tbl_id < $securityTblIdFloor)');
        await _adoptUnsentSecurityCells(switched);
        await _exec('DELETE FROM sync_held_cell');
        await _exec('DELETE FROM sync_held_envelope');
        await _exec('DELETE FROM sync_vector');
        return _report(switched, null, reauthor: false);
      case OriginSwitchReason.groupSwitch:
        for (final table in _securityTables) {
          await _exec('DELETE FROM $table');
        }
        await _exec('DELETE FROM sync_held_envelope');
        await _exec('DELETE FROM sync_peer_state_table');
        await _exec('DELETE FROM sync_vector');
        await _exec(
            'DELETE FROM sync_clock WHERE key / $packedKeyFactor IN (SELECT id FROM sync_row WHERE tbl_id >= $securityTblIdFloor)');
        await _exec('UPDATE sync_clock SET manifest_id = NULL');
        await _scheduleReauthor(ReauthorSpec.all(newOriginId: switched.newId));
        return _report(switched, null, reauthor: true);
      case OriginSwitchReason.initial:
        throw ArgumentError.value(reason, 'reason');
    }
  }

  /// U11: the sealed cursor is the highest retained (manifested, at or below
  /// the mark) seq. Adopted cells do not count as held.
  Future<int> _sealWithCursor(_Switched switched, int? sentMark) async {
    final row = await _selectOne(
        'SELECT MAX(origin_seq) AS top FROM sync_clock WHERE origin_id = ? AND manifest_id IS NOT NULL AND (? IS NULL OR origin_seq <= ?)',
        [switched.oldId, sentMark, sentMark]);
    final cursor = (row?['top'] as int?) ?? 0;
    await _exec(
        'INSERT INTO sync_vector (origin_id, cursor) VALUES (?, ?) ON CONFLICT (origin_id) DO UPDATE SET cursor = excluded.cursor',
        [switched.oldOrigin, cursor]);
    return cursor;
  }

  Future<void> _raiseHlc(int floor) async {
    final row = await _selectOne('SELECT MAX(hlc) AS top FROM sync_clock');
    final highest = (row?['top'] as int?) ?? 0;
    await _exec('UPDATE sync_state SET hlc = MAX(hlc, ?, ?) WHERE id = ?',
        [highest, floor, _stateId]);
  }

  Future<void> _scheduleReauthor(ReauthorSpec spec) => _exec(
      "UPDATE sync_state SET reauthor_spec = ?, upgrade_phase = 'reauthor', upgrade_cursor = NULL WHERE id = ?",
      [spec.encode(), _stateId]);

  /// Security cells without a manifest: no peer can hold them, they stay on
  /// the sealed origin and are never sent (D14, U11/rooted).
  Future<int> _countUnsentSecurityCells(int originId) async {
    final row = await _selectOne(
        'SELECT COUNT(*) AS total FROM sync_clock WHERE origin_id = ? AND manifest_id IS NULL '
        'AND (SELECT tbl_id FROM sync_row WHERE id = sync_clock.key / $packedKeyFactor) >= ?',
        [originId, securityTblIdFloor]);
    return row!['total'] as int;
  }

  /// `local_reset` keeps the security tables, so their never-sent cells move
  /// to the new origin like any adopted cell; nobody else could serve them.
  Future<void> _adoptUnsentSecurityCells(_Switched switched) async {
    final keys = await _select(
        'SELECT key FROM sync_clock WHERE origin_id = ? AND manifest_id IS NULL '
        'AND (SELECT tbl_id FROM sync_row WHERE id = sync_clock.key / $packedKeyFactor) >= ? '
        'ORDER BY origin_seq, key',
        [switched.oldId, securityTblIdFloor]);
    var nextSeq = (await _state())['next_seq'] as int;
    for (final row in keys) {
      await _exec(
          'UPDATE sync_clock SET origin_id = ?, origin_seq = ? WHERE key = ?',
          [switched.newId, nextSeq++, row['key']]);
    }
    await _exec(
        'UPDATE sync_state SET next_seq = ? WHERE id = ?', [nextSeq, _stateId]);
  }

  SyncOriginSwitchReport _report(_Switched switched, int? cursor,
          {required bool reauthor, int securityLeftBehind = 0}) =>
      SyncOriginSwitchReport(
          oldOrigin: switched.oldOrigin,
          newOrigin: switched.newOrigin,
          sealedCursor: cursor,
          reauthorScheduled: reauthor,
          securityLeftBehind: securityLeftBehind);

  Future<void> _clearUserTables() async {
    for (final policy in syncTablePolicies) {
      await _exec('DELETE FROM "${policy.tableName}"');
    }
  }
}

enum _ItemOutcome { applied, unchanged, held, failed }

class _Switched {
  final String oldOrigin;
  final int oldId;
  final String newOrigin;
  final int newId;
  const _Switched(this.oldOrigin, this.oldId, this.newOrigin, this.newId);
}
