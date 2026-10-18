/// One device of the in-memory sync engine: store, sync ledger, key file
/// and membership, peer state, and the operations the app (and the
/// convergence simulator) drives: local writes, sessions, pairing, removal,
/// group switch, restore, key loss and replace-import (T12 part A).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../crypto/epoch.dart';
import '../crypto/primitives.dart';
import '../crypto/revocation.dart';
import '../membership/identity.dart';
import '../membership/membership.dart';
import '../membership/security_records.dart';
import '../model/change.dart';
import '../model/ids.dart';
import '../protocol/version.dart';
import '../store/sync_ledger.dart';
import '../store/replica_store.dart';
import '../store/sync_store.dart';
import 'session.dart';
import 'session_result.dart';
import 'transport.dart';

Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

/// Engine tuning and injectable behaviour.
final class SyncEngineConfig {
  const SyncEngineConfig({
    this.window = 4,
    this.maxBatchChanges = SyncLimits.maxBatchChanges,
    this.maxBatchBytes = 6 * 1024 * 1024,
    this.appVersion = '0.0.0',
    this.protocolVersion = syncProtocolVersion,
    this.minCompatible = minCompatibleProtocolVersion,
    this.sentMarkRetryDelays = const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)],
    this.delay = _realDelay,
  })  : assert(window >= 1),
        assert(maxBatchChanges >= 1 && maxBatchChanges <= SyncLimits.maxBatchChanges);

  /// Unacknowledged batches a sender keeps in flight (U9/PA-2).
  final int window;

  /// Changes per batch (D8 limit 1,000).
  final int maxBatchChanges;

  /// Estimated encoded bytes per batch (below the 8 MiB frame limit).
  final int maxBatchBytes;

  final String appVersion;
  final int protocolVersion;
  final int minCompatible;

  /// Waits between sent-mark write retries (D7: 1 s, 2 s, 4 s).
  final List<Duration> sentMarkRetryDelays;

  /// Sleeps for a retry delay; tests and the simulator inject an immediate
  /// one so no real timer runs.
  final Future<void> Function(Duration) delay;
}

/// What the D14 startup check did.
enum StartupAction { normal, keyLost, restore }

/// Per-peer sync state (`sync_peer_state_table`, FR-016, FR-017).
final class PeerState {
  PeerState(this.memberId);

  final String memberId;

  /// Local time of the last fully successful session (FR-016).
  int? lastCompleteLocal;

  /// Local time of the last session that finished its exchange.
  int? lastExchangeLocal;
  SessionResult? lastResult;

  /// Consecutive sessions in which an item of a row failed (FR-017).
  final Map<RowRef, int> consecutiveFailures = {};

  /// FR-017: some items fail in 3 consecutive sessions.
  bool itemsCannotBeApplied = false;

  /// Last peer wall clock (from its Hello) and its local receive time.
  int? lastPeerWall;
  int? lastPeerWallReceivedAt;

  @override
  String toString() => 'PeerState($memberId, last=${lastResult.runtimeType}, stuck=$itemsCannotBeApplied)';
}

/// Pairing refused (nothing changed on either device).
final class PairingException implements Exception {
  const PairingException(this.message);

  final String message;

  @override
  String toString() => 'PairingException: $message';
}

/// A DB-only snapshot (app restore, Android Auto Backup, file copy).
final class DeviceDbSnapshot {
  DeviceDbSnapshot._(this.store);

  final SyncStoreSnapshot store;
}

/// A snapshot of the app data directory: DB and key file. The sync ledger
/// lives outside it (U11) and is not part of the snapshot.
final class DirectorySnapshot {
  DirectorySnapshot._(this.store, this.keyFile, this.keyFilePresent);

  final SyncStoreSnapshot store;
  final KeyFileSnapshot keyFile;
  final bool keyFilePresent;
}

/// The results of both sides of one session.
final class SessionPair {
  const SessionPair(this.initiator, this.responder, {this.retried = false});

  final SessionResult initiator;
  final SessionResult responder;

  /// Whether the session was retried after a restore was detected (D15).
  final bool retried;

  bool get bothComplete => initiator.isComplete && responder.isComplete;

  @override
  String toString() => 'SessionPair($initiator | $responder${retried ? ', retried' : ''})';
}

/// One device (see the library documentation).
final class SyncDevice {
  SyncDevice._({
    required this.name,
    required this.ids,
    required this.clock,
    required this.config,
    required this.store,
    required this.ledger,
    required this.membership,
  });

  /// Creates a fresh, unpaired device with a new identity and origin.
  static Future<SyncDevice> create({
    required String name,
    required int Function() clock,
    SyncIdSource? ids,
    SyncEngineConfig config = const SyncEngineConfig(),
    SyncLedger? ledger,
  }) async {
    final source = ids ?? SyncIdSource();
    final identity = await DeviceIdentity.generate(source, name: name);
    final origin = source.origin();
    final deviceLedger = ledger ?? InMemorySyncLedger();
    await deviceLedger.append(
      OriginEntry(origin: origin, state: OriginEntryState.committed, reason: OriginSwitchReason.initial),
    );
    return SyncDevice._(
      name: name,
      ids: source,
      clock: clock,
      config: config,
      store: SyncStore(memberId: identity.memberId, origin: origin),
      ledger: deviceLedger,
      membership: Membership(identity, retainedRevocations: () => deviceLedger.revocations),
    );
  }

  final String name;
  final SyncIdSource ids;

  /// Local wall clock in ms (injectable; the simulator applies offsets).
  int Function() clock;
  final SyncEngineConfig config;
  final SyncStore store;

  /// Injected, independent of the DB and the key file (U11, F4).
  final SyncLedger ledger;
  final Membership membership;

  /// Whether the key file exists (a lost key file triggers D14 rule 2).
  bool keyFilePresent = true;

  /// Set after a key loss, or when an origin switch left never-sent security
  /// rows behind (U11/rooted), until the device is paired again (D14).
  bool needsRepairing = false;

  /// Local time of the last session with any member that finished its
  /// exchange (status display).
  int? lastSuccessfulSyncLocal;

  final Map<String, PeerState> peers = {};

  /// Running sessions by peer member id (one per peer pair, D15).
  final Map<String, SyncSession> activeSessions = {};

  String get memberId => membership.memberId;
  int now() => clock();

  PeerState peerState(String memberId) => peers.putIfAbsent(memberId, () => PeerState(memberId));

  // --- Local writes -------------------------------------------------------------

  /// A local edit (captured with a fresh HLC tick and own seq, D3).
  ///
  /// Card A-1: every write marks the written watermark dirty; it is persisted
  /// at the next session start, at [flushWrittenWatermark] (app pause or
  /// shutdown) and at snapshot time, so a data-dir restore below unsent
  /// writes is detectable without waiting for a backup.
  CellRecord write(CellKey key, Object? value, {RowRef? cause}) {
    _watermarkDirty = true;
    return store.writeLocal(key, value, nowMs: now(), cause: cause);
  }

  /// Persists the written watermark now (card A-1). Idempotent; returns
  /// whether a write happened. A ledger write failure is swallowed here (the
  /// mark stays dirty and the next call retries): unlike the sent mark this
  /// is best-effort bookkeeping ahead of a *possible* restore, not a
  /// durability gate for data already handed to the transport.
  Future<bool> flushWrittenWatermark() async {
    if (!_watermarkDirty) return false;
    final origin = store.localOrigin;
    if (!ledger.isReadable || ledger.entryOf(origin) == null) return false;
    try {
      await ledger.persistWrittenWatermark(origin, store.nextSeq, store.hlc);
    } on SyncLedgerWriteException {
      return false;
    }
    _watermarkDirty = false;
    return true;
  }

  bool _watermarkDirty = false;

  /// Soft-deletes [row]: its `~` cell gets `deleted_date = now` and, for a
  /// cascaded child, the [cause] (D3, D5b).
  CellRecord delete(RowRef row, {RowRef? cause}) =>
      write(CellKey(row.table, row.pk, CellKey.existenceCol), now(), cause: cause);

  /// Deletes [parent] and cascades to [children] with `cause = parent`.
  void cascadeDelete(RowRef parent, Iterable<RowRef> children) {
    delete(parent);
    for (final child in children) {
      delete(child, cause: parent);
    }
  }

  // --- Sessions -----------------------------------------------------------------

  /// Runs a session as initiator towards [peerMemberId].
  Future<SessionResult> initiate(
    ISyncTransport transport, {
    required String peerMemberId,
    SessionHooks hooks = const SessionHooks(),
  }) =>
      SyncSession(this, transport, initiator: true, expectedPeer: peerMemberId, hooks: hooks).run();

  /// Serves an incoming session.
  Future<SessionResult> respond(ISyncTransport transport, {SessionHooks hooks = const SessionHooks()}) =>
      SyncSession(this, transport, initiator: false, hooks: hooks).run();

  /// Runs one session between [a] (initiator) and [b] over a fresh
  /// in-memory link with [faults]. When a side detects that its DB is behind
  /// (D15 peer-cursor check) it switches origin and the session is retried
  /// once without faults.
  static Future<SessionPair> syncPair(
    SyncDevice a,
    SyncDevice b, {
    TransportFaults faults = TransportFaults.none,
    SessionHooks hooksA = const SessionHooks(),
    SessionHooks hooksB = const SessionHooks(),
    TransportTrace? trace,
    bool retryAfterRestore = true,
  }) async {
    var pair = await _once(a, b, faults, hooksA, hooksB, trace);
    bool restored(SessionResult r) => r is SessionFailed && r.category == SessionFailure.restoreDetected;
    if (retryAfterRestore && (restored(pair.initiator) || restored(pair.responder))) {
      final again = await _once(a, b, TransportFaults.none, hooksA, hooksB, trace);
      pair = SessionPair(again.initiator, again.responder, retried: true);
    }
    return pair;
  }

  static Future<SessionPair> _once(
    SyncDevice a,
    SyncDevice b,
    TransportFaults faults,
    SessionHooks hooksA,
    SessionHooks hooksB,
    TransportTrace? trace,
  ) async {
    final (ta, tb) = InMemoryTransport.pair(faults: faults, trace: trace);
    final results = await Future.wait([
      a.initiate(ta, peerMemberId: b.memberId, hooks: hooksA),
      b.respond(tb, hooks: hooksB),
    ]);
    return SessionPair(results[0], results[1]);
  }

  // --- Membership -----------------------------------------------------------------

  /// Pairs [joiner] into [inviter]'s group (direct in-memory handover; the
  /// QR/SAS flows are T20/T23). Creates the group on the inviter's first
  /// pairing. Joining from another group with other non-revoked members
  /// requires [confirmGroupSwitch] and runs `switch_origin(group_switch)`
  /// (NB-1); otherwise [PairingException] and nothing changes.
  static Future<void> pair({
    required SyncDevice inviter,
    required SyncDevice joiner,
    bool confirmGroupSwitch = false,
  }) async {
    if (identical(inviter, joiner)) throw ArgumentError('a device cannot pair with itself');
    final im = inviter.membership;
    final jm = joiner.membership;
    if (im.removed) throw const PairingException('the inviter was removed from its group');
    if (im.isRevokedEd(jm.identity.ed25519Pub)) {
      throw const PairingException('a removed device must pair again with a fresh identity');
    }
    if (!im.hasGroup) await inviter._createGroup();
    final g = im.groupId!;
    final joinerGroup = jm.groupId ?? joiner.store.groupId;
    if (joinerGroup != null && joinerGroup != g) {
      final hasOthers = jm.hasGroup && !jm.removed && jm.activeMembers.any((m) => m.memberId != jm.memberId);
      if (hasOthers && !confirmGroupSwitch) {
        throw const PairingException('joining leaves the current group; confirmation required');
      }
      await joiner._leaveForGroupSwitch();
    }
    // The signed records behind every flagged anchor travel with the flags,
    // so the joiner never verifies a flagged member with no cutoff
    // (U11/Efe-2); they reach its ledger before it joins.
    await joiner.ledger.persistRevocations(inviter.ledger.revocations);
    final keys = <EpochId, Uint8List>{
      for (final e in im.keyring.epochs) e: Uint8List.fromList(im.keyring.keyFor(e)!),
    };
    try {
      jm.joinGroup(g, epochKeys: keys, anchors: im.anchors, revokedAnchors: im.revokedAnchorIds);
    } finally {
      for (final k in keys.values) {
        zeroize(k);
      }
    }
    joiner.store.groupId = g;
    joiner.needsRepairing = false;
    inviter._writeSecurity(memberCellKey(jm.memberId), jm.identity.entry(addedBy: inviter.memberId).encode());
    for (final e in keys.keys.toList()..sort()) {
      final grant = EpochGrant(e, jm.identity.ed25519Pub);
      inviter._writeSecurity(epochGrantCellKey(grant), encodeEpochGrant(grant));
    }
    final row = await jm.registerOrigin(joiner.store.localOrigin, joiner.store);
    await im.mergeRegistrations([row], inviter.store);
    await jm.mergeRegistrations(inviter.store.registrations, joiner.store);
    await im.rebuild(inviter.store);
    await jm.rebuild(joiner.store);
  }

  Future<void> _createGroup() async {
    final g = ids.group();
    membership.createGroup(g);
    final epoch = await _createEpoch();
    store.groupId = g;
    _writeSecurity(memberCellKey(memberId), membership.identity.entry(addedBy: memberId).encode());
    final grant = EpochGrant(epoch, membership.identity.ed25519Pub);
    _writeSecurity(epochGrantCellKey(grant), encodeEpochGrant(grant));
    await membership.registerOrigin(store.localOrigin, store);
    await membership.rebuild(store);
  }

  Future<void> _leaveForGroupSwitch() async {
    await switchOrigin(OriginSwitchReason.groupSwitch);
    membership.leaveGroup();
    await _clearLedgerGroupState();
    store.groupId = null;
    peers.clear();
  }

  /// Removes member [memberId] (FR-026): a signed revocation listing every
  /// origin registered to it with the max seq held here, then an epoch
  /// rotation (D7).
  Future<void> removeMember(String memberId) async {
    final m = membership;
    final g = m.groupId ?? (throw StateError('not in a group'));
    if (memberId == this.memberId) throw ArgumentError('use leave/reset to remove this device');
    final entry = m.memberById(memberId) ?? (throw ArgumentError.value(memberId, 'memberId', 'unknown member'));
    final registry = m.registry!;
    final cutoffs = {
      for (final o in registry.originsOf(entry.ed25519Pub)) o: math.max(store.cursorOf(o.hex), store.maxCellSeq(o.hex)),
    };
    final record = await RevocationRecord.sign(
      groupId: g,
      revokedPub: entry.ed25519Pub,
      revoker: m.identity.ed25519,
      cutoffs: cutoffs,
    );
    await _commitOwnRevocation(record);
    await _rotate();
    await m.rebuild(store);
  }

  /// Membership upkeep after a session (D7): revocation self-extension and
  /// the re-rotation rule. Returns whether anything was written.
  Future<bool> maintainMembership() async {
    final m = membership;
    final g = m.groupId;
    final revocations = m.directoryRevocations;
    final registry = m.registry;
    if (g == null || m.removed || revocations == null || registry == null) return false;
    var wrote = false;
    final extension = revocations.selfExtension(registry, (o) => store.maxKnownSeq(o.hex));
    for (final e in extension.entries) {
      final record = await RevocationRecord.sign(
        groupId: g,
        revokedPub: e.key,
        revoker: m.identity.ed25519,
        cutoffs: e.value,
      );
      await _commitOwnRevocation(record);
      wrote = true;
    }
    if (wrote) await m.rebuild(store);
    if (m.mustRotate) {
      await _rotate();
      wrote = true;
      await m.rebuild(store);
    }
    return wrote;
  }

  Future<void> _rotate() async {
    final epoch = await _createEpoch();
    final grant = EpochGrant(epoch, membership.identity.ed25519Pub);
    _writeSecurity(epochGrantCellKey(grant), encodeEpochGrant(grant));
  }

  /// Creates this device's next epoch. The new counter reaches the ledger
  /// before the key exists, so a crash or a later key-file rollback never
  /// lets the counter be created twice (U11, G1).
  Future<EpochId> _createEpoch() async {
    final keyring = membership.keyring;
    final counterFloor = ledger.epochCounterHigh;
    final next = keyring.nextEpoch(memberId, counterFloor: counterFloor);
    await ledger.persistEpochCounterHigh(next.counter);
    return keyring.rotate(memberId, counterFloor: counterFloor);
  }

  /// Writes this device's own revocation [record]: the ledger first, then the
  /// DB cell, like `epoch_counter_high` (U11/Efe-1). A ledger write failure
  /// throws [SyncLedgerWriteException] before anything is committed.
  Future<void> _commitOwnRevocation(RevocationRecord record) async {
    final recordBytes = encodeRevocationRecord(record);
    final carrierOrigin = store.localOrigin;
    final carrierSeq = store.nextSeq;
    await ledger.persistRevocations([_ledgerRevocation(record, recordBytes, carrierOrigin, carrierSeq)]);
    final written = store.writeLocal(revocationCellKey(record), recordBytes, nowMs: now());
    if (written.origin != carrierOrigin.hex || written.originSeq != carrierSeq) {
      throw StateError('a local write interleaved with a revocation commit');
    }
  }

  /// Persists the signed revocation records among received [changes] to the
  /// ledger; awaited before they are committed to the DB (U11/Efe-1). Throws
  /// [SyncLedgerWriteException] on failure.
  Future<void> retainReceivedRevocations(Iterable<Change> changes) async {
    final retained = [
      for (final change in changes)
        if (_receivedRevocation(change) case final revocation?) revocation,
    ];
    if (retained.isNotEmpty) await ledger.persistRevocations(retained);
  }

  /// The ledger form of [change] when it carries a revocation record, else
  /// `null`. A malformed record is not kept: [Membership.rebuild] would
  /// ignore it as well.
  LedgerRevocation? _receivedRevocation(Change change) {
    final value = change.value;
    if (change.tbl != SecurityTables.revocation || value is! BytesValue) return null;
    final RevocationRecord record;
    try {
      record = decodeRevocationRecord(value.value);
    } on Object {
      return null;
    }
    return _ledgerRevocation(record, value.value, change.origin, change.originSeq);
  }

  LedgerRevocation _ledgerRevocation(
    RevocationRecord record,
    Uint8List recordBytes,
    OriginId carrierOrigin,
    int carrierSeq,
  ) =>
      LedgerRevocation(
        recordBytes: recordBytes,
        revokerEntryBytes: membership.memberByEd25519(record.revokerPub)?.encode(),
        carrierOrigin: carrierOrigin,
        carrierSeq: carrierSeq,
      );

  /// Drops the ledger state that belongs to the group being exited (group
  /// switch, key loss): the epoch counter and the revocation records.
  Future<void> _clearLedgerGroupState() async {
    await ledger.resetEpochCounterHigh();
    await ledger.clearRevocations();
  }

  /// Writes a grant row recording that [grant]'s member received the key.
  void recordGrant(EpochGrant grant) => _writeSecurity(epochGrantCellKey(grant), encodeEpochGrant(grant));

  void _writeSecurity(CellKey key, Uint8List value) => store.writeLocal(key, value, nowMs: now());

  // --- Origin switch, restore, key loss, local reset (D6b, D14) ------------------------

  /// `switch_origin(reason)` (D6b steps 1–3). [sentMark] is the old origin's
  /// `max_sent_seq` (`null` = unknown).
  Future<SwitchOriginOutcome> switchOrigin(OriginSwitchReason reason, {int? sentMark}) async {
    final newOrigin = ids.origin();
    await ledger.append(OriginEntry(origin: newOrigin, state: OriginEntryState.pending, reason: reason));
    final outcome = store.switchOrigin(
      reason: reason,
      newOrigin: newOrigin,
      sentMark: sentMark,
      hlcFloor: ledger.hlcFloor,
    );
    // Security rows this device authored but never sent stay behind (U11/rooted):
    // its peers cannot learn them, so it must be paired again.
    if (outcome.securityLeftBehind > 0) needsRepairing = true;
    if (membership.hasGroup && reason != OriginSwitchReason.groupSwitch) {
      await membership.registerOrigin(newOrigin, store);
    }
    await ledger.commit(newOrigin);
    return outcome;
  }

  /// The D15 whole-directory-restore path: the peer holds [peerCursor] for
  /// this device's origin, above `next_seq − 1`.
  Future<SwitchOriginOutcome> switchOriginAfterPeerCursor(int peerCursor) {
    final mark = ledger.entryOf(store.localOrigin)?.maxSentSeq ?? 0;
    return switchOrigin(OriginSwitchReason.restore, sentMark: math.max(mark, peerCursor));
  }

  /// The D14 startup check (first match wins): key loss, pending-switch
  /// recovery, DB behind the sync ledger, otherwise normal. Persists a dirty
  /// written watermark first (card A-1) so the seqs of the previous run's
  /// last unsent writes are remembered before anything new is authored.
  Future<StartupAction> startupCheck() async {
    await flushWrittenWatermark();
    if (!keyFilePresent || store.memberId != membership.memberId) {
      await _becomeKeyLost();
      return StartupAction.keyLost;
    }
    final latest = ledger.latest;
    if (latest != null && latest.state == OriginEntryState.pending) {
      if (latest.origin == store.localOrigin) {
        await ledger.commit(latest.origin);
      } else {
        await ledger.drop(latest.origin);
      }
      return startupCheck();
    }
    final committed = ledger.latestCommitted;
    final entry = ledger.isReadable ? ledger.entryOf(store.localOrigin) : null;
    final mark = entry?.maxSentSeq;
    // Card A: the written watermark covers writes that never left the device,
    // so a data-dir restore below them switches the origin instead of
    // silently re-authoring those seqs under new content. Strict `<`: a DB
    // matching the watermark is a clean full rollback, not a reuse.
    final writtenHigh = entry?.nextSeqHigh ?? 0;
    if (!ledger.isReadable ||
        committed == null ||
        committed.origin != store.localOrigin ||
        store.nextSeq - 1 < (mark ?? 0) ||
        store.nextSeq < writtenHigh) {
      await switchOrigin(OriginSwitchReason.restore, sentMark: mark);
      return StartupAction.restore;
    }
    return StartupAction.normal;
  }

  Future<void> _becomeKeyLost() async {
    final mark = ledger.isReadable ? ledger.entryOf(store.localOrigin)?.maxSentSeq : null;
    final identity = await DeviceIdentity.generate(ids, name: name);
    membership.replaceIdentity(identity);
    await _clearLedgerGroupState();
    keyFilePresent = true;
    needsRepairing = true;
    peers.clear();
    store.memberId = identity.memberId;
    await switchOrigin(OriginSwitchReason.keyLost, sentMark: mark);
    await membership.reload(store);
  }

  /// A copy of the DB alone. Persists the written watermark first (card A):
  /// everything the device authored so far, sent or not, must never be
  /// re-authored after a restore below it.
  Future<DeviceDbSnapshot> snapshotDb() async {
    final snapshot = DeviceDbSnapshot._(store.snapshot());
    await _persistSnapshotWatermark();
    return snapshot;
  }

  /// Restores the DB alone (key file and sync ledger stay current), then runs
  /// the startup check.
  Future<StartupAction> restoreDb(DeviceDbSnapshot snapshot) async {
    store.restore(snapshot.store);
    await membership.reload(store);
    return startupCheck();
  }

  /// A copy of the DB and key file (the app data directory; the ledger is
  /// outside it, U11).
  Future<DirectorySnapshot> snapshotDirectory() async {
    final snapshot = DirectorySnapshot._(store.snapshot(), membership.snapshotKeyFile(), keyFilePresent);
    await _persistSnapshotWatermark();
    return snapshot;
  }

  /// Card A-3: the copy is taken first, so a write racing the snapshot can
  /// only raise the watermark above the copy's `nextSeq` (harmless — the
  /// origin still switches on a restore below the copy), never lower it
  /// below a seq the copy actually contains.
  Future<void> _persistSnapshotWatermark() async {
    _watermarkDirty = false;
    final origin = store.localOrigin;
    if (ledger.isReadable && ledger.entryOf(origin) != null) {
      try {
        await ledger.persistWrittenWatermark(origin, store.nextSeq, store.hlc);
      } on SyncLedgerWriteException {
        _watermarkDirty = true;
      }
    }
  }

  /// Restores the app data directory (DB and key file); the sync ledger stays
  /// current, so the startup check finds the DB behind it and runs
  /// `switch_origin(restore)` (D14 rule 4). A full rollback including the
  /// ledger is undetectable here (U11 accepted residual risk); a test
  /// simulates it by restoring its own ledger copy first.
  Future<StartupAction> restoreDirectory(DirectorySnapshot snapshot) async {
    store.restore(snapshot.store);
    await membership.restoreKeyFile(snapshot.keyFile);
    keyFilePresent = snapshot.keyFilePresent;
    peers.clear();
    await membership.reload(store);
    return startupCheck();
  }

  /// Loses the key file (optionally also the sync ledger, and optionally
  /// with the DB replaced by [oldDb]), then runs the startup check: a new
  /// identity, `switch_origin(key_lost)` and "needs re-pairing" (D14 rule 2).
  Future<StartupAction> loseKeyFile({DeviceDbSnapshot? oldDb, bool loseLedger = false}) async {
    keyFilePresent = false;
    if (loseLedger) await ledger.deleteAll();
    if (oldDb != null) store.restore(oldDb.store);
    return startupCheck();
  }

  /// Replace-import (U4, D14 `local_reset`): user data and the whole vector
  /// are cleared under a new origin, then [cells] are written as fresh local
  /// edits. Security rows stay.
  Future<void> replaceImport(Iterable<(CellKey, Object?)> cells) async {
    final mark = ledger.isReadable ? ledger.entryOf(store.localOrigin)?.maxSentSeq : null;
    await switchOrigin(OriginSwitchReason.localReset, sentMark: mark);
    for (final (key, value) in cells) {
      write(key, value);
    }
  }

  @override
  String toString() => 'SyncDevice($name, $memberId)';
}
