part of 'drift_sync_change_store.dart';

const String _noPeer = '';
const String _unknownHeldKindClause = "kind = '$_heldKindUnknown'";

/// The cell-level store the async session engine runs over, served from the
/// same tables and the same connection as [DriftSyncChangeStore] (T22e).
///
/// A remote apply is isolated per item by a savepoint; the batch transaction
/// ([inTransaction]) holds `apply_mode = 1` so the capture triggers stay
/// silent. Versions that lose to a stored winner are indexed in
/// `sync_superseded` (F5); the triggers on `sync_clock` keep that index in
/// step with local captures and with winning remote versions.
class DriftAsyncSyncStore implements AsyncSyncStorePort {
  final DriftSyncChangeStore _store;
  _ApplyContext? _batchContext;

  DriftAsyncSyncStore(this._store);

  GeneratedDatabase get _db => _store._db;

  // -- local state ----------------------------------------------------------

  @override
  Future<OriginId> localOrigin() async =>
      OriginId.fromHex(await _store._ownOrigin());

  @override
  Future<int> nextSeq() async => (await _store._state())['next_seq'] as int;

  @override
  Future<int> hlc() async => (await _store._state())['hlc'] as int;

  @override
  Future<int> ownSignedTo() async =>
      _store._highestSignedSeq(await _store._ownOrigin());

  @override
  Future<Map<String, int>> vector() => _store.readVector();

  @override
  Future<List<OriginRegistration>> registrations() =>
      _store.readRegistrations();

  // -- cells ----------------------------------------------------------------

  @override
  Future<StoredCell?> storedCell(CellKey key) async {
    final clockKey = await _clockKeyOf(key);
    if (clockKey == null) return _storedUnknownCell(key);
    final rows = await _store._select(
        '${DriftSyncChangeStore._clockCellSelect} WHERE c.key = ?', [clockKey]);
    return (await _storedCells(rows)).firstOrNull;
  }

  /// The held cell of a table or column this release does not know (FR-042).
  /// The session engine re-reads a cell it relays by key, so without this a
  /// relayed unknown cell would look superseded and be skipped forever.
  Future<StoredCell?> _storedUnknownCell(CellKey key) async {
    final row = await _store._selectOne(
        "SELECT * FROM sync_held_cell WHERE $_unknownHeldKindClause AND tbl = ? AND pk = ? AND col = ?",
        [key.table, key.pk, key.col]);
    return row == null ? null : _unknownStoredCell(row);
  }

  @override
  Future<StoredCell?> nextCellOfOrigin(String origin, int afterSeq) async {
    final rows = await _store._select(
        '${DriftSyncChangeStore._clockCellSelect} WHERE c.origin_id = (SELECT id FROM sync_intern WHERE kind = $internKindOrigin AND value = ?) AND c.origin_seq > ? '
        'ORDER BY c.origin_seq, c.key LIMIT 1',
        [origin, afterSeq]);
    final clockCell = (await _storedCells(rows)).firstOrNull;
    final unknownCell = await _nextUnknownCell(origin, afterSeq);
    if (clockCell == null) return unknownCell;
    if (unknownCell == null) return clockCell;
    return unknownCell.record.originSeq < clockCell.record.originSeq
        ? unknownCell
        : clockCell;
  }

  @override
  Future<OriginScanEntry> nextOfOrigin(String origin, int afterSeq) =>
      _db.transaction(() async => (
            cell: await nextCellOfOrigin(origin, afterSeq),
            held: await _nextHeld(origin, afterSeq),
            superseded: await nextSupersededOfOrigin(origin, afterSeq),
          ));

  @override
  Future<List<String>> cellOrigins() async => [
        for (final row in await _store._select(
            'SELECT DISTINCT o.value AS origin FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id '
            'UNION SELECT DISTINCT origin_id FROM sync_held_cell WHERE $_unknownHeldKindClause'))
          row['origin'] as String,
      ];

  @override
  Future<List<CellRecord>> ownCellsInRange(int fromSeq, int toSeq) async {
    final batch = await _store.readChanges(await _store._ownOrigin(),
        afterSeq: fromSeq, upToSeq: toSeq, limit: toSeq - fromSeq);
    return batch.cells;
  }

  @override
  Future<void> attachOwnManifest(OriginManifest manifest) async {
    if (manifest.origin.hex != await _store._ownOrigin()) {
      throw ArgumentError.value(
          manifest.origin, 'manifest', 'not the current origin');
    }
    await _db.transaction(() => _store._storeManifest(manifest));
  }

  Future<int?> _clockKeyOf(CellKey key) async {
    final security = _store._securityByWire[key.table];
    final policy = _store._policyByName[key.table];
    final tblId = security?.tblId ?? policy?.tblId;
    if (tblId == null) return null;
    final colId =
        security != null ? rowLevelColId : _store._colIdOf(policy!, key.col);
    if (colId == null) return null;
    final row = await _store._selectOne(
        'SELECT id FROM sync_row WHERE tbl_id = ? AND pk = ?', [tblId, key.pk]);
    return row == null ? null : (row['id'] as int) * packedKeyFactor + colId;
  }

  Future<CellKey?> _cellKeyOfClockKey(int clockKey) async {
    final row = await _store._selectOne(
        'SELECT tbl_id, pk FROM sync_row WHERE id = ?',
        [clockKey ~/ packedKeyFactor]);
    if (row == null) return null;
    final tblId = row['tbl_id'] as int;
    final security = _store._securityById[tblId];
    if (security != null) {
      return CellKey(security.wireName, row['pk'] as String, CellKey.rowCol);
    }
    final policy = _store._policyById[tblId]!;
    return CellKey(policy.tableName, row['pk'] as String,
        _store._wireColumn(policy, clockKey % packedKeyFactor));
  }

  Future<List<StoredCell>> _storedCells(List<Map<String, Object?>> rows) async {
    final cells = <StoredCell>[];
    for (final row in rows) {
      final record = (await _store._recordsOfClockRows([row])).firstOrNull;
      if (record == null) continue;
      cells.add(StoredCell(record,
          recordedAt: row['recorded_at'] as int,
          manifest: await _manifestOf(row['manifest_id'] as int?)));
    }
    return cells;
  }

  Future<OriginManifest?> _manifestOf(int? manifestId) async {
    if (manifestId == null) return null;
    final row = await _store._selectOne(
        'SELECT * FROM sync_origin_batch WHERE manifest_id = ?', [manifestId]);
    return row == null ? null : _store._manifestFromRow(row);
  }

  Future<StoredCell?> _nextUnknownCell(String origin, int afterSeq) async {
    final row = await _store._selectOne(
        "SELECT * FROM sync_held_cell WHERE $_unknownHeldKindClause AND origin_id = ? AND origin_seq > ? "
        'ORDER BY origin_seq LIMIT 1',
        [origin, afterSeq]);
    return row == null ? null : _unknownStoredCell(row);
  }

  Future<StoredCell> _unknownStoredCell(Map<String, Object?> row) async {
    final origin = row['origin_id'] as String;
    final record = (await _store._readUnknownCells(
            origin, (row['origin_seq'] as int) - 1, row['origin_seq'] as int))
        .first;
    return StoredCell(record,
        recordedAt: 0, manifest: await _manifestOf(row['manifest_id'] as int?));
  }

  // -- superseded index (F5) --------------------------------------------------

  @override
  Future<(int, CellKey)?> nextSupersededOfOrigin(
      String origin, int afterSeq) async {
    final row = await _store._selectOne(
        'SELECT s.origin_seq AS seq, s.clock_key AS clock_key FROM sync_superseded s '
        'JOIN sync_intern o ON o.id = s.origin_id WHERE o.value = ? AND s.origin_seq > ? '
        'ORDER BY s.origin_seq LIMIT 1',
        [origin, afterSeq]);
    if (row == null) return null;
    final key = await _cellKeyOfClockKey(row['clock_key'] as int);
    return key == null ? null : (row['seq'] as int, key);
  }

  @override
  Future<void> dropSupersededEntry(String origin, int seq) => _store._exec(
      'DELETE FROM sync_superseded WHERE origin_seq = ? AND origin_id IN '
      '(SELECT id FROM sync_intern WHERE kind = $internKindOrigin AND value = ?)',
      [seq, origin]);

  @override
  Future<int> supersededIndexed() async => (await _store._selectOne(
      'SELECT COUNT(*) AS total FROM sync_superseded'))!['total'] as int;

  Future<void> _indexSuperseded(
      String origin, int seq, CellKey storedKey) async {
    final clockKey = await _clockKeyOf(storedKey);
    if (clockKey == null) return;
    final winner = await _store._clockRow(clockKey);
    if (winner == null ||
        (winner.origin == origin && winner.originSeq == seq)) {
      return;
    }
    final originId = await _store._intern(internKindOrigin, origin);
    await _store._exec(
        'INSERT OR REPLACE INTO sync_superseded (origin_id, origin_seq, clock_key) VALUES (?, ?, ?)',
        [originId, seq, clockKey]);
  }

  // -- received data ----------------------------------------------------------

  @override
  Future<ApplyOutcome> applyRemote(Change change, OriginManifest manifest,
          {required int nowMs}) =>
      _inRemoteMode(() => _applyItem(change.toCellRecord(), manifest));

  Future<ApplyOutcome> _applyItem(
      CellRecord record, OriginManifest manifest) async {
    await _store._exec('SAVEPOINT $_savepoint');
    try {
      await _store._exec('UPDATE sync_state SET hlc = MAX(hlc, ?) WHERE id = ?',
          [record.clock, _stateId]);
      final outcome =
          await _store._applyCell(record, _batchContext ??= _ApplyContext());
      final result = outcome == _ItemOutcome.unchanged
          ? await _settleLoser(record)
          : await _settleWinner(record, manifest);
      await _store._exec('RELEASE $_savepoint');
      return result;
    } catch (_) {
      await _store._exec('ROLLBACK TO $_savepoint');
      await _store._exec('RELEASE $_savepoint');
      return ApplyOutcome.failed;
    }
  }

  Future<ApplyOutcome> _settleLoser(CellRecord record) async {
    await _indexSuperseded(record.origin, record.originSeq, record.key);
    return ApplyOutcome.unchanged;
  }

  Future<ApplyOutcome> _settleWinner(
      CellRecord record, OriginManifest manifest) async {
    final manifestId = await _store._storedManifestId(manifest);
    final originId = await _store._intern(internKindOrigin, record.origin);
    await _store._exec(
        'UPDATE sync_clock SET manifest_id = ? WHERE origin_id = ? AND origin_seq = ? AND hlc = ?',
        [manifestId, originId, record.originSeq, record.clock]);
    await _store._exec(
        "UPDATE sync_held_cell SET manifest_id = ? WHERE $_unknownHeldKindClause AND origin_id = ? AND origin_seq = ?",
        [manifestId, record.origin, record.originSeq]);
    return ApplyOutcome.applied;
  }

  @override
  Future<bool> advanceCursor(String origin,
      {required int fromSeq, required int toSeq}) async {
    if (origin == await _store._ownOrigin()) return false;
    return _store._advanceCursor(ChangeBatch(
        origin: origin, fromSeq: fromSeq, toSeq: toSeq, cells: const []));
  }

  // The Drift store keeps no per-commit log; the diagnostics service reads
  // the tables themselves.
  @override
  Future<void> logCommit(String origin, int seq) async {}

  @override
  Future<T> inTransaction<T>(Future<T> Function() body) => _inRemoteMode(body);

  /// Runs [body] in a transaction with `apply_mode = 1`; nested calls join the
  /// running one.
  Future<T> _inRemoteMode<T>(Future<T> Function() body) async {
    final mode = (await _store._state())['apply_mode'];
    if (mode == _applyModeRemote) return body();
    return _db.transaction(() async {
      await _store._requireIdleCaptureMode();
      await _store._setApplyMode(_applyModeRemote);
      final outerContext = _batchContext;
      _batchContext = _ApplyContext();
      try {
        final result = await body();
        await _store._setApplyMode(_applyModeCapture);
        return result;
      } finally {
        _batchContext = outerContext;
      }
    });
  }

  // -- held envelopes ---------------------------------------------------------

  Future<HeldEnvelope?> _nextHeld(String origin, int afterSeq) async =>
      (await _heldWhere(
              'origin_id = ? AND origin_seq > ? ORDER BY origin_seq LIMIT 1',
              [origin, afterSeq]))
          .firstOrNull;

  @override
  Future<List<HeldEnvelope>> heldEnvelopes() =>
      _heldWhere('origin_id IS NOT NULL ORDER BY origin_id, origin_seq', []);

  @override
  Future<HeldEnvelope?> heldAt(String origin, int seq) async =>
      (await _heldWhere('origin_id = ? AND origin_seq = ?', [origin, seq]))
          .firstOrNull;

  Future<List<HeldEnvelope>> _heldWhere(
      String clause, List<Object?> args) async {
    final rows = await _store._select(
        'SELECT * FROM sync_held_envelope WHERE $clause', args);
    return [for (final row in rows) await _heldFromRow(row)];
  }

  Future<HeldEnvelope> _heldFromRow(Map<String, Object?> row) async {
    final peer = row['peer'] as String;
    return HeldEnvelope(
      envelope: ChangeEnvelope.decode(row['envelope'] as Uint8List),
      manifest: (await _manifestOf(row['manifest_id'] as int?))!,
      reason: HeldReason.values.byName(row['reason'] as String),
      recordedAt: row['recorded_at'] as int,
      peer: peer == _noPeer ? null : peer,
      failCount: row['fail_count'] as int,
      category: row['category'] as String?,
    );
  }

  @override
  Future<void> putHeld(HeldEnvelope held) => _db.transaction(() async {
        final existing = await heldAt(held.origin, held.seq);
        if (existing != null && existing.failCount > held.failCount) {
          held.failCount = existing.failCount;
        }
        final manifestId = await _store._storedManifestId(held.manifest);
        await _store._exec(
            'INSERT INTO sync_held_envelope (tbl, pk, col, peer, reason, fail_count, category, envelope, origin_id, origin_seq, manifest_id, recorded_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
            'ON CONFLICT (origin_id, origin_seq) DO UPDATE SET tbl = excluded.tbl, pk = excluded.pk, col = excluded.col, '
            'peer = excluded.peer, reason = excluded.reason, fail_count = excluded.fail_count, category = excluded.category, '
            'envelope = excluded.envelope, manifest_id = excluded.manifest_id, recorded_at = excluded.recorded_at',
            [
              held.key.table,
              held.key.pk,
              held.key.col,
              held.peer ?? _noPeer,
              held.reason.name,
              held.failCount,
              held.category,
              held.envelope.encode(),
              held.origin,
              held.seq,
              manifestId,
              held.recordedAt,
            ]);
      });

  @override
  Future<bool> removeHeld(String origin, int seq) async {
    final existed = await heldAt(origin, seq) != null;
    await _store._exec(
        'DELETE FROM sync_held_envelope WHERE origin_id = ? AND origin_seq = ?',
        [origin, seq]);
    return existed;
  }

  @override
  Future<bool> isSuperseded(HeldEnvelope held) async {
    final current = await storedCell(held.key);
    if (current == null) return false;
    final envelope = held.envelope;
    final heldVersion = CellRecord(
        key: held.key,
        value: null,
        clock: envelope.hlc,
        node: envelope.node,
        origin: held.origin,
        originSeq: held.seq);
    return compareCellVersions(heldVersion, current.record) <= 0;
  }

  @override
  Future<void> dropSupersededHeld(HeldEnvelope held) =>
      _db.transaction(() async {
        await removeHeld(held.origin, held.seq);
        await _indexSuperseded(held.origin, held.seq, held.key);
      });

  // -- security view ------------------------------------------------------------

  @override
  Future<SyncStore> securityProjection() async {
    final state = await _store._state();
    final groupHex = state['group_id'] as String?;
    final projection = SyncStore(
      memberId: state['member_id'] as String? ?? '',
      origin: SyncIdSource().origin(),
      initialHlc: state['hlc'] as int,
    );
    if (groupHex != null) projection.groupId = GroupId.fromHex(groupHex);
    final cells = await _store.readSecurityCells();
    projection.applyBatch(ChangeBatch(
        origin: projection.localOrigin.hex,
        fromSeq: 0,
        toSeq: 0,
        cells: cells));
    for (final registration in await _store.readRegistrations()) {
      projection.addRegistration(registration);
    }
    return projection;
  }

  @override
  Future<void> persistRegistrations(Iterable<OriginRegistration> rows) async {
    await _store.mergeRegistrations(rows);
  }
}
