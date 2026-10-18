/// Member revocation with per-origin cutoffs (D7, FR-026).
///
/// A record `(revoked_member_pub, revoker_pub, cutoffs {origin_id: seq},
/// sig)` is signed by the revoker over (big-endian; `str` = `u32 len ‖
/// UTF-8`):
///
/// ```text
/// str   "whph-sync/revocation/v1"
/// 16B   group_id
/// 32B   revoked_member_pub          Ed25519
/// 32B   revoker_pub                 Ed25519
/// u32   n
/// n × (16B origin ‖ i64 cutoff)     origins strictly ascending, cutoff >= 0
/// ```
///
/// Rules:
/// * Records are grow-only; a record is accepted when its signature verifies
///   and the revoker is a known member ([MemberDirectory]).
/// * The effective cutoff of an origin registered to a revoked member is the
///   **max** over all records of that member listing it; an origin no record
///   lists has cutoff 0. Changes with `origin_seq > cutoff` are rejected.
/// * Self-extension: a member that holds higher seqs of any origin of the
///   revoked member (listed or not) than the effective cutoff adds its own
///   record listing them ([RevocationSet.selfExtension]); since cutoffs merge
///   by max, every member converges on the same cutoffs and therefore the
///   same accepted set.
/// * Revocation triggers epoch rotation (see `epoch.dart`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/ids.dart';
import '../model/wire_bytes.dart';
import 'origin_registry.dart';
import 'primitives.dart';

/// Domain of the revocation signing input.
const revocationDomain = 'whph-sync/revocation/v1';

const _recordIdDomain = 'whph-sync/revocation-id/v1';

/// Answers whether an Ed25519 key belongs to a known member of the group
/// (current or revoked; revocation is handled by cutoffs).
/// Implementations must answer `false` for weak keys
/// ([isWeakEd25519PublicKey]).
abstract interface class MemberDirectory {
  bool isMember(List<int> ed25519Pub);
}

/// A [MemberDirectory] over a fixed set of keys. Weak keys
/// ([isWeakEd25519PublicKey]: small-order or non-canonical encodings) are
/// refused with [InvalidKeyMaterialException].
final class MemberKeySet implements MemberDirectory {
  MemberKeySet(Iterable<List<int>> keys) : _keys = {for (final k in keys) _checked(k)};

  final Set<String> _keys;

  void add(List<int> key) => _keys.add(_checked(key));

  static String _checked(List<int> key) {
    if (isWeakEd25519PublicKey(key)) throw const InvalidKeyMaterialException('weak Ed25519 member key');
    return _hex(key);
  }

  @override
  bool isMember(List<int> ed25519Pub) => !isWeakEd25519PublicKey(ed25519Pub) && _keys.contains(_hex(ed25519Pub));
}

/// A signed revocation record.
final class RevocationRecord {
  RevocationRecord({
    required List<int> revokedPub,
    required List<int> revokerPub,
    required Map<OriginId, int> cutoffs,
    required List<int> sig,
  })  : revokedPub = Uint8List.fromList(revokedPub).asUnmodifiableView(),
        revokerPub = Uint8List.fromList(revokerPub).asUnmodifiableView(),
        cutoffs = Map.unmodifiable(Map.fromEntries(cutoffs.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))),
        sig = Uint8List.fromList(sig).asUnmodifiableView() {
    if (this.revokedPub.length != keyLength) throw ArgumentError.value(revokedPub.length, 'revokedPub');
    if (this.revokerPub.length != keyLength) throw ArgumentError.value(revokerPub.length, 'revokerPub');
    if (this.sig.length != 64) throw ArgumentError.value(sig.length, 'sig');
    for (final c in this.cutoffs.values) {
      if (c < 0) throw ArgumentError.value(c, 'cutoffs', 'must be >= 0');
    }
  }

  final Uint8List revokedPub;
  final Uint8List revokerPub;

  /// Cutoffs sorted by origin.
  final Map<OriginId, int> cutoffs;
  final Uint8List sig;

  /// The canonical bytes signed by the revoker.
  static Uint8List signingInput({
    required GroupId groupId,
    required List<int> revokedPub,
    required List<int> revokerPub,
    required Map<OriginId, int> cutoffs,
  }) {
    final sorted = cutoffs.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final w = ByteWriter()
      ..string(revocationDomain)
      ..fixed(groupId.bytes)
      ..fixed(revokedPub)
      ..fixed(revokerPub)
      ..u32(sorted.length);
    for (final e in sorted) {
      if (e.value < 0) throw ArgumentError.value(e.value, 'cutoffs', 'must be >= 0');
      w
        ..fixed(e.key.bytes)
        ..i64(e.value);
    }
    return w.take();
  }

  /// Signs a record revoking [revokedPub] by [revoker].
  static Future<RevocationRecord> sign({
    required GroupId groupId,
    required List<int> revokedPub,
    required Ed25519KeyPair revoker,
    required Map<OriginId, int> cutoffs,
  }) async {
    final input =
        signingInput(groupId: groupId, revokedPub: revokedPub, revokerPub: revoker.publicKey, cutoffs: cutoffs);
    return RevocationRecord(
      revokedPub: revokedPub,
      revokerPub: revoker.publicKey,
      cutoffs: cutoffs,
      sig: await revoker.sign(input),
    );
  }

  // Every field is immutable, so a verification result can be memoized per
  // group on the instance (a record object shared across views is verified
  // once).
  final Map<GroupId, bool> _verified = {};

  /// Whether the signature is valid for [groupId].
  Future<bool> verify(GroupId groupId) async => _verified[groupId] ??= await ed25519Verify(
        signingInput(groupId: groupId, revokedPub: revokedPub, revokerPub: revokerPub, cutoffs: cutoffs),
        sig,
        revokerPub,
      );

  @override
  String toString() => 'RevocationRecord(${cutoffs.length} cutoffs)';
}

/// Outcome of [RevocationSet.merge].
final class RevocationMergeResult {
  const RevocationMergeResult(this.added, this.rejected, this.newlyRevoked);

  final int added;

  /// Invalid signature or revoker not a member.
  final int rejected;

  /// Keys that became revoked by this merge (callers rotate the epoch,
  /// check self-extension, and discard keys if one is their own).
  final List<Uint8List> newlyRevoked;
}

/// The grow-only set of revocation records of one group.
final class RevocationSet {
  RevocationSet(this.groupId);

  final GroupId groupId;
  final Map<String, List<RevocationRecord>> _byRevoked = {};
  final Set<String> _seen = {};

  List<RevocationRecord> get records => [for (final l in _byRevoked.values) ...l];

  /// Verifies and adds [records].
  Future<RevocationMergeResult> merge(Iterable<RevocationRecord> records, MemberDirectory members) async {
    var added = 0;
    var rejected = 0;
    final newly = <Uint8List>[];
    for (final r in records) {
      // Identity covers every signed field and the signature.
      final id = _hex(domainHash256(_recordIdDomain, [
        RevocationRecord.signingInput(
            groupId: groupId, revokedPub: r.revokedPub, revokerPub: r.revokerPub, cutoffs: r.cutoffs),
        r.sig,
      ]));
      if (_seen.contains(id)) continue;
      if (!members.isMember(r.revokerPub) || !await r.verify(groupId)) {
        rejected++;
        continue;
      }
      _seen.add(id);
      final key = _hex(r.revokedPub);
      final wasRevoked = _byRevoked.containsKey(key);
      _byRevoked.putIfAbsent(key, () => []).add(r);
      if (!wasRevoked) newly.add(Uint8List.fromList(r.revokedPub));
      added++;
    }
    return RevocationMergeResult(added, rejected, newly);
  }

  bool isRevoked(List<int> memberPub) => _byRevoked.containsKey(_hex(memberPub));

  /// Revoked member keys.
  List<Uint8List> get revokedMembers => [for (final l in _byRevoked.values) Uint8List.fromList(l.first.revokedPub)];

  /// Effective cutoff of [origin] of the revoked member [memberPub]: max over
  /// its records listing [origin], else 0. `null` when [memberPub] is not
  /// revoked (no cutoff).
  int? cutoffOf(List<int> memberPub, OriginId origin) {
    final list = _byRevoked[_hex(memberPub)];
    if (list == null) return null;
    var cutoff = 0;
    for (final r in list) {
      final c = r.cutoffs[origin];
      if (c != null && c > cutoff) cutoff = c;
    }
    return cutoff;
  }

  /// Cutoff of [origin] resolved through [registry]: `null` when the origin
  /// belongs to a non-revoked member (no limit), 0 when unregistered or
  /// conflicted (nothing accepted).
  int? cutoffFor(OriginId origin, OriginRegistrySet registry) => switch (registry.ownerOf(origin)) {
        OriginRegisteredTo(:final memberPub) => cutoffOf(memberPub, origin),
        OriginUnregistered() || OriginConflicted() => 0,
      };

  /// Whether a change `(origin, seq)` passes the registry and revocation
  /// rules (the manifest check is separate).
  bool accepts(OriginId origin, int seq, OriginRegistrySet registry) {
    final cutoff = cutoffFor(origin, registry);
    return cutoff == null || seq <= cutoff;
  }

  /// The cutoffs a revoker lists when revoking [revokedPub]: every origin
  /// registered to it with the max seq held here ([heldMaxSeq], 0 if none).
  static Map<OriginId, int> initialCutoffs(
    List<int> revokedPub,
    OriginRegistrySet registry,
    int Function(OriginId origin) heldMaxSeq,
  ) =>
      {for (final o in registry.originsOf(revokedPub)) o: heldMaxSeq(o)};

  /// Self-extension (D7): for each revoked member, the origins registered to
  /// it for which this member holds a higher seq than the effective cutoff,
  /// with the held seq. Each non-empty entry is signed by the caller as its
  /// own [RevocationRecord] and merged/synced.
  Map<Uint8List, Map<OriginId, int>> selfExtension(
      OriginRegistrySet registry, int Function(OriginId origin) heldMaxSeq) {
    final out = <Uint8List, Map<OriginId, int>>{};
    for (final list in _byRevoked.values) {
      final revoked = list.first.revokedPub;
      final ext = <OriginId, int>{};
      for (final o in registry.originsOf(revoked)) {
        final held = heldMaxSeq(o);
        if (held > (cutoffOf(revoked, o) ?? 0)) ext[o] = held;
      }
      if (ext.isNotEmpty) out[Uint8List.fromList(revoked)] = ext;
    }
    return out;
  }

  /// Publish-what-you-enforce (card B.2): per revoked member, the cutoffs of
  /// records [isServed] says no peer can fetch (their carrier is stranded on
  /// a sealed origin, or lost to a restore), so the caller re-signs them under
  /// its own key on its live origin. Only records [isAuthoredHere] returns
  /// `true` for are considered (C1/C2: never re-issue another device's
  /// record, only this device's own authoring), and a record already covered
  /// by a servable record of the same revoked member is skipped (idempotent,
  /// C3). Cutoffs of unserved records merge by max per origin.
  Map<Uint8List, Map<OriginId, int>> unpublished({
    required bool Function(RevocationRecord record) isServed,
    required bool Function(RevocationRecord record) isAuthoredHere,
  }) {
    final out = <Uint8List, Map<OriginId, int>>{};
    for (final list in _byRevoked.values) {
      final revoked = list.first.revokedPub;
      final servedCutoffs = <OriginId, int>{};
      for (final r in list.where(isServed)) {
        r.cutoffs.forEach((o, c) => servedCutoffs[o] = math.max(servedCutoffs[o] ?? 0, c));
      }
      final stranded = list.where((r) => !isServed(r) && isAuthoredHere(r)).toList();
      final hasServed = list.any(isServed);
      final missing = <OriginId, int>{};
      for (final r in stranded) {
        r.cutoffs.forEach((o, c) {
          if (c > (servedCutoffs[o] ?? 0)) missing[o] = math.max(missing[o] ?? 0, c);
        });
      }
      // A cutoff-free record still revokes: it needs a servable copy too.
      if (missing.isNotEmpty || (stranded.isNotEmpty && !hasServed)) out[Uint8List.fromList(revoked)] = missing;
    }
    return out;
  }

  @override
  String toString() => 'RevocationSet(${_byRevoked.length} revoked)';
}

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
