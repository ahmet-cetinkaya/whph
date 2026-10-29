/// Building, signing and verifying per-origin change manifests (D7
/// "Change protection", FR-021, FR-023, SC-005 insider inject, SC-014).
///
/// * The author signs manifests of at most [SyncLimits.maxBatchChanges]
///   consecutive own seqs `(from, to]`; `hashes` lists
///   `BLAKE2b-256(canonical change)` of every cell of the range still held
///   (superseded seqs have no entry), in seq order. `sig` is the author's
///   Ed25519 signature over `OriginManifest.signingInput(groupId)` (T10,
///   domain `whph-sync/manifest/v1`).
/// * A receiver verifies the signature **once** per manifest with the key the
///   origin registry holds for that origin (so a manifest signed by any other
///   key fails), requires that key to be a known member, caches the verified
///   manifest, then checks each change: same group and origin, seq inside the
///   range, origin not revoked above its cutoff, canonical hash listed.
library;

import 'dart:typed_data';

import '../model/change.dart';
import '../model/ids.dart';
import '../model/manifest.dart';
import '../protocol/version.dart';
import 'origin_registry.dart';
import 'primitives.dart';
import 'revocation.dart';

/// Signs manifests for this device's own [origin].
final class ManifestSigner {
  ManifestSigner({required this.groupId, required this.origin, required Ed25519KeyPair signer}) : _signer = signer;

  final GroupId groupId;
  final OriginId origin;
  final Ed25519KeyPair _signer;

  /// Signs manifests covering `(fromSeq, toSeq]` in chunks of at most
  /// [SyncLimits.maxBatchChanges] seqs. [changes] are this origin's cells in
  /// the range that are still current (each seq at most once).
  Future<List<OriginManifest>> sign(
      {required int fromSeq, required int toSeq, required Iterable<Change> changes}) async {
    if (fromSeq < 0 || toSeq <= fromSeq) throw ArgumentError('empty or negative range ($fromSeq, $toSeq]');
    final bySeq = <int, Change>{};
    for (final c in changes) {
      if (c.groupId != groupId) throw ArgumentError.value(c.groupId, 'change.groupId', 'other group');
      if (c.origin != origin) throw ArgumentError.value(c.origin, 'change.origin', 'not this signer\'s origin');
      if (c.originSeq <= fromSeq || c.originSeq > toSeq) throw RangeError.range(c.originSeq, fromSeq + 1, toSeq);
      if (bySeq.containsKey(c.originSeq)) throw ArgumentError.value(c.originSeq, 'changes', 'duplicate seq');
      bySeq[c.originSeq] = c;
    }
    final seqs = bySeq.keys.toList()..sort();
    final out = <OriginManifest>[];
    var i = 0;
    for (var from = fromSeq; from < toSeq; from += SyncLimits.maxBatchChanges) {
      final to = (from + SyncLimits.maxBatchChanges) < toSeq ? from + SyncLimits.maxBatchChanges : toSeq;
      final hashes = <Uint8List>[];
      while (i < seqs.length && seqs[i] <= to) {
        hashes.add(bySeq[seqs[i]]!.canonicalHash());
        i++;
      }
      final unsigned = OriginManifest(
        origin: origin,
        fromSeq: from,
        toSeq: to,
        hashes: hashes,
        sig: Uint8List(signatureLength),
      );
      out.add(OriginManifest(
        origin: origin,
        fromSeq: from,
        toSeq: to,
        hashes: hashes,
        sig: await _signer.sign(unsigned.signingInput(groupId)),
      ));
    }
    return out;
  }

  @override
  String toString() => 'ManifestSigner($origin)';
}

/// Why a manifest or change was rejected (reason categories only).
enum ManifestRejection {
  unregisteredOrigin,
  conflictedOrigin,
  signerNotMember,
  badSignature,
  wrongGroup,
  originMismatch,
  seqOutsideManifest,
  revokedAboveCutoff,
  hashNotInManifest,
}

/// Result of [ManifestVerifier.verify].
sealed class ManifestVerdict {
  const ManifestVerdict();
}

/// A manifest whose signature verified with the registered key.
final class VerifiedManifest extends ManifestVerdict {
  VerifiedManifest._(this.manifest, this.signerPub) : _hashes = {for (final h in manifest.hashes) _HashKey(h)};

  final OriginManifest manifest;

  /// The registered member key that signed it.
  final Uint8List signerPub;
  final Set<_HashKey> _hashes;

  bool _lists(Uint8List hash) => _hashes.contains(_HashKey(hash));

  @override
  String toString() => 'VerifiedManifest($manifest)';
}

/// The manifest cannot be used; none of its changes is accepted.
final class ManifestRejected extends ManifestVerdict {
  const ManifestRejected(this.reason);

  final ManifestRejection reason;

  @override
  String toString() => 'ManifestRejected(${reason.name})';
}

/// Result of [ManifestVerifier.checkChange]: `null` reason = accepted.
final class ChangeVerdict {
  const ChangeVerdict._(this.rejection);

  static const accepted = ChangeVerdict._(null);

  final ManifestRejection? rejection;

  bool get isAccepted => rejection == null;

  @override
  String toString() => isAccepted ? 'ChangeAccepted' : 'ChangeRejected(${rejection!.name})';
}

/// Verifies manifests and their changes against the registry, membership and
/// revocations of one group.
final class ManifestVerifier {
  ManifestVerifier({
    required this.groupId,
    required this.registry,
    required this.revocations,
    required this.members,
    this.cacheLimit = 4096,
  });

  final GroupId groupId;
  final OriginRegistrySet registry;
  final RevocationSet revocations;
  final MemberDirectory members;

  /// Maximum cached verified manifests (the cache is cleared when full).
  final int cacheLimit;

  final Map<_HashKey, VerifiedManifest> _cache = {};

  /// Verifies [manifest]'s signature once (cached by its digest).
  Future<ManifestVerdict> verify(OriginManifest manifest) async {
    final owner = registry.ownerOf(manifest.origin);
    final Uint8List signer;
    switch (owner) {
      case OriginUnregistered():
        return const ManifestRejected(ManifestRejection.unregisteredOrigin);
      case OriginConflicted():
        return const ManifestRejected(ManifestRejection.conflictedOrigin);
      case OriginRegisteredTo(:final memberPub):
        signer = memberPub;
    }
    if (!members.isMember(signer)) return const ManifestRejected(ManifestRejection.signerNotMember);
    final input = manifest.signingInput(groupId);
    final digest = _HashKey(domainHash256('whph-sync/manifest-cache/v1', [input, manifest.sig, signer]));
    final cached = _cache[digest];
    if (cached != null) return cached;
    if (!await ed25519Verify(input, manifest.sig, signer)) {
      return const ManifestRejected(ManifestRejection.badSignature);
    }
    final verified = VerifiedManifest._(manifest, Uint8List.fromList(signer));
    if (_cache.length >= cacheLimit) _cache.clear();
    _cache[digest] = verified;
    return verified;
  }

  /// Checks one decrypted [change] against a [VerifiedManifest]. The
  /// registry, membership and revocation state are re-read on every call,
  /// so a revocation or conflict learned after verification applies.
  ChangeVerdict checkChange(Change change, VerifiedManifest manifest) {
    final m = manifest.manifest;
    if (change.groupId != groupId) return const ChangeVerdict._(ManifestRejection.wrongGroup);
    if (change.origin != m.origin) return const ChangeVerdict._(ManifestRejection.originMismatch);
    if (!m.coversSeq(change.originSeq)) return const ChangeVerdict._(ManifestRejection.seqOutsideManifest);
    switch (registry.ownerOf(change.origin)) {
      case OriginUnregistered():
        return const ChangeVerdict._(ManifestRejection.unregisteredOrigin);
      case OriginConflicted():
        return const ChangeVerdict._(ManifestRejection.conflictedOrigin);
      case OriginRegisteredTo(:final memberPub):
        if (!constantTimeEquals(memberPub, manifest.signerPub)) {
          return const ChangeVerdict._(ManifestRejection.badSignature);
        }
        if (!members.isMember(memberPub)) return const ChangeVerdict._(ManifestRejection.signerNotMember);
        final cutoff = revocations.cutoffOf(memberPub, change.origin);
        if (cutoff != null && change.originSeq > cutoff) {
          return const ChangeVerdict._(ManifestRejection.revokedAboveCutoff);
        }
    }
    if (!manifest._lists(change.canonicalHash())) return const ChangeVerdict._(ManifestRejection.hashNotInManifest);
    return ChangeVerdict.accepted;
  }

  @override
  String toString() => 'ManifestVerifier($groupId, ${_cache.length} cached)';
}

/// A 32-byte hash usable as a set/map key.
final class _HashKey {
  _HashKey(this.bytes) : _hash = _fold(bytes);

  final Uint8List bytes;
  final int _hash;

  static int _fold(Uint8List b) {
    var h = 0;
    for (var i = 0; i < 8 && i < b.length; i++) {
      h = (h << 8) | b[i];
    }
    return h ^ b.length;
  }

  @override
  bool operator ==(Object other) => other is _HashKey && other._hash == _hash && _eq(other.bytes, bytes);

  static bool _eq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _hash;
}
