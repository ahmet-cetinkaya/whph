/// The session engine's in-memory replica store (T12).
///
/// Holds, for one device, what the Drift store of T18 holds in `sync_clock`,
/// `sync_vector`, `sync_origin_batch`, `sync_held_envelope`, `sync_origin` and
/// `sync_state`:
///
/// * the winning version of every cell with its local `recorded_at` and the
///   signed manifest that authenticates it (D1, D7);
/// * the own change sequence: current origin and `next_seq` (D2), sealed
///   former own origins (D6b);
/// * the received vector (per-origin cursors, [VersionVector]);
/// * held envelopes (`missing_key`, `apply_failed`, `unverified`) relayed
///   verbatim (D15);
/// * origin registrations (`sync_origin`, D7).
///
/// Every mutation is synchronous and therefore atomic with respect to other
/// sessions of the same isolate (the in-memory analogue of one DB
/// transaction). The store never stages cells (D15 staging is Drift-only:
/// existence here is computed from cells, there are no base rows).
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../clock/hlc.dart';
import '../clock/version_vector.dart';
import '../merge/cell_merge.dart';
import '../model/change.dart';
import '../model/envelope.dart';
import '../model/ids.dart';
import '../model/manifest.dart';
import '../protocol/errors.dart';
import '../protocol/messages.dart';
import '../protocol/version.dart';
import 'replica_store.dart';
import 'sync_ledger.dart';

/// The grow-only security tables, synced as ordinary row-level cells (D1,
/// D13). They are never re-authored; a group
/// switch purges them (NB-1). `sync_origin` travels in the `OriginRegistry`
/// message instead (see [SyncStore.registrations]).
abstract final class SecurityTables {
  static const member = 'sync_member';
  static const revocation = 'sync_revocation';
  static const epochGrant = 'sync_epoch_grant';

  static const all = {member, revocation, epochGrant};

  static bool contains(String table) => all.contains(table);
}

/// One stored cell version with its local metadata.
final class StoredCell {
  StoredCell(this.record, {required this.recordedAt, this.manifest});

  final CellRecord record;

  /// Local wall time (ms) when this version was written or received.
  final int recordedAt;

  /// The signed manifest covering this version (`manifest_id`); `null` for an
  /// own cell not yet sent, or an un-manifested cell of a sealed origin.
  OriginManifest? manifest;

  StoredCell _copy() => StoredCell(record, recordedAt: recordedAt, manifest: manifest);

  @override
  String toString() => 'StoredCell($record${manifest == null ? ', unsigned' : ''})';
}

/// Why an envelope is held unapplied (`sync_held_envelope.reason`, D13, D15).
enum HeldReason {
  /// The epoch key is not held (SC-014). Not an FR-017 failure.
  missingKey,

  /// Apply failed (FR-010/FR-011); retried and refetched; counts for FR-017.
  applyFailed,

  /// The manifest signer is not (yet) a known member, or the change's origin
  /// is revoked above its current cutoff. Retried when membership or cutoffs
  /// change (T12 addition, see the report).
  unverified,
}

/// A received change held unapplied, relayed verbatim with its manifest.
final class HeldEnvelope {
  HeldEnvelope({
    required this.envelope,
    required this.manifest,
    required this.reason,
    required this.recordedAt,
    this.peer,
    this.failCount = 0,
    this.category,
  });

  final ChangeEnvelope envelope;
  final OriginManifest manifest;
  HeldReason reason;
  final int recordedAt;

  /// Member id of the peer it was received from.
  String? peer;

  /// Failed apply attempts (`apply_failed`).
  int failCount;

  /// Failure or rejection category (never values).
  String? category;

  String get origin => envelope.origin.hex;
  int get seq => envelope.originSeq;
  CellKey get key => CellKey(envelope.tbl, envelope.pk, envelope.col);
  RowRef get row => RowRef(envelope.tbl, envelope.pk);

  HeldEnvelope _copy() => HeldEnvelope(
        envelope: envelope,
        manifest: manifest,
        reason: reason,
        recordedAt: recordedAt,
        peer: peer,
        failCount: failCount,
        category: category,
      );

  @override
  String toString() => 'HeldEnvelope(${reason.name}, $key, $origin#$seq, fails=$failCount)';
}

/// Result of [SyncStore.applyRemote].
enum ApplyOutcome {
  /// The version won and was stored.
  applied,

  /// Same or older version; nothing changed except possibly an attached
  /// manifest (idempotent, FR-007, FR-013).
  unchanged,

  /// The injected apply fault fired; nothing changed (the item's savepoint
  /// rolled back, FR-010).
  failed,
}

/// Result of [SyncStore.switchOrigin].
final class SwitchOriginOutcome {
  const SwitchOriginOutcome({
    required this.oldOrigin,
    required this.newOrigin,
    required this.sealedCursor,
    required this.moved,
    required this.purged,
    this.securityLeftBehind = 0,
  });

  final OriginId oldOrigin;
  final OriginId newOrigin;

  /// Cursor set for the sealed old origin (`null` when the vector was
  /// cleared).
  final int? sealedCursor;

  /// Never-sent security cells that stayed on [oldOrigin] (`restore`,
  /// `keyLost`, U11/rooted): their carrier cannot vouch for them under a new
  /// origin, so the device needs re-pairing when this is above 0.
  final int securityLeftBehind;

  /// Cells moved to the new origin (adopted or re-authored).
  final int moved;

  /// Cells deleted by the reason step (`local_reset`, `group_switch`).
  final int purged;

  @override
  String toString() => 'SwitchOriginOutcome($oldOrigin -> $newOrigin, cursor=$sealedCursor, moved=$moved, '
      'purged=$purged)';
}

/// An immutable copy of a whole [SyncStore] (the DB file) for restore tests.
final class SyncStoreSnapshot {
  SyncStoreSnapshot._(this._store);

  final SyncStore _store;

  String get memberId => _store.memberId;
  OriginId get localOrigin => _store.localOrigin;
  int get nextSeq => _store.nextSeq;
}

/// The engine's in-memory replica store (see the library documentation).
final class SyncStore implements ReplicaStore {
  SyncStore({required String memberId, required OriginId origin, int initialHlc = 0})
      : _memberId = memberId,
        _origin = origin,
        _clock = HlcClock(initialHlc);

  String _memberId;
  OriginId _origin;
  int _nextSeq = 1;
  int _ownSignedTo = 0;
  HlcClock _clock;

  /// table -> pk -> col -> cell. Insertion-ordered, hence deterministic.
  final Map<String, Map<String, Map<String, StoredCell>>> _tables = {};

  /// origin hex -> seq -> cell, for every stored cell.
  final Map<String, SplayTreeMap<int, StoredCell>> _byOrigin = {};

  /// origin hex -> seq -> key of the cell whose winner replaced that version
  /// (F5). Lets the sender find the winner behind a seq it omits. Disjoint
  /// from [_byOrigin]; every key has a current cell.
  final Map<String, SplayTreeMap<int, CellKey>> _superseded = {};

  /// Received vector of foreign and sealed own origins.
  VersionVector _vector = VersionVector();

  /// origin hex -> seq -> held envelope.
  final Map<String, SplayTreeMap<int, HeldEnvelope>> _held = {};

  /// origin hex -> registration rows (`sync_origin`, verified before adding).
  final Map<String, List<OriginRegistration>> _registrations = {};

  final Set<String> _sealed = {};

  /// Test hook (T12 acc 3): returns `true` to make the apply of a received
  /// change fail as an injected SQL failure would; nothing is changed.
  bool Function(Change change)? applyFault;

  /// Every committed application of a received version (including idempotent
  /// no-op re-applies), keyed `origin#seq` (diagnostics for FR-012 tests).
  final Map<String, int> commitLog = {};

  // --- Identity and own sequence ----------------------------------------------

  @override
  String get nodeId => _memberId;

  /// The member id stamped on local writes (`sync_state` identity).
  String get memberId => _memberId;

  /// Replaced only by a `key_lost` identity change (D14 rule 2).
  set memberId(String value) {
    if (value.isEmpty) throw ArgumentError.value(value, 'memberId', 'must not be empty');
    _memberId = value;
  }

  /// The current own origin (`local_origin_id`).
  OriginId get localOrigin => _origin;

  /// The next own seq (`next_seq`).
  int get nextSeq => _nextSeq;

  /// Highest own seq authored under [localOrigin].
  int get highestOwnSeq => _nextSeq - 1;

  /// Highest own seq covered by a persisted own manifest.
  int get ownSignedTo => _ownSignedTo;

  /// Former own origins, never authored again (D6b).
  Set<String> get sealedOrigins => Set.unmodifiable(_sealed);

  /// The current HLC state (`sync_state.hlc`).
  int get hlc => _clock.current;

  /// The group this DB's security rows belong to (`sync_state.group_id`,
  /// D7); kept when the key file is lost so a later pairing knows whether
  /// the rows can be reused.
  GroupId? groupId;

  // --- ReplicaStore -------------------------------------------------------------

  @override
  CellRecord writeLocal(CellKey key, Object? value, {required int nowMs, RowRef? cause}) {
    if (cause != null && !key.isExistence) throw ArgumentError.value(cause, 'cause', 'only on an existence cell');
    final encoded = ChangeValue.of(value);
    if (encoded.payload.length > SyncLimits.maxValueBytes) {
      throw ValueTooLargeException(encoded.payload.length, SyncLimits.maxValueBytes);
    }
    final record = CellRecord(
      key: key,
      value: value,
      clock: _clock.tick(nowMs),
      node: _memberId,
      origin: _origin.hex,
      originSeq: _nextSeq++,
      cause: cause,
    );
    _put(StoredCell(record, recordedAt: nowMs));
    return record;
  }

  @override
  CellRecord? read(CellKey key) => _cell(key)?.record;

  /// The stored version of [key] with its metadata, or `null`.
  StoredCell? storedCell(CellKey key) => _cell(key);

  @override
  Iterable<CellRecord> get cells sync* {
    for (final rows in _tables.values) {
      for (final row in rows.values) {
        for (final cell in row.values) {
          yield cell.record;
        }
      }
    }
  }

  @override
  Iterable<String> rowsOf(String table) => _tables[table]?.keys ?? const [];

  /// Every known table.
  Iterable<String> get tables => _tables.keys;

  @override
  bool isRowAlive(String table, String pk) => existenceOf(RowRef(table, pk)) == RowExistence.alive;

  /// Effective existence of [row] (FR-006, D5b).
  RowExistence existenceOf(RowRef row) => rowExistence(row, _lookup);

  /// Every cell of [row], or an empty list.
  List<CellRecord> cellsOfRow(RowRef row) =>
      [for (final c in _tables[row.table]?[row.pk]?.values ?? const <StoredCell>[]) c.record];

  /// Cursors of every origin, including the own current origin at
  /// `next_seq − 1`. Unmodifiable snapshot, keyed by origin hex.
  @override
  Map<String, int> get vector {
    final map = Map.of(_vector.toMap());
    if (_nextSeq > 1) map[_origin.hex] = _nextSeq - 1;
    return Map.unmodifiable(map);
  }

  /// The cursor of [origin] (own current origin: `next_seq − 1`).
  int cursorOf(String origin) => origin == _origin.hex ? _nextSeq - 1 : _vector.cursorOf(origin);

  @override
  List<ChangeBatch> changesSince(Map<String, int> peerVector, {int maxCellsPerBatch = 256}) {
    if (maxCellsPerBatch < 1) throw ArgumentError.value(maxCellsPerBatch, 'maxCellsPerBatch');
    final batches = <ChangeBatch>[];
    final snapshot = vector;
    for (final origin in snapshot.keys.toList()..sort()) {
      final bound = snapshot[origin]!;
      var from = peerVector[origin] ?? 0;
      if (bound <= from) continue;
      var pending = <CellRecord>[];
      var cell = nextCellOfOrigin(origin, from);
      while (cell != null && cell.record.originSeq <= bound) {
        pending.add(cell.record);
        if (pending.length == maxCellsPerBatch) {
          batches.add(ChangeBatch(origin: origin, fromSeq: from, toSeq: cell.record.originSeq, cells: pending));
          from = cell.record.originSeq;
          pending = <CellRecord>[];
        }
        cell = nextCellOfOrigin(origin, cell.record.originSeq);
      }
      if (pending.isNotEmpty || from < bound) {
        batches.add(ChangeBatch(origin: origin, fromSeq: from, toSeq: bound, cells: pending));
      }
    }
    return batches;
  }

  /// Plain (unauthenticated) merge used by store-level tests; the session
  /// engine uses [applyRemote]. The receive time is taken from the HLC.
  @override
  bool applyBatch(ChangeBatch batch) {
    var changed = false;
    for (final remote in batch.cells) {
      _clock.receive(remote.clock);
      final current = _cell(remote.key);
      if (current == null || compareCellVersions(remote, current.record) > 0) {
        _put(StoredCell(remote, recordedAt: Hlc.wallOf(_clock.current)));
        changed = true;
      }
    }
    if (batch.toSeq > batch.fromSeq && advanceCursor(batch.origin, fromSeq: batch.fromSeq, toSeq: batch.toSeq)) {
      changed = true;
    }
    return changed;
  }

  // --- Sending ----------------------------------------------------------------

  /// The first stored cell of [origin] with a seq above [afterSeq].
  StoredCell? nextCellOfOrigin(String origin, int afterSeq) {
    final index = _byOrigin[origin];
    final seq = index?.firstKeyAfter(afterSeq);
    return seq == null ? null : index![seq];
  }

  /// The first superseded seq of [origin] above [afterSeq] with the key of the
  /// cell that replaced it (F5), or `null`.
  (int, CellKey)? nextSupersededOfOrigin(String origin, int afterSeq) {
    final index = _superseded[origin];
    final seq = index?.firstKeyAfter(afterSeq);
    return seq == null ? null : (seq, index![seq]!);
  }

  /// Removes the index entry of the superseded [seq] of [origin].
  void dropSupersededEntry(String origin, int seq) {
    final index = _superseded[origin];
    if (index == null) return;
    index.remove(seq);
    if (index.isEmpty) _superseded.remove(origin);
  }

  /// Adds an index entry without a supersession. For tests that need a stale
  /// entry; the engine records entries only through [_put], [applyRemote] and
  /// [dropSupersededHeld].
  @visibleForTesting
  void debugIndexSuperseded(String origin, int seq, CellKey key) => _recordSuperseded(origin, seq, key);

  /// Origins of which at least one cell is stored.
  Iterable<String> get cellOrigins => _byOrigin.keys;

  /// The first held envelope of [origin] with a seq above [afterSeq].
  HeldEnvelope? nextHeldOfOrigin(String origin, int afterSeq) {
    final index = _held[origin];
    final seq = index?.firstKeyAfter(afterSeq);
    return seq == null ? null : index![seq];
  }

  /// Own cells of the current origin with seq in `(fromSeq, toSeq]`.
  List<CellRecord> ownCellsInRange(int fromSeq, int toSeq) {
    final out = <CellRecord>[];
    var cell = nextCellOfOrigin(_origin.hex, fromSeq);
    while (cell != null && cell.record.originSeq <= toSeq) {
      out.add(cell.record);
      cell = nextCellOfOrigin(_origin.hex, cell.record.originSeq);
    }
    return out;
  }

  /// Persists an own manifest (`sync_origin_batch`, built at send time) and
  /// links the cells it covers.
  void attachOwnManifest(OriginManifest manifest) {
    if (manifest.origin != _origin) throw ArgumentError.value(manifest.origin, 'manifest', 'not the current origin');
    var cell = nextCellOfOrigin(_origin.hex, manifest.fromSeq);
    while (cell != null && cell.record.originSeq <= manifest.toSeq) {
      cell.manifest = manifest;
      cell = nextCellOfOrigin(_origin.hex, cell.record.originSeq);
    }
    if (manifest.toSeq > _ownSignedTo) _ownSignedTo = manifest.toSeq;
  }

  // --- Receiving ----------------------------------------------------------------

  /// Merges a verified, decrypted remote [change] authenticated by
  /// [manifest], received at local time [nowMs].
  ///
  /// The HLC observes the remote clock (D2); the version is stored only when
  /// it wins (FR-007, FR-013).
  ApplyOutcome applyRemote(Change change, OriginManifest manifest, {required int nowMs}) {
    if (applyFault?.call(change) ?? false) return ApplyOutcome.failed;
    final record = change.toCellRecord();
    _clock.receive(record.clock);
    final current = _cell(record.key);
    if (current == null || compareCellVersions(record, current.record) > 0) {
      _put(StoredCell(record, recordedAt: nowMs, manifest: manifest));
      return ApplyOutcome.applied;
    }
    _recordSupersededByStored(record.origin, record.originSeq, record.key);
    return ApplyOutcome.unchanged;
  }

  /// Records that a received version was committed (diagnostics).
  void logCommit(String origin, int seq) {
    final key = '$origin#$seq';
    commitLog[key] = (commitLog[key] ?? 0) + 1;
  }

  /// Advances the cursor of [origin] for a committed declared range (D15).
  /// The own current origin is never advanced by a peer.
  bool advanceCursor(String origin, {required int fromSeq, required int toSeq}) {
    if (origin == _origin.hex) return false;
    return _vector.advance(origin, fromSeq: fromSeq, toSeq: toSeq);
  }

  // --- Held envelopes -----------------------------------------------------------

  /// Every held envelope, by origin then seq.
  List<HeldEnvelope> get heldEnvelopes => [
        for (final origin in _held.keys.toList()..sort()) ..._held[origin]!.values,
      ];

  HeldEnvelope? heldAt(String origin, int seq) => _held[origin]?[seq];

  /// Stores [held]; an existing entry for the same `(origin, seq)` keeps its
  /// fail count.
  void putHeld(HeldEnvelope held) {
    final index = _held.putIfAbsent(held.origin, SplayTreeMap.new);
    final existing = index[held.seq];
    if (existing != null && existing.failCount > held.failCount) held.failCount = existing.failCount;
    index[held.seq] = held;
  }

  bool removeHeld(String origin, int seq) {
    final index = _held[origin];
    final removed = index?.remove(seq) != null;
    if (index != null && index.isEmpty) _held.remove(origin);
    return removed;
  }

  /// Whether a version at least as new as [held] is already stored (the
  /// entry then leaves the table, D15).
  bool isSuperseded(HeldEnvelope held) {
    final current = _cell(held.key);
    if (current == null) return false;
    // Same order as compareCellVersions: (hlc, node), then origin (smaller
    // wins), then seq; value and cause are sealed in the envelope and never
    // differ for one (origin, seq).
    final r = current.record;
    final e = held.envelope;
    final byVersion = Hlc.compareVersions(r.clock, r.node, e.hlc, e.node);
    if (byVersion != 0) return byVersion > 0;
    final byOrigin = e.origin.hex.compareTo(r.origin);
    if (byOrigin != 0) return byOrigin > 0;
    return r.originSeq >= e.originSeq;
  }

  /// Removes [held] because a newer version of its cell is stored (D15).
  void dropSupersededHeld(HeldEnvelope held) {
    removeHeld(held.origin, held.seq);
    _recordSupersededByStored(held.origin, held.seq, held.key);
  }

  // --- Origin registry -----------------------------------------------------------

  /// Stored origin registrations (`sync_origin`).
  List<OriginRegistration> get registrations => [for (final l in _registrations.values) ...l];

  /// Adds a verified registration row; returns `false` when already held.
  bool addRegistration(OriginRegistration row) {
    final list = _registrations.putIfAbsent(row.origin.hex, () => []);
    for (final r in list) {
      if (r.createdHlc == row.createdHlc && _sameBytes(r.memberPub, row.memberPub)) return false;
    }
    list.add(row);
    return true;
  }

  // --- Origin switch (D6b, D14) ------------------------------------------------------

  /// Step 2 of `switch_origin(reason)` (the DB transaction). The caller
  /// (the device) performs steps 1 and 3 on the sync ledger and registers
  /// [newOrigin] in `sync_origin`.
  ///
  /// * `restore`, `keyLost`: the old origin is sealed with cursor
  ///   `min(sentMark, highest retained seq)` (the mark term dropped when
  ///   [sentMark] is `null`; adopted cells do not count as held). Every
  ///   user-table cell without a manifest — a transport cut can leave a
  ///   marked batch undelivered — and every one above
  ///   [sentMark] move to [newOrigin] with fresh seqs, keeping `hlc`, `node`,
  ///   value and cause. `restore` raises the HLC to the max held `hlc` and to
  ///   [hlcFloor] (the ledger's `hlc_high`, F3). Never-sent security cells
  ///   stay on the sealed origin and are never sent (U11/rooted).
  /// * `localReset` (D14): user-table cells and held envelopes are deleted,
  ///   the whole vector is cleared; security cells stay, and those of the
  ///   old origin without a manifest (or above [sentMark]) are adopted.
  /// * `groupSwitch` (NB-1): security cells, registrations, held envelopes,
  ///   manifests and the vector are cleared; every user-table
  ///   cell is re-authored onto [newOrigin] (fresh seqs, same `hlc`/`node`).
  SwitchOriginOutcome switchOrigin({
    required OriginSwitchReason reason,
    required OriginId newOrigin,
    int? sentMark,
    int hlcFloor = 0,
  }) {
    if (newOrigin == _origin || _byOrigin.containsKey(newOrigin.hex) || _sealed.contains(newOrigin.hex)) {
      throw ArgumentError.value(newOrigin, 'newOrigin', 'origin already used');
    }
    final old = _origin;
    final oldHex = old.hex;
    final oldCells = List.of(_byOrigin[oldHex]?.values ?? const <StoredCell>[]);
    var sealedCursor = 0;
    var toMove = <StoredCell>[];
    var purged = 0;
    var securityLeftBehind = 0;
    var clearVector = false;
    switch (reason) {
      case OriginSwitchReason.restore || OriginSwitchReason.keyLost:
        // Never-sent security cells stay on the sealed origin; those without
        // a manifest can never be sent (those above the sent mark with one
        // are still served): re-keyed to a new origin a member row could be vouched for
        // by an origin it itself owns (U11/rooted).
        final neverSent = [
          for (final c in oldCells)
            if (_isNeverSent(c, sentMark)) c,
        ];
        securityLeftBehind =
            neverSent.where((c) => c.manifest == null && SecurityTables.contains(c.record.key.table)).length;
        toMove = [
          for (final c in neverSent)
            if (!SecurityTables.contains(c.record.key.table)) c,
        ];
        // Adopted cells leave the origin, so only retained ones count as held
        // (min(highest held seq, mark) of U11): after a rollback an adopted
        // cell may reuse a seq a peer still has to re-send.
        sealedCursor = oldCells.where((c) => !_isNeverSent(c, sentMark)).fold(0, (_, c) => c.record.originSeq);
        if (reason == OriginSwitchReason.restore) _clock.receive(math.max(_highestHeldHlc(), hlcFloor));
      case OriginSwitchReason.localReset:
        clearVector = true;
        for (final table in _tables.keys.toList()) {
          if (SecurityTables.contains(table)) continue;
          for (final pk in _tables[table]!.keys.toList()) {
            purged += _removeRow(RowRef(table, pk)).length;
          }
        }
        for (final h in heldEnvelopes) {
          if (!SecurityTables.contains(h.row.table)) removeHeld(h.origin, h.seq);
        }
        // Retained (security) cells of the old origin that no peer can hold
        // are adopted like any never-sent cell (D6b), else nobody could ever
        // serve them.
        toMove = [
          for (final c in _byOrigin[oldHex]?.values ?? const <StoredCell>[])
            if (_isNeverSent(c, sentMark)) c,
        ];
      case OriginSwitchReason.groupSwitch:
        clearVector = true;
        for (final table in SecurityTables.all) {
          for (final pk in _tables[table]?.keys.toList() ?? const <String>[]) {
            purged += _removeRow(RowRef(table, pk)).length;
          }
        }
        _held.clear();
        _registrations.clear();
        for (final table in _tables.keys) {
          for (final row in _tables[table]!.values) {
            for (final cell in row.values) {
              cell.manifest = null;
              toMove.add(cell);
            }
          }
        }
      case OriginSwitchReason.initial:
        throw ArgumentError.value(reason, 'reason', 'not a switch reason');
    }
    _pruneSuperseded();
    _sealed.add(oldHex);
    _origin = newOrigin;
    _nextSeq = 1;
    _ownSignedTo = 0;
    for (final cell in toMove) {
      final r = cell.record;
      // Same version moving to the new origin: not a supersession.
      _place(StoredCell(
        CellRecord(
          key: r.key,
          value: r.value,
          clock: r.clock,
          node: r.node,
          origin: newOrigin.hex,
          originSeq: _nextSeq++,
          cause: r.cause,
        ),
        recordedAt: cell.recordedAt,
      ));
    }
    if (clearVector) {
      _vector = VersionVector();
    } else {
      _vector = VersionVector({..._vector.toMap(), oldHex: sealedCursor});
    }
    return SwitchOriginOutcome(
      oldOrigin: old,
      newOrigin: newOrigin,
      sealedCursor: clearVector ? null : sealedCursor,
      moved: toMove.length,
      purged: purged,
      securityLeftBehind: securityLeftBehind,
    );
  }

  /// Whether no peer is known to hold [cell] of the sealed own origin:
  /// without a manifest, or above [sentMark] (D6b).
  bool _isNeverSent(StoredCell cell, int? sentMark) =>
      cell.manifest == null || (sentMark != null && cell.record.originSeq > sentMark);

  int _highestHeldHlc() => cells.fold(0, (max, c) => math.max(max, c.clock));

  /// The highest seq of [origin] among stored cells (applied versions), or
  /// 0. Self-extension of revocation cutoffs uses this (D7): held envelopes
  /// rejected above a cutoff must not extend it.
  int maxCellSeq(String origin) => _byOrigin[origin]?.lastKey() ?? 0;

  /// Highest seq of [origin] among stored winners and held envelopes (D7
  /// self-extension, card B.1): a device that holds an above-cutoff envelope
  /// without storing it still extends the cutoff, so its peers accept the
  /// envelope once the record reaches them.
  int maxKnownSeq(String origin) {
    var max = maxCellSeq(origin);
    for (final h in _held[origin]?.values ?? const <HeldEnvelope>[]) {
      if (h.seq > max) max = h.seq;
    }
    return max;
  }

  // --- Snapshot / restore -----------------------------------------------------------

  /// A deep copy of the whole store (the DB file).
  SyncStoreSnapshot snapshot() => SyncStoreSnapshot._(_clone());

  /// Replaces the whole state with [snapshot]'s (a DB restore). Fault hooks
  /// and diagnostics are kept.
  void restore(SyncStoreSnapshot snapshot) => _assign(snapshot._store._clone());

  SyncStore _clone() {
    final copy = SyncStore(memberId: _memberId, origin: _origin, initialHlc: _clock.current)
      .._nextSeq = _nextSeq
      .._ownSignedTo = _ownSignedTo
      .._vector = VersionVector(_vector.toMap())
      ..groupId = groupId;
    for (final table in _tables.entries) {
      for (final row in table.value.values) {
        for (final cell in row.values) {
          copy._place(cell._copy());
        }
      }
    }
    for (final e in _superseded.entries) {
      copy._superseded[e.key] = SplayTreeMap.of(e.value);
    }
    for (final h in heldEnvelopes) {
      copy.putHeld(h._copy());
    }
    for (final e in _registrations.entries) {
      copy._registrations[e.key] = List.of(e.value);
    }
    copy._sealed.addAll(_sealed);
    return copy;
  }

  void _assign(SyncStore other) {
    _memberId = other._memberId;
    _origin = other._origin;
    _nextSeq = other._nextSeq;
    _ownSignedTo = other._ownSignedTo;
    _clock = other._clock;
    _tables
      ..clear()
      ..addAll(other._tables);
    _byOrigin
      ..clear()
      ..addAll(other._byOrigin);
    _superseded
      ..clear()
      ..addAll(other._superseded);
    _vector = other._vector;
    _held
      ..clear()
      ..addAll(other._held);
    _registrations
      ..clear()
      ..addAll(other._registrations);
    _sealed
      ..clear()
      ..addAll(other._sealed);
    groupId = other.groupId;
  }

  // --- Diagnostics ----------------------------------------------------------------

  /// Number of stored clock rows.
  int get cellCount => _byOrigin.values.fold(0, (n, m) => n + m.length);

  /// Number of distinct manifests still referenced (orphans are unreachable).
  int get manifestCount {
    final set = Set<OriginManifest>.identity();
    for (final index in _byOrigin.values) {
      for (final c in index.values) {
        if (c.manifest != null) set.add(c.manifest!);
      }
    }
    for (final h in heldEnvelopes) {
      set.add(h.manifest);
    }
    return set.length;
  }

  @override
  String toString() => 'SyncStore($_memberId, origin $_origin, next_seq $_nextSeq, $cellCount cells, '
      '${heldEnvelopes.length} held)';

  // --- Internals --------------------------------------------------------------------

  StoredCell? _cell(CellKey key) => _tables[key.table]?[key.pk]?[key.col];

  RowCells? _lookup(RowRef row) {
    final cells = _tables[row.table]?[row.pk];
    return cells == null ? null : CellListRow([for (final c in cells.values) c.record]);
  }

  /// Stores [cell] as the winner of its key and remembers the version it
  /// replaces (F5).
  void _put(StoredCell cell) {
    final replaced = _cell(cell.record.key)?.record;
    final sameVersion =
        replaced != null && replaced.origin == cell.record.origin && replaced.originSeq == cell.record.originSeq;
    if (replaced != null && !sameVersion) _recordSuperseded(replaced.origin, replaced.originSeq, replaced.key);
    _place(cell);
  }

  /// Stores [cell] as the winner of its key without recording a supersession:
  /// for rebuilding a copy and for re-keying a version onto a new origin.
  void _place(StoredCell cell) {
    final key = cell.record.key;
    final row = _tables.putIfAbsent(key.table, () => {}).putIfAbsent(key.pk, () => {});
    final previous = row[key.col];
    if (previous != null) _unindex(previous);
    row[key.col] = cell;
    _byOrigin.putIfAbsent(cell.record.origin, SplayTreeMap.new)[cell.record.originSeq] = cell;
  }

  /// Indexes a version that lost to the stored winner of [key] without ever
  /// being stored, so a relay can still send the winner in its place (F5).
  /// The stored winner itself is never indexed (`index ∩ _byOrigin = ∅`).
  void _recordSupersededByStored(String origin, int seq, CellKey key) {
    final stored = _cell(key)?.record;
    if (stored == null || (stored.origin == origin && stored.originSeq == seq)) return;
    _recordSuperseded(origin, seq, key);
  }

  void _recordSuperseded(String origin, int seq, CellKey key) =>
      _superseded.putIfAbsent(origin, SplayTreeMap.new)[seq] = key;

  /// Drops the entries whose key lost its cell (rows removed by a switch).
  void _pruneSuperseded() {
    for (final index in _superseded.values) {
      index.removeWhere((_, key) => _cell(key) == null);
    }
    _superseded.removeWhere((_, index) => index.isEmpty);
  }

  /// Number of superseded versions indexed (`supersededIndexed`, F5).
  int get supersededIndexed => _superseded.values.fold(0, (n, index) => n + index.length);

  /// Debug-only invariant of the superseded index: it never shares a version
  /// with [_byOrigin] and every key has a current cell. Local state only; the
  /// simulation calls it after store mutations, release builds skip it.
  void assertSupersededIndexConsistent() {
    assert(() {
      for (final MapEntry(key: origin, value: index) in _superseded.entries) {
        for (final MapEntry(key: seq, value: key) in index.entries) {
          if (_byOrigin[origin]?.containsKey(seq) ?? false) {
            throw StateError('superseded $origin#$seq is also a stored winner');
          }
          if (_cell(key) == null) throw StateError('superseded $origin#$seq points at missing cell $key');
        }
      }
      return true;
    }());
  }

  void _unindex(StoredCell cell) {
    final index = _byOrigin[cell.record.origin];
    if (index == null) return;
    if (identical(index[cell.record.originSeq], cell)) index.remove(cell.record.originSeq);
    if (index.isEmpty) _byOrigin.remove(cell.record.origin);
  }

  List<StoredCell> _removeRow(RowRef ref) {
    final rows = _tables[ref.table];
    final row = rows?.remove(ref.pk);
    if (row == null) return const [];
    if (rows!.isEmpty) _tables.remove(ref.table);
    for (final cell in row.values) {
      _unindex(cell);
    }
    return row.values.toList();
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
