import 'dart:convert';
import 'dart:typed_data';

import 'package:whph/core/application/shared/utils/sync_identity.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

const int _msPerSecond = 1000;
const int _hlcCounterBits = 16;
const int _hexRadix = 16;
const int _revocationOriginSeq = 0;

/// A security row failed validation (wrong pk, malformed bytes).
class SecurityCellRejected implements Exception {
  final String category;
  const SecurityCellRejected(this.category);

  @override
  String toString() => 'SecurityCellRejected($category)';
}

/// Mapping of one grow-only security table (D7, D13) between its wire form
/// (a row-level `*` cell whose value is the record bytes, see
/// `security_records.dart`) and the Drift row that stores it.
class SecurityCellSpec {
  /// Table name on the wire (`SecurityTables`).
  final String wireName;
  final int tblId;
  final String tableName;

  /// Column holding the cell's pk.
  final String pkColumn;

  /// Validates [bytes] against [pk] and returns the Drift row.
  final Map<String, Object?> Function(String pk, Uint8List bytes, int clock)
      toRow;

  /// The record bytes of a stored row.
  final Uint8List Function(Map<String, Object?> row) fromRow;

  const SecurityCellSpec({
    required this.wireName,
    required this.tblId,
    required this.tableName,
    required this.pkColumn,
    required this.toRow,
    required this.fromRow,
  });
}

/// Lowercase hex form used by the security tables for keys and signatures.
String hexEncode(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(_hexRadix).padLeft(2, '0')).join();

Uint8List hexDecode(String hex) => Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: _hexRadix),
    ]);

int _wallSeconds(int clock) => (clock >> _hlcCounterBits) ~/ _msPerSecond;

void _requirePk(bool matches) {
  if (!matches) throw const SecurityCellRejected('security_pk_mismatch');
}

Map<String, Object?> _memberRow(String pk, Uint8List bytes, int clock) {
  final entry = MemberEntry.decode(bytes);
  _requirePk(entry.memberId == pk);
  return {
    'id': syncIdentityId('sync_member', [entry.memberId]),
    'member_id': entry.memberId,
    'name': entry.name,
    'platform': null,
    'x25519_pub': hexEncode(entry.x25519Pub),
    'ed25519_pub': hexEncode(entry.ed25519Pub),
    'added_by': entry.addedBy,
    'created_date': _wallSeconds(clock),
  };
}

Uint8List _memberBytes(Map<String, Object?> row) => MemberEntry(
      memberId: row['member_id'] as String,
      x25519Pub: hexDecode(row['x25519_pub'] as String),
      ed25519Pub: hexDecode(row['ed25519_pub'] as String),
      name: (row['name'] as String?) ?? '',
      addedBy: row['added_by'] as String,
    ).encode();

Map<String, Object?> _revocationRow(String pk, Uint8List bytes, int clock) {
  final record = decodeRevocationRecord(bytes);
  _requirePk(revocationCellKey(record).pk == pk);
  return {
    'revoked_pub': hexEncode(record.revokedPub),
    'revoker_pub': hexEncode(record.revokerPub),
    'origin_id': pk,
    'origin_seq': _revocationOriginSeq,
    'cutoffs': jsonEncode(
        {for (final e in record.cutoffs.entries) e.key.hex: e.value}),
    'sig': hexEncode(record.sig),
    'hlc': clock,
  };
}

Uint8List _revocationBytes(Map<String, Object?> row) {
  final cutoffs = jsonDecode(row['cutoffs'] as String) as Map<String, dynamic>;
  return encodeRevocationRecord(RevocationRecord(
    revokedPub: hexDecode(row['revoked_pub'] as String),
    revokerPub: hexDecode(row['revoker_pub'] as String),
    cutoffs: {
      for (final e in cutoffs.entries) OriginId.fromHex(e.key): e.value as int,
    },
    sig: hexDecode(row['sig'] as String),
  ));
}

Map<String, Object?> _grantRow(String pk, Uint8List bytes, int clock) {
  final grant = decodeEpochGrant(bytes);
  _requirePk(epochGrantCellKey(grant).pk == pk);
  return {
    'id': pk,
    'counter': grant.epoch.counter,
    'creator': grant.epoch.creator,
    'granted_to': hexEncode(grant.memberPub),
    'key_ciphertext': '',
  };
}

Uint8List _grantBytes(Map<String, Object?> row) => encodeEpochGrant(EpochGrant(
      EpochId(row['counter'] as int, row['creator'] as String),
      hexDecode(row['granted_to'] as String),
    ));

const List<SecurityCellSpec> securityCellSpecs = [
  SecurityCellSpec(
    wireName: SecurityTables.member,
    tblId: securityTblIdFloor,
    tableName: 'sync_member_table',
    pkColumn: 'member_id',
    toRow: _memberRow,
    fromRow: _memberBytes,
  ),
  SecurityCellSpec(
    wireName: SecurityTables.revocation,
    tblId: securityTblIdFloor + 1,
    tableName: 'sync_revocation',
    pkColumn: 'origin_id',
    toRow: _revocationRow,
    fromRow: _revocationBytes,
  ),
  SecurityCellSpec(
    wireName: SecurityTables.epochGrant,
    tblId: securityTblIdFloor + 2,
    tableName: 'sync_epoch_grant',
    pkColumn: 'id',
    toRow: _grantRow,
    fromRow: _grantBytes,
  ),
];
