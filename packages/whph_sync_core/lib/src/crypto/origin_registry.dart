/// The self-authenticating, grow-only origin registry `sync_origin` (D7).
///
/// Signing input v1 (big-endian; `str` = `u32 len ‖ UTF-8`):
///
/// ```text
/// str   "whph-sync/origin/v1"
/// 16B   group_id
/// 16B   origin_id
/// 32B   member_ed25519_pub
/// i64   created_hlc
/// ```
///
/// `sig` is the member's Ed25519 signature over it, so a row proves that the
/// holder of `member_pub` claimed the origin in this group; relays cannot
/// forge or re-attribute it.
///
/// Merge is a set union of valid rows (grow-only), hence order-independent.
/// Resolution per origin considers only rows whose key is a known member key
/// ([MemberDirectory]; revoked members still count, they are resolved via
/// cutoffs). Rows signed by any other key are stored (membership may be
/// learned later) but are no claim, so a non-member cannot squat or block an
/// origin:
/// * no member row → [OriginUnregistered];
/// * member rows naming one key → the origin belongs to that key (duplicates
///   with different `created_hlc` are harmless);
/// * rows naming **different** keys (only a malicious member can produce a
///   claim for an origin id it did not generate) → the origin is
///   [OriginConflicted] and no change of it is accepted anywhere, so a
///   squatter can never have changes attributed to its key and every replica
///   reaches the same decision regardless of arrival order.
library;

import 'dart:typed_data';

import '../model/ids.dart';
import '../model/wire_bytes.dart';
import '../protocol/messages.dart';
import 'primitives.dart';
import 'revocation.dart';

/// Domain of the origin registration signing input.
const originRegistrationDomain = 'whph-sync/origin/v1';

/// Canonical bytes signed by an origin registration.
Uint8List originRegistrationSigningInput({
  required GroupId groupId,
  required OriginId origin,
  required List<int> memberPub,
  required int createdHlc,
}) {
  if (memberPub.length != keyLength) throw ArgumentError.value(memberPub.length, 'memberPub');
  return (ByteWriter()
        ..string(originRegistrationDomain)
        ..fixed(groupId.bytes)
        ..fixed(origin.bytes)
        ..fixed(memberPub)
        ..i64(createdHlc))
      .take();
}

/// Signs a registration of [origin] by [member] in [groupId].
Future<OriginRegistration> signOriginRegistration({
  required GroupId groupId,
  required OriginId origin,
  required Ed25519KeyPair member,
  required int createdHlc,
}) async {
  final input = originRegistrationSigningInput(
    groupId: groupId,
    origin: origin,
    memberPub: member.publicKey,
    createdHlc: createdHlc,
  );
  return OriginRegistration(
    origin: origin,
    memberPub: member.publicKey,
    createdHlc: createdHlc,
    sig: await member.sign(input),
  );
}

/// Whether [registration]'s signature is valid for [groupId].
Future<bool> verifyOriginRegistration(GroupId groupId, OriginRegistration registration) => ed25519Verify(
      originRegistrationSigningInput(
        groupId: groupId,
        origin: registration.origin,
        memberPub: registration.memberPub,
        createdHlc: registration.createdHlc,
      ),
      registration.sig,
      registration.memberPub,
    );

/// Owner of an origin as resolved by the registry.
sealed class OriginOwner {
  const OriginOwner();
}

/// No valid row by a member key registers the origin.
final class OriginUnregistered extends OriginOwner {
  const OriginUnregistered();
}

/// The origin belongs to [memberPub].
final class OriginRegisteredTo extends OriginOwner {
  const OriginRegisteredTo(this.memberPub);

  final Uint8List memberPub;
}

/// Valid rows by member keys name different keys; nothing of this origin is
/// accepted.
final class OriginConflicted extends OriginOwner {
  const OriginConflicted();
}

/// Outcome of [OriginRegistrySet.merge].
final class OriginMergeResult {
  const OriginMergeResult(this.added, this.rejected);

  /// Rows newly stored.
  final int added;

  /// Rows dropped because their signature did not verify.
  final int rejected;

  @override
  String toString() => 'OriginMergeResult(added: $added, rejected: $rejected)';
}

/// In-memory form of `sync_origin` for one group. Ownership is resolved
/// against [members] (read live on every call).
final class OriginRegistrySet {
  OriginRegistrySet(this.groupId, {required this.members});

  final GroupId groupId;

  /// Known member keys (current and revoked).
  final MemberDirectory members;

  // origin → rows keyed by `hex(member_pub) + created_hlc` (set semantics).
  final Map<OriginId, Map<String, OriginRegistration>> _rows = {};

  /// Every stored row (to send first in every session, D7).
  List<OriginRegistration> get entries => [for (final m in _rows.values) ...m.values];

  /// Verifies and adds [rows]; invalid signatures are dropped.
  Future<OriginMergeResult> merge(Iterable<OriginRegistration> rows) async {
    var added = 0;
    var rejected = 0;
    for (final row in rows) {
      final key = '${_hex(row.memberPub)}:${row.createdHlc}';
      final existing = _rows[row.origin]?[key];
      if (existing != null && constantTimeEquals(existing.sig, row.sig)) continue;
      if (!await verifyOriginRegistration(groupId, row)) {
        rejected++;
        continue;
      }
      // Ed25519 signatures of one input are deterministic for an honest
      // signer; a second valid signature over the same input changes nothing.
      if (existing != null) continue;
      _rows.putIfAbsent(row.origin, () => {})[key] = row;
      added++;
    }
    return OriginMergeResult(added, rejected);
  }

  /// The owner of [origin]; rows by non-member keys are ignored.
  OriginOwner ownerOf(OriginId origin) {
    final rows = _rows[origin];
    if (rows == null) return const OriginUnregistered();
    Uint8List? first;
    for (final r in rows.values) {
      if (!members.isMember(r.memberPub)) continue;
      if (first == null) {
        first = r.memberPub;
      } else if (!constantTimeEquals(r.memberPub, first)) {
        return const OriginConflicted();
      }
    }
    return first == null ? const OriginUnregistered() : OriginRegisteredTo(first);
  }

  /// Origins registered (without conflict) to [memberPub].
  List<OriginId> originsOf(List<int> memberPub) => [
        for (final origin in _rows.keys)
          if (ownerOf(origin) case OriginRegisteredTo(memberPub: final owner) when constantTimeEquals(owner, memberPub))
            origin,
      ];

  @override
  String toString() => 'OriginRegistrySet($groupId, ${_rows.length} origins)';
}

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
