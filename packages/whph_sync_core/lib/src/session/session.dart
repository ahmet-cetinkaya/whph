/// The sync session state machine (D7, D8, D15, U9/PA-2).
///
/// ## Flow (both sides after the handshake run the same exchange)
///
/// 1. Noise `XX` with the `MembershipView` check (reject only); the
///    initiator's `Hello` rides in handshake message 3. The responder
///    arbitrates simultaneous starts (the session started by the smaller
///    member id continues, the other gets `Busy`) and answers `HelloAck` or
///    `UpdateRequired` (FR-040, FR-041).
/// 2. Each side's writer sends `OriginRegistry` (first, D7) and
///    `VectorExchange{vector, refetch}`.
/// 3. On the peer's `VectorExchange` the reader takes this side's snapshot
///    vector (the send bound, FR-014) and runs the peer-cursor restore check
///    (abort with `ErrorMessage(preparing)` → `switch_origin(restore)` →
///    retry). Deletion records are kept indefinitely, so the incremental
///    exchange is always sound.
/// 4. The writer hands over epoch keys the peer lacks (`KeyHandover`,
///    recording grants), answers the peer's refetch list, then streams
///    ranged `ChangeBatchMessage`s: per origin, every seq in
///    `(peer cursor, snapshot]` ascending, declared as `(from, to]` ranges;
///    own unsigned cells get manifests (≤ 1,000 seqs) signed at send time;
///    other cells travel with their stored manifests, held envelopes
///    verbatim. The sent-seq mark is persisted before a batch above it.
/// 5. Pipelining: up to `window` batches stay unacknowledged; acks
///    (`BatchAck`) arrive asynchronously; the receiver applies each batch as
///    one atomic step with per-item isolation, then advances cursors to the
///    declared bounds and acks. Both directions stream concurrently.
/// 6. An empty batch (no ranges, no envelopes) ends a stream. The session is
///    done when both streams ended and were acknowledged.
///
/// Any Noise failure (replayed, reordered, altered frame), decode error,
/// transport close or peer error tears the session down; committed batches
/// stay committed, so the next session resumes from the advanced cursors
/// (FR-012).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../crypto/envelope.dart';
import '../crypto/manifest_signer.dart';
import '../crypto/primitives.dart';
import '../model/change.dart';
import '../model/envelope.dart';
import '../model/ids.dart';
import '../model/manifest.dart';
import '../protocol/errors.dart';
import '../protocol/messages.dart';
import '../protocol/version.dart';
import '../store/sync_ledger.dart';
import '../store/replica_store.dart';
import '../store/sync_store.dart';
import 'secure_channel.dart';
import 'session_result.dart';
import 'sync_device.dart';
import 'transport.dart';

/// Test hooks of one session side.
final class SessionHooks {
  const SessionHooks({this.outgoingBatch, this.afterBatchSent, this.beforeApply});

  /// Replaces each outgoing change batch before it is encoded (models a
  /// tampering insider or relay: the receiver must reject the altered item).
  final ChangeBatchMessage Function(ChangeBatchMessage batch)? outgoingBatch;

  /// Called after a data batch was handed to the transport.
  final void Function(int batchId)? afterBatchSent;

  /// Called before a received data batch is applied.
  final void Function(ChangeBatchMessage batch)? beforeApply;
}

/// Aborts a session with a failure category.
final class _Abort implements Exception {
  const _Abort(this.category, {this.peerCursor});

  final SessionFailure category;
  final int? peerCursor;

  @override
  String toString() => '_Abort(${category.name})';
}

sealed class _Decision {
  const _Decision();
}

final class _Apply extends _Decision {
  const _Apply(this.change, this.manifest);

  final Change change;
  final OriginManifest manifest;
}

final class _Hold extends _Decision {
  const _Hold(this.reason, this.manifest, {this.rejectedAs});

  final HeldReason reason;
  final OriginManifest manifest;

  /// Also counted as a rejection (revoked above cutoff).
  final String? rejectedAs;
}

final class _Reject extends _Decision {
  const _Reject(this.reason);

  final String reason;
}

/// Per-origin send plan: stream `(declared, bound]`.
final class _OriginPlan {
  _OriginPlan(this.origin, this.declared, this.bound) : scanned = declared;

  final String origin;
  int declared;
  int scanned;
  int bound;
  bool done = false;
}

/// One side of one sync session (see the library documentation).
final class SyncSession {
  SyncSession(this.device, this._transport, {required this.initiator, this.expectedPeer, required this.hooks});

  final SyncDevice device;
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

  SyncStore get _store => device.store;

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
      return await _run();
    } catch (e) {
      _failure ??= e;
      await _channel?.abort();
      await _transport.close();
      final failure = _failure!;
      if (failure is _Abort && failure.category == SessionFailure.restoreDetected) {
        // D15: the local DB is behind what the peer holds of this origin.
        await device.switchOriginAfterPeerCursor(failure.peerCursor!);
      }
      return _failedResult(failure);
    } finally {
      _unregister();
    }
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
      throw _Abort(rejectedStatic ? SessionFailure.notAuthorized : SessionFailure.securityError);
    }
    _channel = channel;
    final peer = m.activeMemberByX25519(channel.remoteStatic);
    if (peer == null) throw const _Abort(SessionFailure.notAuthorized);
    _peerId = peer.memberId;
    _peerEd = Uint8List.fromList(peer.ed25519Pub);

    final Hello peerHello;
    if (initiator) {
      if (peer.memberId != expectedPeer) {
        // The address answered with another member's key (D7): continue
        // with that member; the address list is T20's concern.
        if (device.activeSessions.containsKey(peer.memberId)) throw const _Abort(SessionFailure.busy);
        _unregister();
        device.activeSessions[peer.memberId] = this;
      }
      final SyncMessage answer;
      try {
        answer = await channel.receive();
      } on TransportClosedException {
        throw const _Abort(SessionFailure.refusedByPeer);
      }
      switch (answer) {
        case Busy():
          throw const _Abort(SessionFailure.busy);
        case ErrorMessage(:final category):
          throw _Abort(
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
      ..bytesSent = channel.bytesSent;
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
  Future<T> _guard<T>(Future<T> future) =>
      Future.any([future, _failed.future.then<T>((_) => throw _failure ?? const _Abort(SessionFailure.internal))]);

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
    final m = device.membership;
    switch (message) {
      case OriginRegistry(:final entries):
        if (_registryReceived) throw const MalformedMessageException('second OriginRegistry');
        _registryReceived = true;
        if (await m.mergeRegistrations(entries, _store) > 0) await _onSecurityChange();
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
        throw _Abort(category == SyncErrorCategory.preparing ? SessionFailure.peerPreparing : SessionFailure.peerError);
      default:
        throw MalformedMessageException('unexpected ${message.type.name}');
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
      result.grants.forEach(device.recordGrant);
      if (result.grants.isNotEmpty) await m.rebuild(_store);
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
    _snapshot = _store.vector;
    final peerCursor = _peerVector[_store.localOrigin.hex] ?? 0;
    if (peerCursor > _store.nextSeq - 1) {
      await _send(channel, ErrorMessage(SyncErrorCategory.preparing));
      throw _Abort(SessionFailure.restoreDetected, peerCursor: peerCursor);
    }
    _peerVxReady.complete(vx);
  }

  // --- Writer ------------------------------------------------------------------------

  Future<void> _writer(SecureChannel channel) async {
    final m = device.membership;
    await _send(channel, OriginRegistry(_store.registrations));
    await _send(
      channel,
      VectorExchange(
        vector: {for (final e in _store.vector.entries) OriginId.fromHex(e.key): e.value},
        refetch: _refetchKeys(),
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
      handedOver.forEach(device.recordGrant);
      await m.rebuild(_store);
    }

    await _sendRefetch(channel, vx.refetch);
    await _stream(channel);

    final endId = _nextBatchId++;
    _endMarkerId = endId;
    await _sendBatch(channel, ChangeBatchMessage(batchId: endId, ranges: const {}), data: false);
    await _guard(_endAcked.future);
  }

  List<CellKey> _refetchKeys() {
    final keys = <CellKey>{};
    for (final h in _store.heldEnvelopes) {
      if (h.reason == HeldReason.applyFailed) keys.add(h.key);
    }
    return keys.toList();
  }

  /// Answers the peer's refetch list with current cells it already covers
  /// (newer ones are in the stream anyway).
  Future<void> _sendRefetch(SecureChannel channel, List<CellKey> refetch) async {
    final cells = <StoredCell>[];
    for (final key in refetch) {
      final cell = _store.storedCell(key);
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
        items.add((r.origin, r.originSeq, manifest, () => _seal(r), _estimate(r)));
    }
    for (final h in held) {
      if (h.seq > (_peerVector[h.origin] ?? 0)) continue;
      if (seen.add('${h.origin}#${h.seq}')) items.add((h.origin, h.seq, h.manifest, () => h.envelope, _heldSize(h)));
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
        final manifestSize = manifests.contains(manifest) ? 0 : _manifestSize(manifest);
        if (envelopes.isNotEmpty &&
            (envelopes.length >= config.maxBatchChanges || bytes + size + manifestSize > config.maxBatchBytes)) {
          break;
        }
        lo[origin] = math.min(lo[origin] ?? seq, seq);
        hi[origin] = math.max(hi[origin] ?? seq, seq);
        manifests.add(manifest);
        envelopes.add(build());
        bytes += size + manifestSize;
        i++;
      }
      sent += envelopes.length;
      await _sendBatch(
        channel,
        ChangeBatchMessage(
          batchId: _nextBatchId++,
          ranges: {for (final o in lo.keys) OriginId.fromHex(o): SeqRange(lo[o]! - 1, hi[o]!)},
          manifests: manifests.toList(),
          envelopes: envelopes,
        ),
      );
    }
    return sent;
  }

  static String _versionOf(CellRecord record) => '${record.origin}#${record.originSeq}';

  ChangeEnvelope _seal(CellRecord record) {
    final m = device.membership;
    final cipher =
        EnvelopeCipher(groupId: m.groupId!, keyring: m.keyring, protocolVersion: device.config.protocolVersion);
    return cipher.seal(Change.fromCellRecord(record, groupId: m.groupId!), _nonces);
  }

  Future<void> _stream(SecureChannel channel) async {
    final snapshot = _snapshot!;
    final own = _store.localOrigin.hex;
    final plans = [
      for (final o in snapshot.keys.toList()..sort())
        if (snapshot[o]! > (_peerVector[o] ?? 0)) _OriginPlan(o, _peerVector[o] ?? 0, snapshot[o]!),
    ];
    final config = device.config;
    var p = 0;
    while (p < plans.length && !_storageError) {
      final ranges = <OriginId, SeqRange>{};
      final manifests = <OriginManifest>{};
      final envelopes = <ChangeEnvelope>[];
      final versions = <String>{};
      var bytes = 64;
      var ownTo = 0;
      var full = false;
      bool overflows(int size, OriginManifest? manifest) {
        final manifestSize = manifest == null || manifests.contains(manifest) ? 0 : _manifestSize(manifest);
        return envelopes.isNotEmpty &&
            (envelopes.length >= config.maxBatchChanges || bytes + size + manifestSize > config.maxBatchBytes);
      }

      void addSigned(StoredCell cell) {
        final record = cell.record;
        final signedBy = cell.manifest ?? (throw StateError('own origin switched during the session'));
        bytes += _estimate(record) + (manifests.contains(signedBy) ? 0 : _manifestSize(signedBy));
        manifests.add(signedBy);
        envelopes.add(_seal(record));
        versions.add(_versionOf(record));
        if (record.origin == own) ownTo = math.max(ownTo, record.originSeq);
      }

      while (p < plans.length && !full) {
        final plan = plans[p];
        final from = plan.declared;
        while (true) {
          final cell = _store.nextCellOfOrigin(plan.origin, plan.scanned);
          final held = _store.nextHeldOfOrigin(plan.origin, plan.scanned);
          final cellSeq = cell?.record.originSeq;
          final heldSeq = held?.seq;
          final useCell = cellSeq != null && (heldSeq == null || cellSeq <= heldSeq);
          final seq = useCell ? cellSeq : heldSeq;
          if (seq == null || seq > plan.bound) {
            plan.done = true;
            break;
          }
          final size = useCell ? _estimate(cell!.record) : _heldSize(held!);
          final manifest = useCell ? cell!.manifest : held!.manifest;
          if (overflows(size, manifest)) {
            full = true;
            break;
          }
          if (useCell) {
            if (cell!.manifest == null) await _signOwnThrough(seq, plan.bound);
            final current = _store.storedCell(cell.record.key);
            // Superseded while signing: the next pass handles its seq as
            // superseded.
            if (current == null || !identical(current.record, cell.record)) continue;
            addSigned(current);
          } else {
            bytes += size + (manifests.contains(held!.manifest) ? 0 : _manifestSize(held.manifest));
            manifests.add(held.manifest);
            envelopes.add(held.envelope);
            versions.add('${plan.origin}#$seq');
            stats.heldRelayed++;
          }
          plan.scanned = seq;
        }
        final to = plan.done ? plan.bound : plan.scanned;
        if (to > from) {
          ranges[OriginId.fromHex(plan.origin)] = SeqRange(from, to);
          if (plan.origin == own) ownTo = math.max(ownTo, to);
        }
        plan
          ..declared = to
          ..scanned = to;
        if (plan.done) p++;
      }
      if (ranges.isEmpty) continue;
      final sent = await _sendBatch(
        channel,
        ChangeBatchMessage(
          batchId: _nextBatchId++,
          ranges: ranges,
          manifests: manifests.toList(),
          envelopes: envelopes,
        ),
        ownTo: ownTo,
      );
      if (!sent) return;
      stats.sentVersions.addAll(versions);
    }
    if (!_storageError) await _serveAboveCursor(channel);
  }

  /// Serves signed cells this store holds above its own cursor for their
  /// origin — after `local_reset` cleared the vector (D14), the retained
  /// security rows. Each goes in its own batch with the single-seq
  /// range `(seq − 1, seq]`, which moves a peer's cursor only when it is
  /// contiguous, so nothing is skipped.
  Future<void> _serveAboveCursor(SecureChannel channel) async {
    final snapshot = _snapshot!;
    final own = _store.localOrigin.hex;
    for (final origin in _store.cellOrigins.toList()..sort()) {
      if (origin == own) continue;
      final from = math.max(snapshot[origin] ?? 0, _peerVector[origin] ?? 0);
      var cell = _store.nextCellOfOrigin(origin, from);
      while (cell != null && !_storageError) {
        final record = cell.record;
        final manifest = cell.manifest;
        if (manifest != null) {
          await _sendBatch(
            channel,
            ChangeBatchMessage(
              batchId: _nextBatchId++,
              ranges: {OriginId.fromHex(origin): SeqRange(record.originSeq - 1, record.originSeq)},
              manifests: [manifest],
              envelopes: [_seal(record)],
            ),
          );
          stats.sentVersions.add('$origin#${record.originSeq}');
          stats.aboveCursorSent++;
        }
        cell = _store.nextCellOfOrigin(origin, record.originSeq);
      }
    }
  }

  /// Signs own manifests (≤ 1,000 consecutive seqs each) until [seq] is
  /// covered, never beyond the snapshot [bound] (D7: built at send time).
  Future<void> _signOwnThrough(int seq, int bound) async {
    final m = device.membership;
    while (_store.ownSignedTo < seq) {
      final from = _store.ownSignedTo;
      final to = math.min(from + SyncLimits.maxBatchChanges, bound);
      final origin = _store.localOrigin;
      final changes = [
        for (final r in _store.ownCellsInRange(from, to)) Change.fromCellRecord(r, groupId: m.groupId!),
      ];
      final signer = ManifestSigner(groupId: m.groupId!, origin: origin, signer: m.identity.ed25519);
      final signed = await signer.sign(fromSeq: from, toSeq: to, changes: changes);
      if (_store.localOrigin != origin) return;
      for (final manifest in signed) {
        _store.attachOwnManifest(manifest);
        stats.manifestsSigned++;
      }
    }
  }

  static int _estimate(CellRecord r) =>
      160 + r.key.table.length + r.key.pk.length * 2 + r.key.col.length + r.node.length + _valueSize(r.value);

  static int _valueSize(Object? value) => switch (value) {
        null => 0,
        int() => 8,
        String() => value.length * 3,
        Uint8List() => value.length,
        _ => ChangeValue.of(value).payload.length,
      };

  static int _heldSize(HeldEnvelope h) =>
      160 + h.envelope.tbl.length + h.envelope.pk.length * 2 + h.envelope.col.length + h.envelope.ciphertext.length;

  static int _manifestSize(OriginManifest m) => 104 + m.hashes.length * changeHashLength;

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
    final origin = _store.localOrigin;
    final mark = device.ledger.entryOf(origin)?.maxSentSeq ?? 0;
    if (seq <= mark) return true;
    final delays = device.config.sentMarkRetryDelays;
    for (var attempt = 0;; attempt++) {
      try {
        await device.ledger.persistSentMark(origin, seq, _store.hlc);
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
    final decisions = <(ChangeEnvelope, _Decision)>[
      for (final e in batch.envelopes) (e, _decide(e, batch.manifests, verdicts)),
    ];
    final applicable = [
      for (final (_, decision) in decisions)
        if (decision case _Apply(:final change)) change,
    ];
    // Without its revocation records in the ledger the batch is not committed
    // and its ranges do not move the cursor, so the peer sends it again.
    if (!await _retainRevocations(applicable)) {
      await _send(channel, BatchAck(batch.batchId));
      return;
    }
    // Commit: one synchronous step (the batch transaction); each item is
    // isolated (its own savepoint), a failed item does not hold back the
    // cursor (D15).
    final now = device.now();
    var securityTouched = false;
    for (final (envelope, decision) in decisions) {
      stats.envelopesReceived++;
      final origin = envelope.origin.hex;
      switch (decision) {
        case _Apply(:final change, :final manifest):
          switch (_store.applyRemote(change, manifest, nowMs: now)) {
            case ApplyOutcome.failed:
              _holdFailed(envelope, manifest, now);
            case ApplyOutcome.applied:
              stats.applied++;
              _store
                ..removeHeld(origin, envelope.originSeq)
                ..logCommit(origin, envelope.originSeq);
              if (SecurityTables.contains(change.tbl)) securityTouched = true;
            case ApplyOutcome.unchanged:
              stats.unchanged++;
              _store
                ..removeHeld(origin, envelope.originSeq)
                ..logCommit(origin, envelope.originSeq);
          }
        case _Hold(:final reason, :final manifest, :final rejectedAs):
          if (_store.heldAt(origin, envelope.originSeq) == null) {
            _store.putHeld(HeldEnvelope(
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
        case _Reject(:final reason):
          stats.reject(reason);
      }
    }
    for (final e in batch.ranges.entries) {
      final origin = e.key.hex;
      final range = e.value;
      _store.advanceCursor(origin, fromSeq: range.from, toSeq: range.to);
    }
    stats.batchesApplied++;
    if (securityTouched) await _onSecurityChange();
    await _send(channel, BatchAck(batch.batchId));
  }

  void _holdFailed(ChangeEnvelope envelope, OriginManifest manifest, int now) {
    final origin = envelope.origin.hex;
    final existing = _store.heldAt(origin, envelope.originSeq);
    if (existing != null) {
      existing
        ..reason = HeldReason.applyFailed
        ..failCount += 1
        ..peer = _peerId
        ..category = 'apply_failed';
    } else {
      _store.putHeld(HeldEnvelope(
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

  _Decision _decide(ChangeEnvelope envelope, List<OriginManifest> manifests, List<ManifestVerdict> verdicts) {
    final candidates = <int>[
      for (var i = 0; i < manifests.length; i++)
        if (manifests[i].origin == envelope.origin && manifests[i].coversSeq(envelope.originSeq)) i,
    ];
    if (candidates.isEmpty) return const _Reject('noManifest');
    return _decideWith(envelope, [for (final i in candidates) (manifests[i], verdicts[i])]);
  }

  /// Decides one envelope against candidate manifests (FR-021, FR-023,
  /// D7): apply, hold (missing key; signer not yet known; revoked above the
  /// current cutoff) or reject (tampered, not listed, wrong group...).
  _Decision _decideWith(ChangeEnvelope envelope, List<(OriginManifest, ManifestVerdict)> candidates) {
    final m = device.membership;
    OriginManifest? holdable;
    String? rejection;
    for (final (manifest, verdict) in candidates) {
      if (verdict is ManifestRejected) {
        if (verdict.reason == ManifestRejection.signerNotMember ||
            verdict.reason == ManifestRejection.unregisteredOrigin) {
          holdable ??= manifest;
        } else {
          rejection ??= verdict.reason.name;
        }
      } else {
        holdable ??= manifest;
      }
    }
    final cipher = EnvelopeCipher(groupId: m.groupId!, keyring: m.keyring);
    switch (cipher.open(envelope)) {
      case MissingEpochKey():
        if (holdable != null) return _Hold(HeldReason.missingKey, holdable);
        return _Reject(rejection ?? 'manifest');
      case EnvelopeRejected():
        return const _Reject('envelope');
      case EnvelopeOpened(:final change):
        OriginManifest? unverified;
        String? revoked;
        for (final (manifest, verdict) in candidates) {
          if (verdict is! VerifiedManifest) continue;
          // A flagged signer with no known cutoff waits for its revocation
          // record instead of being verified without one (U11/Efe-R1).
          if (m.isFlaggedWithoutRecord(verdict.signerPub)) {
            unverified ??= manifest;
            continue;
          }
          final check = m.verifier.checkChange(change, verdict);
          if (check.isAccepted) return _Apply(change, manifest);
          switch (check.rejection!) {
            case ManifestRejection.revokedAboveCutoff:
              unverified ??= manifest;
              revoked = 'revokedAboveCutoff';
            case ManifestRejection.signerNotMember || ManifestRejection.unregisteredOrigin:
              unverified ??= manifest;
            default:
              rejection ??= check.rejection!.name;
          }
        }
        if (unverified != null) return _Hold(HeldReason.unverified, unverified, rejectedAs: revoked);
        if (holdable != null && rejection == null) return _Hold(HeldReason.unverified, holdable);
        return _Reject(rejection ?? 'manifest');
    }
  }

  /// Retries held envelopes: after the peer's key handover (all reasons, the
  /// session-start retry of D15) and after membership or cutoff changes
  /// (missing key, unverified). Superseded entries leave the table.
  Future<void> _retryHeld({required bool includeApplyFailed}) async {
    for (var round = 0; round < 4; round++) {
      final m = device.membership;
      var securityTouched = false;
      for (final held in _store.heldEnvelopes) {
        if (_failure != null) return;
        if (!includeApplyFailed && held.reason == HeldReason.applyFailed) continue;
        if (_store.heldAt(held.origin, held.seq) != held) continue;
        if (_store.isSuperseded(held)) {
          _store.dropSupersededHeld(held);
          continue;
        }
        final verdict = await m.verifier.verify(held.manifest);
        if (_store.heldAt(held.origin, held.seq) != held) continue;
        final decision = _decideWith(held.envelope, [(held.manifest, verdict)]);
        final now = device.now();
        // A held revocation whose ledger write fails stays held for later.
        if (decision is _Apply && !await _retainRevocations([decision.change])) continue;
        switch (decision) {
          case _Apply(:final change, :final manifest):
            switch (_store.applyRemote(change, manifest, nowMs: now)) {
              case ApplyOutcome.failed:
                _holdFailed(held.envelope, manifest, now);
              case ApplyOutcome.applied || ApplyOutcome.unchanged:
                _store.removeHeld(held.origin, held.seq);
                stats.heldRetriedApplied++;
                if (SecurityTables.contains(change.tbl)) securityTouched = true;
            }
          case _Hold(:final reason, :final rejectedAs):
            held
              ..reason = held.reason == HeldReason.applyFailed ? held.reason : reason
              ..category = rejectedAs ?? held.category;
          case _Reject(:final reason):
            _store.removeHeld(held.origin, held.seq);
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
    final changed = await m.rebuild(_store);
    if (m.removed) throw const _Abort(SessionFailure.removedFromGroup);
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
    if (error is _Abort) {
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
  String toString() => 'SyncSession(${device.name}, ${initiator ? 'initiator' : 'responder'}, peer $_peerId)';
}
