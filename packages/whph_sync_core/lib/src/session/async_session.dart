/// The asynchronous sync session engine (T22b): the same protocol, state
/// machine and U11 behaviours as [SyncSession] (see its library documentation
/// for the flow), run over an [AsyncSyncStorePort] so a database-backed store
/// can serve it. Pure decision and batching logic is shared through
/// `session_support.dart`; the received-batch commit runs inside one store
/// transaction.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../crypto/envelope.dart';
import '../crypto/epoch.dart';
import '../crypto/manifest_signer.dart';
import '../crypto/primitives.dart';
import '../model/change.dart';
import '../model/envelope.dart';
import '../model/ids.dart';
import '../model/manifest.dart';
import '../protocol/errors.dart';
import '../protocol/messages.dart';
import '../protocol/version.dart';
import '../store/async_sync_store_port.dart';
import '../store/sync_ledger.dart';
import '../store/replica_store.dart';
import '../store/sync_store.dart';
import 'relay_winner.dart';
import 'secure_channel.dart';
import 'session_result.dart';
import 'session_support.dart';
import 'async_session_device.dart';
import 'session.dart' show SessionHooks;
import 'transport.dart';

/// One side of one sync session (see the library documentation).
final class AsyncSyncSession {
  AsyncSyncSession(this.device, this._transport, {required this.initiator, this.expectedPeer, required this.hooks});

  final AsyncSessionDevice device;
  final ISyncTransport _transport;
  final bool initiator;
  final String? expectedPeer;
  final SessionHooks hooks;
  final SessionStats stats = SessionStats();

  SecureChannel? _channel;
  String? _peerId;
  Uint8List? _peerEd;
  Object? _failure;
  final Completer<void> _failed = Completer();

  // Exchange state.
  VectorExchange? _peerVx;
  final Completer<VectorExchange> _peerVxReady = Completer();
  Map<String, int> _peerVector = const {};
  Map<String, int>? _snapshot;
  bool _registryReceived = false;
  bool _handoverReceived = false;

  // Pipelined writer.
  final Set<int> _unacked = {};
  Completer<void>? _ackSignal;
  int _nextBatchId = 0;
  int? _endMarkerId;
  final Completer<void> _endAcked = Completer();
  bool _peerEnded = false;
  bool _storageError = false;
  late NonceSource _nonces;

  // FR-017 bookkeeping.
  final Set<RowRef> _failedRows = {};

  AsyncSyncStorePort get _store => device.store;

  /// Runs the session to its end and returns this side's result.
  Future<SessionResult> run() async {
    final m = device.membership;
    if (m.removed) return _early(SessionFailure.removedFromGroup);
    if (!m.hasGroup || m.keyring.epochs.isEmpty) return _early(SessionFailure.notPaired);
    if (initiator) {
      final peer = expectedPeer!;
      if (device.activeSessions.containsKey(peer)) return _early(SessionFailure.busy, peer: peer);
      device.activeSessions[peer] = this;
    }
    try {
      // Card A-1: remember every seq authored so far before this session
      // moves data, and again when it ends.
      await _flushWatermark();
      return await _run();
    } catch (e) {
      _failure ??= e;
      await _channel?.abort();
      await _transport.close();
      final failure = _failure!;
      if (failure is SessionAbort && failure.category == SessionFailure.restoreDetected) {
        // D15: the local DB is behind what the peer holds of this origin.
        await device.switchOriginAfterPeerCursor(failure.peerCursor!);
      }
      return _failedResult(failure);
    } finally {
      _unregister();
      await _flushWatermark();
    }
  }

  Future<void> _flushWatermark() async {
    final failuresBefore = device.watermarkFlushFailures;
    await device.flushWrittenWatermark();
    stats.watermarkFlushFailed += device.watermarkFlushFailures - failuresBefore;
  }

  Future<SessionResult> _early(SessionFailure category, {String? peer}) async {
    await _transport.close();
    return SessionFailed(stats, peer, category);
  }

  void _unregister() {
    for (final id in {_peerId, if (initiator) expectedPeer}) {
      if (id != null && identical(device.activeSessions[id], this)) device.activeSessions.remove(id);
    }
  }

  // --- Handshake, version check, arbitration -------------------------------------

  Future<SessionResult> _run() async {
    final m = device.membership;
    final config = device.config;
    var rejectedStatic = false;
    bool accept(Uint8List pub) {
      final ok = m.acceptsStatic(pub);
      if (!ok) rejectedStatic = true;
      return ok;
    }

    final hello = Hello(
      protocolVersion: config.protocolVersion,
      minCompatible: config.minCompatible,
      appVersion: config.appVersion,
      memberId: device.memberId,
      deviceName: device.name,
      wallMs: device.now(),
    );
    final SecureChannel channel;
    final Uint8List? peerHelloBytes;
    try {
      (channel, peerHelloBytes) = await SecureChannel.handshake(
        transport: _transport,
        initiator: initiator,
        staticKey: m.identity.x25519,
        acceptRemoteStatic: accept,
        hello: initiator ? SyncCodec.encode(hello) : null,
      );
    } on SyncCryptoException {
      throw SessionAbort(rejectedStatic ? SessionFailure.notAuthorized : SessionFailure.securityError);
    }
    _channel = channel;
    final peer = m.activeMemberByX25519(channel.remoteStatic);
    if (peer == null) throw const SessionAbort(SessionFailure.notAuthorized);
    _peerId = peer.memberId;
    _peerEd = Uint8List.fromList(peer.ed25519Pub);

    final Hello peerHello;
    if (initiator) {
      if (peer.memberId != expectedPeer) {
        // The address answered with another member's key (D7): continue
        // with that member; the address list is T20's concern.
        if (device.activeSessions.containsKey(peer.memberId)) throw const SessionAbort(SessionFailure.busy);
        _unregister();
        device.activeSessions[peer.memberId] = this;
      }
      final SyncMessage answer;
      try {
        answer = await channel.receive();
      } on TransportClosedException {
        throw const SessionAbort(SessionFailure.refusedByPeer);
      }
      switch (answer) {
        case Busy():
          throw const SessionAbort(SessionFailure.busy);
        case ErrorMessage(:final category):
          throw SessionAbort(
              category == SyncErrorCategory.preparing ? SessionFailure.peerPreparing : SessionFailure.peerError);
        default:
          switch (evaluateHelloAnswer(local: hello, answer: answer)) {
            case Incompatible(:final mustUpdate):
              await channel.close();
              return SessionFailed(stats, _peerId, SessionFailure.needsUpdate, mustUpdate: mustUpdate);
            case Compatible():
              peerHello = (answer as HelloAck).hello;
          }
      }
    } else {
      final decoded = SyncCodec.decode(peerHelloBytes ?? Uint8List(0));
      if (decoded is! Hello) throw const MalformedMessageException('expected Hello in handshake message 3');
      peerHello = decoded;
      final other = device.activeSessions[peer.memberId];
      if (other != null && (!other.initiator || device.memberId.compareTo(peer.memberId) < 0)) {
        await channel.send(const Busy());
        await channel.close();
        return SessionFailed(stats, _peerId, SessionFailure.busy);
      }
      device.activeSessions[peer.memberId] = this;
      final answer = answerHello(local: hello, remote: peerHello);
      await channel.send(answer);
      if (answer is UpdateRequired) {
        await channel.close();
        return SessionFailed(
          stats,
          _peerId,
          SessionFailure.needsUpdate,
          mustUpdate: DeviceRef(answer.memberId, answer.deviceName),
        );
      }
    }
    if (peerHello.memberId != peer.memberId) throw const MalformedMessageException('Hello member id mismatch');
    device.peerState(peer.memberId)
      ..lastPeerWall = peerHello.wallMs
      ..lastPeerWallReceivedAt = device.now();
    return _exchange(channel);
  }

  // --- Exchange --------------------------------------------------------------------

  Future<SessionResult> _exchange(SecureChannel channel) async {
    _nonces = NonceSource();
    final reader = _readLoop(channel);
    try {
      await _writer(channel);
    } catch (e) {
      _fail(e);
    }
    await reader;
    if (_failure != null) throw _failure!;
    stats
      ..framesSent = channel.sent.values.fold(0, (a, b) => a + b)
      ..bytesSent = channel.bytesSent
      ..supersededIndexed = await _store.supersededIndexed();
    await channel.close();
    return _finish();
  }

  void _fail(Object error) {
    if (_failure != null) return;
    _failure = error;
    if (!_failed.isCompleted) _failed.complete();
    // Wakes the other loop: its pending receive or send fails.
    unawaited(_channel?.abort() ?? Future.value());
  }

  /// Awaits [future] unless the session fails first.
  Future<T> _guard<T>(Future<T> future) => Future.any(
      [future, _failed.future.then<T>((_) => throw _failure ?? const SessionAbort(SessionFailure.internal))]);

  Future<void> _send(SecureChannel channel, SyncMessage message) => _guard(channel.send(message));

  Future<void> _readLoop(SecureChannel channel) async {
    try {
      while (!(_peerEnded && _endAcked.isCompleted)) {
        final message = await channel.receive();
        if (_failure != null) return;
        await _handle(channel, message);
      }
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _handle(SecureChannel channel, SyncMessage message) async {
    switch (message) {
      case OriginRegistry(:final entries):
        if (_registryReceived) throw const MalformedMessageException('second OriginRegistry');
        _registryReceived = true;
        if (await _mergeRegistrations(entries) > 0) await _onSecurityChange();
      case VectorExchange vx:
        if (!_registryReceived || _peerVx != null) throw const MalformedMessageException('unexpected VectorExchange');
        await _onVectorExchange(channel, vx);
      case KeyHandover(:final grants):
        if (_peerVx == null || _handoverReceived) throw const MalformedMessageException('unexpected KeyHandover');
        await _acceptHandover(grants);
        _handoverReceived = true;
        await _retryHeld(includeApplyFailed: true);
      case ChangeBatchMessage batch:
        if (!_handoverReceived) throw const MalformedMessageException('change batch before key handover');
        await _receiveBatch(channel, batch);
      case BatchAck(:final batchId):
        _onAck(batchId);
      case ErrorMessage(:final category):
        throw SessionAbort(
            category == SyncErrorCategory.preparing ? SessionFailure.peerPreparing : SessionFailure.peerError);
      default:
        throw MalformedMessageException('unexpected ${message.type.name}');
    }
  }

  /// Merges verified registration rows through the security projection and
  /// stores the new ones. Returns the number of rows newly added.
  Future<int> _mergeRegistrations(List<OriginRegistration> entries) async {
    return _serializedMembership(() async {
      final projection = await _store.securityProjection();
      final before = projection.registrations.length;
      final added = await device.membership.mergeRegistrations(entries, projection);
      if (added > 0) await _store.persistRegistrations(projection.registrations.skip(before));
      return added;
    });
  }

  /// Membership work queued per device: `Membership.rebuild` and
  /// `mergeRegistrations` await in the middle of updating their view, so the
  /// reader and writer loops (and parallel sessions) must not overlap in them.
  static final Expando<Future<void>> _membershipTails = Expando('membership work');

  Future<T> _serializedMembership<T>(Future<T> Function() work) {
    final membership = device.membership;
    final result = (_membershipTails[membership] ?? Future<void>.value()).then((_) => work());
    _membershipTails[membership] = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<bool> _rebuild() =>
      _serializedMembership(() async => device.membership.rebuild(await _store.securityProjection()));

  Future<void> _recordGrants(Iterable<EpochGrant> grants) async {
    for (final grant in grants) {
      await device.recordGrant(grant);
    }
  }

  /// Stores the keys the peer handed over (never `keyring.add`: a conflicting
  /// key for a held epoch must not abort the session) and records the grants.
  Future<void> _acceptHandover(List<EpochKeyGrant> keys) async {
    final m = device.membership;
    try {
      final result = m.keyring.acceptHandover(
        fromPub: _peerEd!,
        ownPub: m.identity.ed25519Pub,
        keys: keys,
        creatorPubOf: (creatorId) => m.memberById(creatorId)?.ed25519Pub,
      );
      stats.keysReceived += result.added.length;
      await _recordGrants(result.grants);
      if (result.grants.isNotEmpty) await _rebuild();
    } finally {
      for (final k in keys) {
        zeroize(k.key);
      }
    }
  }

  Future<void> _onVectorExchange(SecureChannel channel, VectorExchange vx) async {
    _peerVx = vx;
    _peerVector = {for (final e in vx.vector.entries) e.key.hex: e.value};
    // The send bound (FR-014), taken before any of the peer's batches is
    // applied so nothing received in this session is echoed back.
    _snapshot = await _store.vector();
    final peerCursor = _peerVector[(await _store.localOrigin()).hex] ?? 0;
    if (peerCursor > await _store.nextSeq() - 1) {
      await _send(channel, ErrorMessage(SyncErrorCategory.preparing));
      throw SessionAbort(SessionFailure.restoreDetected, peerCursor: peerCursor);
    }
    _peerVxReady.complete(vx);
  }

  // --- Writer ------------------------------------------------------------------------

  Future<void> _writer(SecureChannel channel) async {
    final m = device.membership;
    await _send(channel, OriginRegistry(await _store.registrations()));
    await _send(
      channel,
      VectorExchange(
        vector: {for (final e in (await _store.vector()).entries) OriginId.fromHex(e.key): e.value},
        refetch: await _refetchKeys(),
        heldEpochs: m.keyring.epochs,
      ),
    );
    final vx = await _guard(_peerVxReady.future);

    // Key handover (D7, receiver-driven): the keys the peer did not list,
    // unless the peer is excluded.
    final peerEd = _peerEd!;
    final (grants, handedOver) = m.keyring.handoverTo(
      peerPub: peerEd,
      peerHas: vx.heldEpochs.toSet(),
      peerIsRevoked: m.isExcluded(peerEd),
    );
    try {
      await _send(channel, KeyHandover(grants));
    } finally {
      for (final g in grants) {
        zeroize(g.key);
      }
    }
    if (handedOver.isNotEmpty) {
      stats.keysHandedOver += handedOver.length;
      await _recordGrants(handedOver);
      await _rebuild();
    }

    await _sendRefetch(channel, vx.refetch);
    await _stream(channel);

    final endId = _nextBatchId++;
    _endMarkerId = endId;
    await _sendBatch(channel, ChangeBatchMessage(batchId: endId, ranges: const {}), data: false);
    await _guard(_endAcked.future);
  }

  Future<List<CellKey>> _refetchKeys() async {
    final keys = <CellKey>{};
    for (final h in await _store.heldEnvelopes()) {
      if (h.reason == HeldReason.applyFailed) keys.add(h.key);
    }
    return keys.toList();
  }

  /// Answers the peer's refetch list with current cells it already covers
  /// (newer ones are in the stream anyway).
  Future<void> _sendRefetch(SecureChannel channel, List<CellKey> refetch) async {
    final cells = <StoredCell>[];
    for (final key in refetch) {
      final cell = await _store.storedCell(key);
      if (cell != null) cells.add(cell);
    }
    stats.refetchSent += await _sendCovered(channel, cells, const []);
  }

  /// Sends signed [cells] and [held] envelopes whose seqs the peer's cursors
  /// already cover (anything above them is in the stream). Each batch
  /// declares `(min − 1, max]` per origin, at or below the peer's cursor, so
  /// the ranges never move it. Returns the number of envelopes sent.
  Future<int> _sendCovered(SecureChannel channel, List<StoredCell> cells, List<HeldEnvelope> held) async {
    final config = device.config;
    final seen = <String>{};
    final items = <(String, int, OriginManifest, ChangeEnvelope Function(), int)>[];
    for (final cell in cells) {
      final r = cell.record;
      final manifest = cell.manifest;
      if (manifest == null || r.originSeq > (_peerVector[r.origin] ?? 0)) continue;
      if (seen.add('${r.origin}#${r.originSeq}'))
        items.add((r.origin, r.originSeq, manifest, () => _seal(r), estimateCell(r)));
    }
    for (final h in held) {
      if (h.seq > (_peerVector[h.origin] ?? 0)) continue;
      if (seen.add('${h.origin}#${h.seq}')) items.add((h.origin, h.seq, h.manifest, () => h.envelope, heldSize(h)));
    }
    var sent = 0;
    var i = 0;
    while (i < items.length) {
      final lo = <String, int>{};
      final hi = <String, int>{};
      final manifests = <OriginManifest>{};
      final envelopes = <ChangeEnvelope>[];
      var bytes = 64;
      while (i < items.length) {
        final (origin, seq, manifest, build, size) = items[i];
        final extra = manifests.contains(manifest) ? 0 : manifestSize(manifest);
        if (envelopes.isNotEmpty &&
            (envelopes.length >= config.maxBatchChanges || bytes + size + extra > config.maxBatchBytes)) {
          break;
        }
        lo[origin] = math.min(lo[origin] ?? seq, seq);
        hi[origin] = math.max(hi[origin] ?? seq, seq);
        manifests.add(manifest);
        envelopes.add(build());
        bytes += size + extra;
        i++;
      }
      sent += envelopes.length;
      await _sendBatch(
        channel,
        ChangeBatchMessage(
          batchId: _nextBatchId++,
          ranges: {
            for (final o in lo.keys) OriginId.fromHex(o): [SeqRange(lo[o]! - 1, hi[o]!)]
          },
          manifests: manifests.toList(),
          envelopes: envelopes,
        ),
      );
    }
    return sent;
  }

  ChangeEnvelope _seal(CellRecord record) {
    final m = device.membership;
    final cipher =
        EnvelopeCipher(groupId: m.groupId!, keyring: m.keyring, protocolVersion: device.config.protocolVersion);
    return cipher.seal(Change.fromCellRecord(record, groupId: m.groupId!), _nonces);
  }

  Future<void> _stream(SecureChannel channel) async {
    final snapshot = _snapshot!;
    final plans = [
      for (final o in snapshot.keys.toList()..sort())
        if (snapshot[o]! > (_peerVector[o] ?? 0)) OriginPlan(o, _peerVector[o] ?? 0, snapshot[o]!),
    ];
    var p = 0;
    while (p < plans.length && !_storageError) {
      final draft = BatchDraft(device.config, own: (await _store.localOrigin()).hex);
      while (p < plans.length && !draft.full) {
        final plan = plans[p];
        final from = plan.declared;
        await _scanPlan(plan, draft);
        final to = plan.done ? plan.bound : plan.scanned;
        if (to > from) draft.declare(plan.origin, SeqRange(from, to));
        plan
          ..declared = to
          ..scanned = to;
        if (plan.done || plan.stopped) p++;
      }
      if (draft.ranges.isEmpty) continue;
      assert(await _omissionsAreCovered(draft), 'a range omits a superseded seq without its winner (F5)');
      final sent = await _sendBatch(
        channel,
        ChangeBatchMessage(
          batchId: _nextBatchId++,
          ranges: draft.ranges,
          manifests: draft.manifests.toList(),
          envelopes: draft.envelopes,
        ),
        ownTo: draft.ownTo,
      );
      if (!sent) return;
      stats.sentVersions.addAll(draft.versions);
    }
    if (!_storageError) await _serveAboveCursor(channel);
  }

  /// Adds the items of [plan] above its scan position to [draft] in seq order,
  /// until the plan reaches its bound ([OriginPlan.done]), the batch is full
  /// ([BatchDraft.full]) or the origin is given up for this session
  /// ([OriginPlan.stopped]).
  Future<void> _scanPlan(OriginPlan plan, BatchDraft draft) async {
    int? rereadMissSeq;
    while (true) {
      final (:cell, :held, :superseded) = await _store.nextOfOrigin(plan.origin, plan.scanned);
      final cellSeq = cell?.record.originSeq;
      final heldSeq = held?.seq;
      final useCell = cellSeq != null && (heldSeq == null || cellSeq <= heldSeq);
      final liveSeq = useCell ? cellSeq : heldSeq;
      final supersededSeq = superseded?.$1;
      final liveFirst = liveSeq != null && (supersededSeq == null || liveSeq <= supersededSeq);
      final seq = liveFirst ? liveSeq : supersededSeq;
      if (seq == null || seq > plan.bound) {
        plan.done = true;
        return;
      }
      if (!liveFirst) {
        if (!await _passSuperseded(plan, draft, seq, superseded!.$2)) return;
        continue;
      }
      if (useCell && isNeverSentSecurityCell(cell!, draft.own)) {
        // Stayed on the sealed origin at a switch (U11/rooted): it is never
        // sent, its seq is just a gap in the declared range.
        plan.scanned = seq;
        continue;
      }
      // Already in the batch as the winner behind a superseded seq (F5).
      if (draft.versions.contains('${plan.origin}#$seq')) {
        plan.scanned = seq;
        continue;
      }
      final size = useCell ? estimateCell(cell!.record) : heldSize(held!);
      final manifest = useCell ? cell!.manifest : held!.manifest;
      if (draft.overflows(size, manifest)) {
        draft.full = true;
        return;
      }
      if (useCell) {
        if (cell!.manifest == null) await _signOwnThrough(seq, plan.bound);
        final current = await _store.storedCell(cell.record.key);
        // Superseded while signing: the next pass handles its seq as
        // superseded.
        if (current == null || !sameVersion(current.record, cell.record)) {
          // One retry covers a cell superseded while signing. A second miss
          // for the same seq means the store cannot re-read what it just
          // listed; looping again would spin without ever yielding to timers.
          if (rereadMissSeq == seq) {
            throw StateError('cell $seq of ${plan.origin} cannot be re-read by key');
          }
          rereadMissSeq = seq;
          continue;
        }
        final signedBy = current.manifest ?? (throw StateError('own origin switched during the session'));
        draft.add(signedBy, _seal(current.record), estimateCell(current.record), origin: plan.origin, seq: seq);
      } else {
        draft.add(held!.manifest, held.envelope, size, origin: plan.origin, seq: seq);
        stats.heldRelayed++;
      }
      plan.scanned = seq;
    }
  }

  /// Debug oracle (F5): every superseded seq inside a declared range of [draft]
  /// is covered by its winner, already at the receiver, in this batch, or sent
  /// earlier in this session. Runs in `assert` only.
  Future<bool> _omissionsAreCovered(BatchDraft draft) async {
    for (final entry in draft.ranges.entries) {
      for (final range in entry.value) {
        var superseded = await _store.nextSupersededOfOrigin(entry.key.hex, range.from);
        while (superseded != null && superseded.$1 <= range.to) {
          final winner = await _store.storedCell(superseded.$2);
          // Covered when passed with its winner at scan time, or sent before it
          // was superseded; the winner may have been replaced since.
          final version = '${entry.key.hex}#${superseded.$1}';
          final covered = draft.passed.contains(version) ||
              _wasSent(draft, version) ||
              winner == null ||
              selectRelayWinner(winner, _peerVector[winner.record.origin] ?? 0) == null ||
              _wasSent(draft, versionOf(winner.record));
          if (!covered) return false;
          superseded = await _store.nextSupersededOfOrigin(entry.key.hex, superseded.$1);
        }
      }
    }
    return true;
  }

  bool _wasSent(BatchDraft draft, String version) =>
      draft.versions.contains(version) || stats.sentVersions.contains(version);

  /// Passes the superseded [seq] of [plan] (its winner is the cell at [key]).
  /// The receiver may move its cursor past [seq] only if it already has the
  /// winner or gets it in the same atomic batch (F5). Returns whether the scan
  /// may go on; otherwise the batch is full or the origin was given up.
  Future<bool> _passSuperseded(OriginPlan plan, BatchDraft draft, int seq, CellKey key) async {
    final committed = await _store.storedCell(key);
    if (committed == null) {
      // A stale entry (its cell was removed) must not stall the origin for
      // good: nothing can be relayed for it, so drop it and treat the seq as
      // a gap.
      stats.staleSupersededDropped++;
      await _store.dropSupersededEntry(plan.origin, seq);
      plan.scanned = seq;
      return true;
    }
    final winner = selectRelayWinner(committed, _peerVector[committed.record.origin] ?? 0);
    if (winner == null) {
      plan.scanned = seq;
      draft.passed.add('${plan.origin}#$seq');
      return true;
    }
    switch (await _relayWinner(winner, draft)) {
      case WinnerRelay.included:
        plan.scanned = seq;
        draft.passed.add('${plan.origin}#$seq');
        return true;
      case WinnerRelay.changed:
        return true;
      case WinnerRelay.noRoom:
        draft.full = true;
        return false;
      case WinnerRelay.unusable:
        // As the first item of a batch nothing could progress: give the origin
        // up for this session instead of looping (a later session retries).
        if (draft.isEmpty && plan.scanned == plan.declared) {
          plan.stopped = true;
        } else {
          draft.full = true;
        }
        return false;
    }
  }

  /// Puts the committed [winner] into [draft] under a narrow range of its own
  /// unless the batch already carries it.
  Future<WinnerRelay> _relayWinner(StoredCell winner, BatchDraft draft) async {
    final record = winner.record;
    if (draft.versions.contains(versionOf(record))) return WinnerRelay.included;
    var signed = winner;
    if (record.origin == draft.own) {
      // Sign through the winner only: it may lie above the snapshot, and the
      // own bound stays as it is (FR-014). Its seq still counts in `ownTo`.
      if (winner.manifest == null) await _signOwnThrough(record.originSeq, record.originSeq);
      final current = await _store.storedCell(record.key);
      if (current == null || !sameVersion(current.record, record)) return WinnerRelay.changed;
      signed = current;
    }
    final manifest = signed.manifest;
    if (manifest == null) return WinnerRelay.unusable;
    if (draft.overflows(estimateCell(record), manifest)) return WinnerRelay.noRoom;
    draft.add(manifest, _seal(record), estimateCell(record), origin: record.origin, seq: record.originSeq);
    if (!draft.covers(record.origin, record.originSeq)) {
      draft.declare(record.origin, SeqRange(record.originSeq - 1, record.originSeq));
    }
    return WinnerRelay.included;
  }

  /// Serves signed cells this store holds above its own cursor for their
  /// origin — after `local_reset` cleared the vector (D14), the retained
  /// security rows. Each goes in its own batch with the single-seq
  /// range `(seq − 1, seq]`, which moves a peer's cursor only when it is
  /// contiguous, so nothing is skipped.
  Future<void> _serveAboveCursor(SecureChannel channel) async {
    final snapshot = _snapshot!;
    final own = (await _store.localOrigin()).hex;
    for (final origin in (await _store.cellOrigins())..sort()) {
      if (origin == own) continue;
      final from = math.max(snapshot[origin] ?? 0, _peerVector[origin] ?? 0);
      var cell = await _store.nextCellOfOrigin(origin, from);
      while (cell != null && !_storageError) {
        final record = cell.record;
        final manifest = cell.manifest;
        if (manifest != null) {
          await _sendBatch(
            channel,
            ChangeBatchMessage(
              batchId: _nextBatchId++,
              ranges: {
                OriginId.fromHex(origin): [SeqRange(record.originSeq - 1, record.originSeq)]
              },
              manifests: [manifest],
              envelopes: [_seal(record)],
            ),
          );
          stats.sentVersions.add('$origin#${record.originSeq}');
          stats.aboveCursorSent++;
        }
        cell = await _store.nextCellOfOrigin(origin, record.originSeq);
      }
    }
  }

  /// Signs own manifests (≤ 1,000 consecutive seqs each) until [seq] is
  /// covered, never beyond [bound] (D7: built at send time; the snapshot bound,
  /// or [seq] itself for a relayed winner above the snapshot).
  Future<void> _signOwnThrough(int seq, int bound) async {
    final m = device.membership;
    while (await _store.ownSignedTo() < seq) {
      final from = await _store.ownSignedTo();
      final to = math.min(from + SyncLimits.maxBatchChanges, bound);
      final origin = await _store.localOrigin();
      final changes = [
        for (final r in await _store.ownCellsInRange(from, to)) Change.fromCellRecord(r, groupId: m.groupId!),
      ];
      final signer = ManifestSigner(groupId: m.groupId!, origin: origin, signer: m.identity.ed25519);
      final signed = await signer.sign(fromSeq: from, toSeq: to, changes: changes);
      if (await _store.localOrigin() != origin) return;
      for (final manifest in signed) {
        await _store.attachOwnManifest(manifest);
        stats.manifestsSigned++;
      }
    }
  }

  /// Sends one batch within the window. Returns `false` when the sent-seq
  /// mark could not be persisted (the batch is not sent, D7).
  Future<bool> _sendBatch(SecureChannel channel, ChangeBatchMessage batch, {int ownTo = 0, bool data = true}) async {
    if (ownTo > 0 && !await _persistSentMark(ownTo)) {
      _storageError = true;
      return false;
    }
    while (_unacked.length >= device.config.window) {
      await _guard((_ackSignal ??= Completer()).future);
    }
    final outgoing = data ? (hooks.outgoingBatch?.call(batch) ?? batch) : batch;
    _unacked.add(batch.batchId);
    stats.maxInFlight = math.max(stats.maxInFlight, _unacked.length);
    await _send(channel, outgoing);
    if (data) {
      stats
        ..batchesSent += 1
        ..envelopesSent += outgoing.envelopes.length;
      hooks.afterBatchSent?.call(batch.batchId);
    }
    return true;
  }

  Future<bool> _persistSentMark(int seq) async {
    final origin = await _store.localOrigin();
    final mark = device.ledger.entryOf(origin)?.maxSentSeq ?? 0;
    if (seq <= mark) return true;
    final delays = device.config.sentMarkRetryDelays;
    for (var attempt = 0;; attempt++) {
      try {
        await device.ledger.persistSentMark(origin, seq, await _store.hlc());
        return true;
      } on SyncLedgerWriteException {
        if (attempt >= delays.length) return false;
        await device.config.delay(delays[attempt]);
      }
    }
  }

  void _onAck(int batchId) {
    if (!_unacked.contains(batchId)) throw MalformedMessageException('unexpected ack $batchId');
    stats.maxUnackedAtAck = math.max(stats.maxUnackedAtAck, _unacked.length);
    _unacked.remove(batchId);
    final signal = _ackSignal;
    _ackSignal = null;
    signal?.complete();
    if (batchId == _endMarkerId) _endAcked.complete();
  }

  // --- Receiver ------------------------------------------------------------------------

  Future<void> _receiveBatch(SecureChannel channel, ChangeBatchMessage batch) async {
    if (batch.ranges.isEmpty && batch.envelopes.isEmpty) {
      _peerEnded = true;
      await _send(channel, BatchAck(batch.batchId));
      return;
    }
    // After a ledger write failure nothing more is committed and the cursor
    // stays put, so the peer sends the rest again next session (U11/Efe-R1).
    if (_storageError) {
      await _send(channel, BatchAck(batch.batchId));
      return;
    }
    hooks.beforeApply?.call(batch);
    final verifier = device.membership.verifier;
    final verdicts = <ManifestVerdict>[for (final mf in batch.manifests) await verifier.verify(mf)];
    if (_failure != null) return;
    final decisions = <(ChangeEnvelope, SessionDecision)>[
      for (final e in batch.envelopes) (e, decideEnvelope(device.membership, e, batch.manifests, verdicts)),
    ];
    final applicable = [
      for (final (_, decision) in decisions)
        if (decision case ApplyDecision(:final change)) change,
    ];
    // Without its revocation records in the ledger the batch is not committed
    // and its ranges do not move the cursor, so the peer sends it again.
    if (!await _retainRevocations(applicable)) {
      await _send(channel, BatchAck(batch.batchId));
      return;
    }
    // Commit: one store transaction (the batch transaction); each item is
    // isolated (its own savepoint), a failed item does not hold back the
    // cursor (D15).
    final now = device.now();
    final securityTouched = await _store.inTransaction(() async {
      var touched = false;
      for (final (envelope, decision) in decisions) {
        stats.envelopesReceived++;
        touched |= await _commitDecision(envelope, decision, now);
      }
      for (final e in batch.ranges.entries) {
        // Ascending per origin ([ChangeBatchMessage.ranges]).
        for (final range in e.value) {
          await _store.advanceCursor(e.key.hex, fromSeq: range.from, toSeq: range.to);
        }
      }
      return touched;
    });
    stats.batchesApplied++;
    if (securityTouched) await _onSecurityChange();
    await _send(channel, BatchAck(batch.batchId));
  }

  /// Commits one decided envelope of a received batch. Returns whether a
  /// security row changed.
  Future<bool> _commitDecision(ChangeEnvelope envelope, SessionDecision decision, int now) async {
    final origin = envelope.origin.hex;
    switch (decision) {
      case ApplyDecision(:final change, :final manifest):
        switch (await _store.applyRemote(change, manifest, nowMs: now)) {
          case ApplyOutcome.failed:
            await _holdFailed(envelope, manifest, now);
            return false;
          case ApplyOutcome.applied:
            stats.applied++;
            await _markCommitted(origin, envelope.originSeq);
            return SecurityTables.contains(change.tbl);
          case ApplyOutcome.unchanged:
            stats.unchanged++;
            await _markCommitted(origin, envelope.originSeq);
            return false;
        }
      case HoldDecision(:final reason, :final manifest, :final rejectedAs):
        if (await _store.heldAt(origin, envelope.originSeq) == null) {
          await _store.putHeld(HeldEnvelope(
            envelope: envelope,
            manifest: manifest,
            reason: reason,
            recordedAt: now,
            peer: _peerId,
            category: rejectedAs,
          ));
        }
        if (reason == HeldReason.missingKey) {
          stats.heldMissingKey++;
        } else {
          stats.heldUnverified++;
        }
        if (rejectedAs != null) stats.reject(rejectedAs);
        return false;
      case RejectDecision(:final reason):
        stats.reject(reason);
        return false;
    }
  }

  Future<void> _markCommitted(String origin, int seq) async {
    await _store.removeHeld(origin, seq);
    await _store.logCommit(origin, seq);
  }

  Future<void> _holdFailed(ChangeEnvelope envelope, OriginManifest manifest, int now) async {
    final origin = envelope.origin.hex;
    final existing = await _store.heldAt(origin, envelope.originSeq);
    if (existing != null) {
      existing
        ..reason = HeldReason.applyFailed
        ..failCount += 1
        ..peer = _peerId
        ..category = 'apply_failed';
      await _store.putHeld(existing);
    } else {
      await _store.putHeld(HeldEnvelope(
        envelope: envelope,
        manifest: manifest,
        reason: HeldReason.applyFailed,
        recordedAt: now,
        peer: _peerId,
        failCount: 1,
        category: 'apply_failed',
      ));
    }
    stats.failed++;
    _failedRows.add(RowRef(envelope.tbl, envelope.pk));
  }

  /// Whether [held] is still stored unchanged (a database store returns a
  /// fresh copy on each read, so identity cannot tell).
  Future<bool> _stillHeld(HeldEnvelope held) async {
    final current = await _store.heldAt(held.origin, held.seq);
    return current != null && current.reason == held.reason && current.failCount == held.failCount;
  }

  /// Retries held envelopes: after the peer's key handover (all reasons, the
  /// session-start retry of D15) and after membership or cutoff changes
  /// (missing key, unverified). Superseded entries leave the table.
  Future<void> _retryHeld({required bool includeApplyFailed}) async {
    for (var round = 0; round < 4; round++) {
      final m = device.membership;
      var securityTouched = false;
      for (final held in await _store.heldEnvelopes()) {
        if (_failure != null) return;
        if (!includeApplyFailed && held.reason == HeldReason.applyFailed) continue;
        if (!await _stillHeld(held)) continue;
        if (await _store.isSuperseded(held)) {
          await _store.dropSupersededHeld(held);
          continue;
        }
        final verdict = await m.verifier.verify(held.manifest);
        if (!await _stillHeld(held)) continue;
        final decision = decideWith(device.membership, held.envelope, [(held.manifest, verdict)]);
        final now = device.now();
        // A held revocation whose ledger write fails stays held for later.
        if (decision is ApplyDecision && !await _retainRevocations([decision.change])) continue;
        switch (decision) {
          case ApplyDecision(:final change, :final manifest):
            switch (await _store.applyRemote(change, manifest, nowMs: now)) {
              case ApplyOutcome.failed:
                await _holdFailed(held.envelope, manifest, now);
              case ApplyOutcome.applied || ApplyOutcome.unchanged:
                await _store.removeHeld(held.origin, held.seq);
                stats.heldRetriedApplied++;
                if (SecurityTables.contains(change.tbl)) securityTouched = true;
            }
          case HoldDecision(:final reason, :final rejectedAs):
            held
              ..reason = held.reason == HeldReason.applyFailed ? held.reason : reason
              ..category = rejectedAs ?? held.category;
            await _store.putHeld(held);
          case RejectDecision(:final reason):
            await _store.removeHeld(held.origin, held.seq);
            stats.reject(reason);
        }
      }
      if (!securityTouched) return;
      if (!await _rebuildMembership()) return;
      includeApplyFailed = false;
    }
  }

  /// Persists the revocation records among [changes] to the sync ledger
  /// before they are committed (U11/Efe-1). Returns `false` on a ledger
  /// write failure: the caller commits none of them, and the session stops
  /// sending and ends partial with storage error (D7).
  Future<bool> _retainRevocations(List<Change> changes) async {
    try {
      await device.retainReceivedRevocations(changes);
      return true;
    } on SyncLedgerWriteException {
      _storageError = true;
      return false;
    }
  }

  Future<void> _onSecurityChange() async {
    if (await _rebuildMembership()) await _retryHeld(includeApplyFailed: false);
  }

  Future<bool> _rebuildMembership() async {
    final m = device.membership;
    final changed = await _rebuild();
    if (m.removed) throw const SessionAbort(SessionFailure.removedFromGroup);
    return changed;
  }

  // --- End ---------------------------------------------------------------------------

  Future<SessionResult> _finish() async {
    final peerId = _peerId!;
    final now = device.now();
    final peer = device.peerState(peerId);
    for (final row in _failedRows) {
      peer.consecutiveFailures[row] = (peer.consecutiveFailures[row] ?? 0) + 1;
    }
    peer.consecutiveFailures.removeWhere((row, _) => !_failedRows.contains(row));
    peer.itemsCannotBeApplied = peer.consecutiveFailures.values.any((n) => n >= 3);
    final reasons = {
      if (stats.failed > 0) PartialReason.itemsFailed,
      if (stats.rejected > 0) PartialReason.itemsRejected,
      if (_storageError) PartialReason.storageError,
    };
    final SessionResult result =
        reasons.isEmpty ? SessionComplete(stats, peerId) : SessionPartial(stats, peerId, reasons);
    peer
      ..lastResult = result
      ..lastExchangeLocal = now;
    if (result.isComplete) peer.lastCompleteLocal = now;
    device.lastSuccessfulSyncLocal = now;
    await device.maintainMembership();
    return result;
  }

  SessionResult _failedResult(Object error) {
    final SessionFailed result;
    if (error is SessionAbort) {
      result = SessionFailed(stats, _peerId, error.category, peerCursor: error.peerCursor);
    } else if (error is TransportClosedException) {
      result = SessionFailed(stats, _peerId, SessionFailure.notReachable);
    } else if (error is SyncCryptoException) {
      result = SessionFailed(stats, _peerId, SessionFailure.securityError);
    } else if (error is SyncDecodeException) {
      result = SessionFailed(stats, _peerId, SessionFailure.protocolError, error: error);
    } else {
      result = SessionFailed(stats, _peerId, SessionFailure.internal, error: error);
    }
    if (_peerId != null) device.peerState(_peerId!).lastResult = result;
    return result;
  }

  @override
  String toString() => 'AsyncSyncSession(${device.name}, ${initiator ? 'initiator' : 'responder'}, peer $_peerId)';
}
