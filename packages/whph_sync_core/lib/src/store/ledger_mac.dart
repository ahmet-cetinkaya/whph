/// Message authentication of the revocation records kept in the sync ledger
/// (D13a): the ledger file lives outside the database, so a record written
/// there by someone without the key file must not reach `Membership`.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../crypto/primitives.dart';
import '../model/wire_bytes.dart';
import 'sync_ledger.dart';

const String _keyInfo = 'whph-sync-ledger-mac-v1';
const String _macDomain = 'whph-sync-ledger-record-mac-v1';
const int _macKeyLength = 32;

/// The ledger MAC key, derived from the device's Ed25519 [identitySeed] (the
/// secret in the key file). Never log or store the result.
Uint8List deriveLedgerMacKey(List<int> identitySeed) {
  final derived = noiseHkdf(utf8.encode(_keyInfo), identitySeed, 2);
  final key = Uint8List.sublistView(derived.first, 0, _macKeyLength);
  return Uint8List.fromList(key);
}

/// The MAC of [revocation] under [macKey]: it covers the record, the revoker
/// entry and the carrier position, length-prefixed so fields cannot be moved
/// into each other.
Uint8List ledgerRevocationMac(List<int> macKey, LedgerRevocation revocation) {
  final entry = revocation.revokerEntryBytes;
  final writer = ByteWriter()
    ..string(_macDomain)
    ..bytes(revocation.recordBytes)
    ..fixed(revocation.carrierOrigin.bytes)
    ..i64(revocation.carrierSeq)
    ..u8(entry == null ? 0 : 1)
    ..bytes(entry ?? const <int>[]);
  return hmacBlake2b(macKey, writer.take());
}

/// Whether [mac] authenticates [revocation] under [macKey] (constant time).
bool isLedgerRevocationMacValid(List<int> macKey, LedgerRevocation revocation, List<int> mac) =>
    constantTimeEquals(ledgerRevocationMac(macKey, revocation), mac);
