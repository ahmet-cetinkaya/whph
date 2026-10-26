/// Signed per-origin change manifests (D7 "Change protection").
///
/// Manifest signing input v1 (big-endian; `str` = `u32 len ‖ UTF-8`):
///
/// ```text
/// str   "whph-sync/manifest/v1"
/// 16B   group_id
/// 16B   origin
/// i64   from_seq                     exclusive lower bound
/// i64   to_seq                       inclusive upper bound
/// u32   n                            number of hashes
/// n×32B hashes                       BLAKE2b-256 of canonical changes
/// ```
///
/// Wire form (inside a change batch; the group is implicit in the session):
/// `16B origin ‖ i64 from_seq ‖ i64 to_seq ‖ u32 n ‖ n×32B hashes ‖ 64B sig`.
library;

import 'dart:typed_data';

import '../protocol/errors.dart';
import '../protocol/version.dart';
import 'change.dart';
import 'ids.dart';
import 'wire_bytes.dart';

/// Domain-separation prefix of the manifest signing input.
const manifestSigningDomain = 'whph-sync/manifest/v1';

/// Length of an Ed25519 signature.
const signatureLength = 64;

/// The author's signed list of change hashes for its own seqs `(fromSeq, toSeq]`.
///
/// Seqs of the range whose cell was superseded before signing have no hash,
/// so `hashes.length <= toSeq - fromSeq`; a range spans at most
/// [SyncLimits.maxBatchChanges] seqs.
final class OriginManifest {
  OriginManifest({
    required this.origin,
    required this.fromSeq,
    required this.toSeq,
    required List<Uint8List> hashes,
    required List<int> sig,
  })  : hashes = List.unmodifiable([for (final h in hashes) Uint8List.fromList(h).asUnmodifiableView()]),
        sig = Uint8List.fromList(sig).asUnmodifiableView() {
    final problem = _problem(fromSeq, toSeq, this.hashes.length, this.sig.length);
    if (problem != null) throw ArgumentError(problem);
    for (final h in this.hashes) {
      if (h.length != changeHashLength) throw ArgumentError.value(h.length, 'hashes', 'each hash is 32 bytes');
    }
  }

  final OriginId origin;
  final int fromSeq;
  final int toSeq;
  final List<Uint8List> hashes;

  /// Author's Ed25519 signature over [signingInput] (produced/verified in T11).
  final Uint8List sig;

  /// Canonical bytes signed by the author: `(group_id, origin, from_seq,
  /// to_seq, hashes)`.
  Uint8List signingInput(GroupId groupId) {
    final w = ByteWriter()
      ..string(manifestSigningDomain)
      ..fixed(groupId.bytes)
      ..fixed(origin.bytes)
      ..i64(fromSeq)
      ..i64(toSeq);
    _writeHashes(w, hashes);
    return w.take();
  }

  /// Whether [hash] is listed.
  bool containsHash(List<int> hash) => hashes.any((h) => bytesEqual(h, hash));

  /// Whether `seq` lies in `(fromSeq, toSeq]`.
  bool coversSeq(int seq) => seq > fromSeq && seq <= toSeq;

  void writeTo(ByteWriter w) {
    w
      ..fixed(origin.bytes)
      ..i64(fromSeq)
      ..i64(toSeq);
    _writeHashes(w, hashes);
    w.fixed(sig);
  }

  static OriginManifest readFrom(ByteReader r) {
    final origin = OriginId(r.fixed(Id128.length, 'manifest origin'));
    final fromSeq = r.seq('manifest from_seq');
    final toSeq = r.seq('manifest to_seq');
    final n = r.u32('manifest hash count');
    if (n > SyncLimits.maxBatchChanges) throw BatchTooLargeException(n, SyncLimits.maxBatchChanges);
    if (n * changeHashLength > r.remaining) throw const TruncatedMessageException('manifest hashes');
    final hashes = [for (var i = 0; i < n; i++) r.fixed(changeHashLength, 'manifest hash')];
    final sig = r.fixed(signatureLength, 'manifest sig');
    final problem = _problem(fromSeq, toSeq, n, sig.length);
    if (problem != null) throw MalformedMessageException(problem);
    return OriginManifest(origin: origin, fromSeq: fromSeq, toSeq: toSeq, hashes: hashes, sig: sig);
  }

  static String? _problem(int fromSeq, int toSeq, int hashCount, int sigLength) {
    if (fromSeq < 0 || toSeq <= fromSeq) return 'manifest range ($fromSeq, $toSeq] is empty or negative';
    if (toSeq - fromSeq > SyncLimits.maxBatchChanges) {
      return 'manifest range spans ${toSeq - fromSeq} seqs (max ${SyncLimits.maxBatchChanges})';
    }
    if (hashCount > toSeq - fromSeq) return 'manifest lists $hashCount hashes for ${toSeq - fromSeq} seqs';
    if (sigLength != signatureLength) return 'manifest sig must be $signatureLength bytes';
    return null;
  }

  static void _writeHashes(ByteWriter w, List<Uint8List> hashes) {
    w.u32(hashes.length);
    for (final h in hashes) {
      w.fixed(h);
    }
  }

  /// Equal when authored identically: the author's signature covers origin,
  /// range and hashes, so equal signatures over equal ranges are the same
  /// manifest (a forged copy fails verification instead). Batches collect manifests in sets, and without value equality
  /// every cell of one range carried its own copy (T28: 32 KB per cell).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OriginManifest &&
      other.fromSeq == fromSeq &&
      other.toSeq == toSeq &&
      other.origin == origin &&
      other.hashes.length == hashes.length &&
      bytesEqual(other.sig, sig);

  @override
  int get hashCode => Object.hash(origin, fromSeq, toSeq);

  @override
  String toString() => 'OriginManifest($origin, ($fromSeq, $toSeq], ${hashes.length} hashes)';
}
