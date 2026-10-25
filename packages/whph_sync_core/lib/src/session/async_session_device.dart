/// The device surface `AsyncSyncSession` runs against, and its in-memory
/// implementation over a [SyncDevice] (T22b). The in-memory adapter lets the
/// simulator and the package tests drive the async engine against the proven
/// in-memory semantics.
library;

import 'dart:async';

import '../crypto/epoch.dart';
import '../membership/membership.dart';
import '../model/change.dart';
import '../model/manifest.dart';
import '../model/ids.dart';
import '../protocol/messages.dart';
import '../store/async_sync_store_port.dart';
import '../store/replica_store.dart';
import '../store/sync_ledger.dart';
import '../store/sync_store.dart';
import 'async_session.dart';
import 'session.dart';
import 'session_result.dart';
import 'sync_device.dart';
import 'transport.dart';

/// What an async session needs from its device: identity, membership, ledger,
/// peer bookkeeping and the store-touching upkeep operations.
abstract interface class AsyncSessionDevice {
  String get name;
  String get memberId;
  int now();
  SyncEngineConfig get config;
  Membership get membership;
  SyncLedger get ledger;
  AsyncSyncStorePort get store;

  /// Running sessions by peer member id (one per peer pair, D15).
  Map<String, AsyncSyncSession> get activeSessions;

  PeerState peerState(String memberId);

  int? get lastSuccessfulSyncLocal;
  set lastSuccessfulSyncLocal(int? value);

  /// Swallowed written-watermark flush failures (card A-1).
  int get watermarkFlushFailures;

  Future<bool> flushWrittenWatermark();

  /// Writes a grant row recording that the grant's member received the key.
  Future<void> recordGrant(EpochGrant grant);

  /// Persists the signed revocation records among [changes] to the ledger
  /// before they are committed (U11/Efe-1); throws [SyncLedgerWriteException].
  Future<void> retainReceivedRevocations(Iterable<Change> changes);

  /// Membership upkeep after a session (D7); returns whether it wrote.
  Future<bool> maintainMembership();

  /// D15: this DB is behind what a peer holds of its origin.
  Future<void> switchOriginAfterPeerCursor(int peerCursor);
}

/// [SyncStore] seen through the async port; every call completes immediately.
final class InMemoryAsyncSyncStore implements AsyncSyncStorePort {
  InMemoryAsyncSyncStore(this.store);

  final SyncStore store;

  @override
  Future<OriginId> localOrigin() async => store.localOrigin;

  @override
  Future<int> nextSeq() async => store.nextSeq;

  @override
  Future<int> hlc() async => store.hlc;

  @override
  Future<int> ownSignedTo() async => store.ownSignedTo;

  @override
  Future<Map<String, int>> vector() async => store.vector;

  @override
  Future<List<OriginRegistration>> registrations() async => store.registrations;

  @override
  Future<StoredCell?> storedCell(CellKey key) async => store.storedCell(key);

  @override
  Future<StoredCell?> nextCellOfOrigin(String origin, int afterSeq) async => store.nextCellOfOrigin(origin, afterSeq);

  @override
  Future<OriginScanEntry> nextOfOrigin(String origin, int afterSeq) async => (
        cell: store.nextCellOfOrigin(origin, afterSeq),
        held: store.nextHeldOfOrigin(origin, afterSeq),
        superseded: store.nextSupersededOfOrigin(origin, afterSeq),
      );

  @override
  Future<List<String>> cellOrigins() async => store.cellOrigins.toList();

  @override
  Future<List<CellRecord>> ownCellsInRange(int fromSeq, int toSeq) async => store.ownCellsInRange(fromSeq, toSeq);

  @override
  Future<void> attachOwnManifest(OriginManifest manifest) async => store.attachOwnManifest(manifest);

  @override
  Future<(int, CellKey)?> nextSupersededOfOrigin(String origin, int afterSeq) async =>
      store.nextSupersededOfOrigin(origin, afterSeq);

  @override
  Future<void> dropSupersededEntry(String origin, int seq) async => store.dropSupersededEntry(origin, seq);

  @override
  Future<int> supersededIndexed() async => store.supersededIndexed;

  @override
  Future<ApplyOutcome> applyRemote(Change change, OriginManifest manifest, {required int nowMs}) async =>
      store.applyRemote(change, manifest, nowMs: nowMs);

  @override
  Future<bool> advanceCursor(String origin, {required int fromSeq, required int toSeq}) async =>
      store.advanceCursor(origin, fromSeq: fromSeq, toSeq: toSeq);

  @override
  Future<void> logCommit(String origin, int seq) async => store.logCommit(origin, seq);

  @override
  Future<T> inTransaction<T>(Future<T> Function() body) => body();

  @override
  Future<List<HeldEnvelope>> heldEnvelopes() async => store.heldEnvelopes;

  @override
  Future<HeldEnvelope?> heldAt(String origin, int seq) async => store.heldAt(origin, seq);

  @override
  Future<void> putHeld(HeldEnvelope held) async => store.putHeld(held);

  @override
  Future<bool> removeHeld(String origin, int seq) async => store.removeHeld(origin, seq);

  @override
  Future<bool> isSuperseded(HeldEnvelope held) async => store.isSuperseded(held);

  @override
  Future<void> dropSupersededHeld(HeldEnvelope held) async => store.dropSupersededHeld(held);

  @override
  Future<SyncStore> securityProjection() async => store;

  @override
  Future<void> persistRegistrations(Iterable<OriginRegistration> rows) async => rows.forEach(store.addRegistration);
}

/// A [SyncDevice] driven through the async engine.
final class InMemoryAsyncSessionDevice implements AsyncSessionDevice {
  InMemoryAsyncSessionDevice(this.device) : store = InMemoryAsyncSyncStore(device.store);

  final SyncDevice device;

  @override
  final InMemoryAsyncSyncStore store;

  @override
  final Map<String, AsyncSyncSession> activeSessions = {};

  @override
  String get name => device.name;

  @override
  String get memberId => device.memberId;

  @override
  int now() => device.now();

  @override
  SyncEngineConfig get config => device.config;

  @override
  Membership get membership => device.membership;

  @override
  SyncLedger get ledger => device.ledger;

  @override
  PeerState peerState(String memberId) => device.peerState(memberId);

  @override
  int? get lastSuccessfulSyncLocal => device.lastSuccessfulSyncLocal;

  @override
  set lastSuccessfulSyncLocal(int? value) => device.lastSuccessfulSyncLocal = value;

  @override
  int get watermarkFlushFailures => device.watermarkFlushFailures;

  @override
  Future<bool> flushWrittenWatermark() => device.flushWrittenWatermark();

  @override
  Future<void> recordGrant(EpochGrant grant) async => device.recordGrant(grant);

  @override
  Future<void> retainReceivedRevocations(Iterable<Change> changes) => device.retainReceivedRevocations(changes);

  @override
  Future<bool> maintainMembership() => device.maintainMembership();

  @override
  Future<void> switchOriginAfterPeerCursor(int peerCursor) => device.switchOriginAfterPeerCursor(peerCursor);

  /// Runs a session as initiator towards [peerMemberId].
  Future<SessionResult> initiate(
    ISyncTransport transport, {
    required String peerMemberId,
    SessionHooks hooks = const SessionHooks(),
  }) =>
      AsyncSyncSession(this, transport, initiator: true, expectedPeer: peerMemberId, hooks: hooks).run();

  /// Serves an incoming session.
  Future<SessionResult> respond(ISyncTransport transport, {SessionHooks hooks = const SessionHooks()}) =>
      AsyncSyncSession(this, transport, initiator: false, hooks: hooks).run();

  /// [SyncDevice.syncPair] through the async engine: one session between [a]
  /// (initiator) and [b], retried once without faults after a detected
  /// restore (D15).
  static Future<SessionPair> syncPair(
    InMemoryAsyncSessionDevice a,
    InMemoryAsyncSessionDevice b, {
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
    InMemoryAsyncSessionDevice a,
    InMemoryAsyncSessionDevice b,
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
}
