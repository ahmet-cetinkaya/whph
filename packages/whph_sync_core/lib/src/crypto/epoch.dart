/// Group-key epochs, key handover and the re-rotation rule (D7).
///
/// * Epoch id `(counter, creator member id)` is totally ordered by
///   [EpochId.compareTo] (counter, then creator id); the highest known epoch
///   is the one used to seal new envelopes. Counters are bounded by
///   [EpochId.maxCounter]; [EpochRules.next] throws [EpochCounterException]
///   instead of wrapping.
/// * Key material lives only in the key file (T20) and in a [GroupKeyring];
///   it is never synced. What is synced is an [EpochGrant]
///   `(epoch, member_pub)` recording that `member_pub` holds (was handed,
///   handed over, or created) the key.
/// * Handover, giving side: inside an authenticated session, a member hands
///   the peer the epoch keys it lacks, after checking the peer is not revoked
///   ([GroupKeyring.handoverTo]).
/// * Handover, receiving side: received keys go through
///   [GroupKeyring.acceptHandover] (never [GroupKeyring.add]). It records a
///   grant for the receiver, for the **sender** (it proved possession by
///   sending the key) and for the epoch's **creator** (who necessarily holds
///   it). Every key that ever held an epoch is therefore named by some grant
///   row that reaches the group through an honest member, even when the
///   creator — e.g. a member about to be removed — planted the epoch without
///   a self-grant. A handed-over epoch whose counter is more than
///   [EpochRules.maxCounterJump] above the highest epoch held before the
///   handover is not stored but reported in [HandoverAcceptResult.skipped]
///   (never thrown: the rest of the handover is stored). An insider cannot
///   exhaust the counter space, and a chain of within-bound jumps through an
///   honest member only delays its peers: each later session stores the next
///   `maxCounterJump` window, so they catch up. An empty keyring (joining at
///   pairing) accepts any bounded counter; only a malicious inviter can
///   isolate a joiner that way.
/// * Colliding epoch ids: a handed-over key for an epoch id already held with
///   a **different** key never replaces the held key and never throws: the
///   first key is kept, the epoch is marked conflicted
///   ([GroupKeyring.conflictedEpochs]) and, while it is the highest held
///   epoch, [EpochRules.mustRotate] fires past it, so the group converges
///   on a fresh epoch every member holds with the same key.
/// * Re-rotation rule ([EpochRules.mustRotate]): a member rotates when its
///   highest **held** epoch was granted to a now-revoked key or is
///   conflicted. Rotation creates `(max(highest held counter, ledger
///   counter floor) + 1, me)` and the caller records a self-grant. Epochs
///   known only from grant rows (not held) never trigger or shape a
///   rotation: a phantom grant row cannot force partitions or rotation
///   storms. Concurrent rotations produce
///   several epochs with the same counter; the creator id breaks the tie
///   deterministically, so all members converge on one highest epoch. The
///   rule re-fires until the highest held epoch is not flagged, and each
///   firing raises the counter, so convergence follows once revocations have
///   propagated (no new grants to revoked keys can then be made).
/// * **Engine contract (D7):** rotate when your highest held epoch was
///   granted to a newly revoked key (or is conflicted). The grant-based rule
///   is what makes convergence independent of who learned of the revocation
///   first.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/ids.dart';
import '../protocol/messages.dart';
import 'primitives.dart';

/// A synced grant row: [memberPub] (Ed25519 member key) holds the key of
/// [epoch]. Carries no key material.
final class EpochGrant {
  EpochGrant(this.epoch, List<int> memberPub) : memberPub = Uint8List.fromList(memberPub).asUnmodifiableView() {
    if (this.memberPub.length != keyLength) throw ArgumentError.value(memberPub.length, 'memberPub');
  }

  final EpochId epoch;
  final Uint8List memberPub;

  @override
  bool operator ==(Object other) =>
      other is EpochGrant && other.epoch == epoch && constantTimeEquals(other.memberPub, memberPub);

  @override
  int get hashCode => Object.hash(epoch, Object.hashAll(memberPub));

  @override
  String toString() => 'EpochGrant($epoch)';
}

/// Pure epoch rules shared by the membership service (T20) and the engine.
abstract final class EpochRules {
  /// Largest accepted distance between a handed-over epoch counter and the
  /// highest counter held before the handover (2^16).
  static const maxCounterJump = 0x10000;

  /// The first epoch of a new group, created by the inviter (D7).
  static EpochId initial(String creatorMemberId) => EpochId(1, creatorMemberId);

  /// The epoch a rotation by [creatorMemberId] creates over [highest] and
  /// [counterFloor] (the highest counter this device ever created, from its
  /// sync ledger; U11 G1). Throws [EpochCounterException] when the base
  /// counter is at [EpochId.maxCounter] (never wraps).
  static EpochId next(EpochId? highest, String creatorMemberId, {int counterFloor = 0}) {
    final counter = math.max(highest?.counter ?? 0, counterFloor);
    if (counter >= EpochId.maxCounter) throw const EpochCounterException('epoch counter exhausted');
    return EpochId(counter + 1, creatorMemberId);
  }

  /// The highest of [epochs], or `null` when empty.
  static EpochId? highest(Iterable<EpochId> epochs) {
    EpochId? best;
    for (final e in epochs) {
      if (best == null || e.compareTo(best) > 0) best = e;
    }
    return best;
  }

  /// Whether [epoch] was ever granted to a key for which [isRevoked] holds.
  static bool grantedToRevoked(EpochId epoch, Iterable<EpochGrant> grants, bool Function(Uint8List pub) isRevoked) =>
      grants.any((g) => g.epoch == epoch && isRevoked(g.memberPub));

  /// The re-rotation rule (see the library documentation): a member rotates
  /// when the highest of its [heldEpochs] (epochs whose key it holds) was
  /// granted to a now-revoked key or is in [conflictedEpochs]
  /// ([GroupKeyring.conflictedEpochs]). [knownEpochs] is **ignored** (kept
  /// for source compatibility): epochs known only from grant rows never
  /// force a rotation.
  static bool mustRotate({
    Iterable<EpochId> knownEpochs = const [],
    required Set<EpochId> heldEpochs,
    required Iterable<EpochGrant> grants,
    required bool Function(Uint8List pub) isRevoked,
    Set<EpochId> conflictedEpochs = const {},
  }) {
    final topHeld = highest(heldEpochs);
    if (topHeld == null) return false;
    return conflictedEpochs.contains(topHeld) || grantedToRevoked(topHeld, grants, isRevoked);
  }
}

/// Outcome of [GroupKeyring.acceptHandover].
final class HandoverAcceptResult {
  HandoverAcceptResult._(this.added, this.conflicted, this.grants, this.skipped);

  /// Epochs whose key was newly stored.
  final List<EpochId> added;

  /// Epochs already held with a **different** key. The held key was kept and
  /// the epoch is now in [GroupKeyring.conflictedEpochs].
  final List<EpochId> conflicted;

  /// Grant rows the caller records (syncs): for every handed-over epoch the
  /// receiver, the sender and (when resolvable) the creator; none for
  /// [skipped] epochs.
  final List<EpochGrant> grants;

  /// Handed-over epochs not stored because their counter is more than
  /// [EpochRules.maxCounterJump] above the highest counter held before the
  /// handover. No grant is recorded for them; a later handover (after the
  /// lower epochs were stored) delivers them.
  final List<EpochId> skipped;

  @override
  String toString() =>
      'HandoverAcceptResult(${added.length} added, ${conflicted.length} conflicted, ${skipped.length} skipped)';
}

/// The epoch keys this device holds (secret). Keys are copied in and zeroed
/// by [destroy]; [toString] never prints them.
final class GroupKeyring {
  final Map<EpochId, Uint8List> _keys = {};
  final Set<EpochId> _conflicted = {};
  bool _destroyed = false;

  /// Adds the key of [epoch] (copied), e.g. when loading the key file.
  /// Returns `false` and keeps the existing key when [epoch] is already held
  /// with the same key; throws when a different key is offered for a held
  /// epoch (never silently replaced). Keys received from a peer go through
  /// [acceptHandover] instead, which never throws on a collision.
  bool add(EpochId epoch, List<int> key) {
    _checkAlive();
    if (key.length != EpochKeyGrant.keyLength) throw const InvalidKeyMaterialException('epoch key must be 32 bytes');
    final existing = _keys[epoch];
    if (existing != null) {
      if (constantTimeEquals(existing, key)) return false;
      throw const InvalidKeyMaterialException('conflicting key for a held epoch');
    }
    _keys[epoch] = Uint8List.fromList(key);
    return true;
  }

  /// The id [rotate] creates with the same arguments. Lets the caller persist
  /// the new counter (sync ledger) before the key exists.
  EpochId nextEpoch(String creatorMemberId, {int counterFloor = 0}) =>
      EpochRules.next(highest, creatorMemberId, counterFloor: counterFloor);

  /// Creates `max(highest held counter, counterFloor) + 1` with a fresh
  /// random key; returns its id. [counterFloor] is the highest counter this
  /// device ever created (sync ledger), so a rolled-back key file cannot
  /// re-create an epoch id. The caller records `EpochGrant(id, ownPub)`
  /// (self-grant) and persists the key (T20). Epochs known only from grant
  /// rows never shape the new counter. Throws [EpochCounterException] when
  /// the counter space is exhausted.
  EpochId rotate(String creatorMemberId, {int counterFloor = 0}) {
    _checkAlive();
    final id = nextEpoch(creatorMemberId, counterFloor: counterFloor);
    final key = secureRandomBytes(EpochKeyGrant.keyLength);
    _keys[id] = key;
    return id;
  }

  bool holds(EpochId epoch) => _keys.containsKey(epoch);

  Set<EpochId> get epochs => Set.unmodifiable(_keys.keys);

  /// The highest held epoch.
  EpochId? get highest => EpochRules.highest(_keys.keys);

  /// Read-only view of the key of [epoch], or `null`. Do not retain it.
  Uint8List? keyFor(EpochId epoch) {
    _checkAlive();
    return _keys[epoch]?.asUnmodifiableView();
  }

  /// Builds the key handover for a peer whose Ed25519 key is [peerPub] and
  /// that holds [peerHas]. Returns nothing when [peerIsRevoked] is `true`
  /// (D7: check before handing over). The returned grants carry key copies:
  /// the caller zeroes them after encoding; the [EpochGrant] rows must be
  /// recorded (synced) for each handed-over epoch.
  (List<EpochKeyGrant>, List<EpochGrant>) handoverTo({
    required List<int> peerPub,
    required Set<EpochId> peerHas,
    required bool peerIsRevoked,
  }) {
    _checkAlive();
    if (peerIsRevoked) return (const [], const []);
    final epochs = _keys.keys.where((e) => !peerHas.contains(e)).toList()..sort();
    return (
      [for (final e in epochs) EpochKeyGrant(epoch: e, key: _keys[e]!)],
      [for (final e in epochs) EpochGrant(e, peerPub)],
    );
  }

  /// Stores the epoch keys a peer handed over in an authenticated session.
  ///
  /// [fromPub] is the sender's Ed25519 member key, [ownPub] this member's;
  /// [creatorPubOf] resolves an epoch creator's member id to its Ed25519 key
  /// (`null` when unknown). A key of the wrong length throws
  /// [InvalidKeyMaterialException] and stores nothing. Epochs whose counter
  /// exceeds the highest counter held **before this call** by more than
  /// [EpochRules.maxCounterJump] are not stored, get no grant and are
  /// returned in [HandoverAcceptResult.skipped] (never thrown); the others
  /// are stored. An empty keyring accepts any bounded counter. A key colliding with a held epoch keeps the held key and marks
  /// the epoch conflicted (see the library documentation). The caller records
  /// the returned [HandoverAcceptResult.grants] and zeroes [keys].
  HandoverAcceptResult acceptHandover({
    required List<int> fromPub,
    required List<int> ownPub,
    required Iterable<EpochKeyGrant> keys,
    Uint8List? Function(String memberId)? creatorPubOf,
  }) {
    _checkAlive();
    final list = keys.toList();
    for (final k in list) {
      if (k.key.length != EpochKeyGrant.keyLength)
        throw const InvalidKeyMaterialException('epoch key must be 32 bytes');
    }
    final topHeld = highest;
    final limit = topHeld == null ? null : topHeld.counter + EpochRules.maxCounterJump;
    final added = <EpochId>[];
    final conflicted = <EpochId>[];
    final skipped = <EpochId>{};
    final grants = <EpochGrant>{};
    for (final k in list) {
      final e = k.epoch;
      if (limit != null && e.counter > limit) {
        skipped.add(e);
        continue;
      }
      final existing = _keys[e];
      if (existing == null) {
        _keys[e] = Uint8List.fromList(k.key);
        added.add(e);
      } else if (!constantTimeEquals(existing, k.key)) {
        if (_conflicted.add(e)) conflicted.add(e);
      }
      grants
        ..add(EpochGrant(e, ownPub))
        ..add(EpochGrant(e, fromPub));
      final creator = creatorPubOf?.call(e.creator);
      if (creator != null) grants.add(EpochGrant(e, creator));
    }
    return HandoverAcceptResult._(
      List.unmodifiable(added),
      List.unmodifiable(conflicted),
      List.unmodifiable(grants),
      List.unmodifiable(skipped),
    );
  }

  /// Held epochs for which a peer offered a different key (pass to
  /// [EpochRules.mustRotate]).
  Set<EpochId> get conflictedEpochs => Set.unmodifiable(_conflicted);

  /// Removes and zeroes every key (e.g. "removed from group", group switch).
  void destroy() {
    for (final k in _keys.values) {
      zeroize(k);
    }
    _keys.clear();
    _conflicted.clear();
    _destroyed = true;
  }

  void _checkAlive() {
    if (_destroyed) throw StateError('keyring destroyed');
  }

  /// Epoch ids only; never key bytes.
  @override
  String toString() => 'GroupKeyring(${_keys.length} epochs)';
}
