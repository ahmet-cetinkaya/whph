/// Cell encodings of the synced security rows (D13): `sync_member`,
/// `sync_revocation`, `sync_epoch_grant`.
///
/// Each row is a row-level table with one `*` cell whose value is the record
/// bytes below (big-endian; `str` = `u32 len ‖ UTF-8`). Rows travel as
/// ordinary changes, so they are encrypted and covered by the author's signed
/// manifest like any user change (D7); revocation records additionally carry
/// the revoker's own signature.
///
/// ```text
/// member     "whph-sync/member/v1" str ‖ str member_id ‖ 32B x25519 ‖ 32B ed25519 ‖ str name ‖ str added_by
/// revocation "whph-sync/revocation-cell/v1" str ‖ 32B revoked ‖ 32B revoker ‖ u32 n ‖ n×(16B origin ‖ i64 cutoff) ‖ 64B sig
/// grant      "whph-sync/grant/v1" str ‖ i64 epoch counter ‖ str epoch creator ‖ 32B member ed25519
/// ```
library;

import 'dart:typed_data';

import '../crypto/epoch.dart';
import '../crypto/primitives.dart';
import '../crypto/revocation.dart';
import '../model/change.dart';
import '../model/ids.dart';
import '../model/wire_bytes.dart';
import '../store/replica_store.dart';
import '../store/sync_store.dart';

const _memberDomain = 'whph-sync/member/v1';
const _revocationDomain = 'whph-sync/revocation-cell/v1';
const _grantDomain = 'whph-sync/grant/v1';

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// A `sync_member` entry: public keys and display data of one member.
final class MemberEntry {
  MemberEntry({
    required this.memberId,
    required List<int> x25519Pub,
    required List<int> ed25519Pub,
    required this.name,
    required this.addedBy,
  })  : x25519Pub = Uint8List.fromList(x25519Pub).asUnmodifiableView(),
        ed25519Pub = Uint8List.fromList(ed25519Pub).asUnmodifiableView() {
    if (memberId.isEmpty) throw ArgumentError.value(memberId, 'memberId', 'must not be empty');
    if (this.x25519Pub.length != keyLength) throw ArgumentError.value(x25519Pub.length, 'x25519Pub');
    if (this.ed25519Pub.length != keyLength) throw ArgumentError.value(ed25519Pub.length, 'ed25519Pub');
  }

  final String memberId;
  final Uint8List x25519Pub;
  final Uint8List ed25519Pub;
  final String name;

  /// Member id of the member that added this one.
  final String addedBy;

  /// The row key of this entry.
  CellKey get cellKey => memberCellKey(memberId);

  Uint8List encode() => (ByteWriter()
        ..string(_memberDomain)
        ..string(memberId)
        ..fixed(x25519Pub)
        ..fixed(ed25519Pub)
        ..string(name)
        ..string(addedBy))
      .take();

  /// Decodes [encode] output; throws a `SyncDecodeException` subtype.
  static MemberEntry decode(Uint8List bytes) {
    final r = ByteReader(bytes);
    if (r.string('domain') != _memberDomain) throw const FormatException('not a member entry');
    final entry = MemberEntry(
      memberId: r.name('member_id'),
      x25519Pub: r.fixed(keyLength, 'x25519'),
      ed25519Pub: r.fixed(keyLength, 'ed25519'),
      name: r.string('name'),
      addedBy: r.string('added_by'),
    );
    r.expectEnd('member entry');
    return entry;
  }

  @override
  String toString() => 'MemberEntry($memberId)';
}

/// Row key of the member entry of [memberId].
CellKey memberCellKey(String memberId) => CellKey(SecurityTables.member, memberId, CellKey.rowCol);

/// Encodes a revocation record as a cell value.
Uint8List encodeRevocationRecord(RevocationRecord record) {
  final w = ByteWriter()
    ..string(_revocationDomain)
    ..fixed(record.revokedPub)
    ..fixed(record.revokerPub)
    ..u32(record.cutoffs.length);
  for (final e in record.cutoffs.entries) {
    w
      ..fixed(e.key.bytes)
      ..i64(e.value);
  }
  w.fixed(record.sig);
  return w.take();
}

/// Decodes [encodeRevocationRecord] output.
RevocationRecord decodeRevocationRecord(Uint8List bytes) {
  final r = ByteReader(bytes);
  if (r.string('domain') != _revocationDomain) throw const FormatException('not a revocation record');
  final revoked = r.fixed(keyLength, 'revoked');
  final revoker = r.fixed(keyLength, 'revoker');
  final n = r.count('cutoff count', minElementBytes: Id128.length + 8);
  final cutoffs = <OriginId, int>{};
  for (var i = 0; i < n; i++) {
    cutoffs[OriginId(r.fixed(Id128.length, 'origin'))] = r.seq('cutoff');
  }
  final sig = r.fixed(64, 'sig');
  r.expectEnd('revocation record');
  return RevocationRecord(revokedPub: revoked, revokerPub: revoker, cutoffs: cutoffs, sig: sig);
}

/// Row key of a revocation record: 16 bytes of the hash of its encoding.
CellKey revocationCellKey(RevocationRecord record) =>
    CellKey(SecurityTables.revocation, _hex(blake2b256(encodeRevocationRecord(record)).sublist(0, 16)), CellKey.rowCol);

/// Encodes an epoch grant as a cell value.
Uint8List encodeEpochGrant(EpochGrant grant) => (ByteWriter()
      ..string(_grantDomain)
      ..i64(grant.epoch.counter)
      ..string(grant.epoch.creator)
      ..fixed(grant.memberPub))
    .take();

/// Decodes [encodeEpochGrant] output.
EpochGrant decodeEpochGrant(Uint8List bytes) {
  final r = ByteReader(bytes);
  if (r.string('domain') != _grantDomain) throw const FormatException('not an epoch grant');
  final counter = r.seq('epoch counter');
  final creator = r.name('epoch creator');
  final pub = r.fixed(keyLength, 'member');
  r.expectEnd('epoch grant');
  return EpochGrant(EpochId(counter, creator), pub);
}

/// Row key of an epoch grant.
CellKey epochGrantCellKey(EpochGrant grant) => CellKey(
      SecurityTables.epochGrant,
      '${grant.epoch.counter}.${grant.epoch.creator}.${_hex(grant.memberPub)}',
      CellKey.rowCol,
    );
