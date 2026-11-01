import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

OriginId _origin(int fill) => OriginId(List.filled(16, fill));

LedgerRevocation _revocation({
  List<int> record = const [1, 2, 3],
  List<int>? entry = const [4, 5],
  int originFill = 7,
  int seq = 9,
}) =>
    LedgerRevocation(recordBytes: record, revokerEntryBytes: entry, carrierOrigin: _origin(originFill), carrierSeq: seq);

void main() {
  final key = deriveLedgerMacKey(List.filled(32, 1));
  final revocation = _revocation();
  final mac = ledgerRevocationMac(key, revocation);

  test('the MAC is deterministic and accepted for the same record and key', () {
    expect(ledgerRevocationMac(key, _revocation()), mac);
    expect(isLedgerRevocationMacValid(key, revocation, mac), isTrue);
  });

  test('another identity seed derives a key that rejects the MAC', () {
    final otherKey = deriveLedgerMacKey(List.filled(32, 2));
    expect(isLedgerRevocationMacValid(otherKey, revocation, mac), isFalse);
  });

  test('every covered field changes the MAC', () {
    final variants = {
      'record': _revocation(record: const [1, 2, 9]),
      'entry bytes': _revocation(entry: const [4, 6]),
      'no entry': _revocation(entry: null),
      'origin': _revocation(originFill: 8),
      'seq': _revocation(seq: 10),
    };
    for (final MapEntry(:key, value: variant) in variants.entries) {
      expect(isLedgerRevocationMacValid(deriveLedgerMacKey(List.filled(32, 1)), variant, mac), isFalse, reason: key);
    }
  });

  test('moving a byte between record and entry does not keep the MAC', () {
    final moved = _revocation(record: const [1, 2], entry: const [3, 4, 5]);
    expect(isLedgerRevocationMacValid(key, moved, mac), isFalse);
  });

  test('a truncated or empty MAC is rejected', () {
    expect(isLedgerRevocationMacValid(key, revocation, Uint8List.sublistView(mac, 0, 32)), isFalse);
    expect(isLedgerRevocationMacValid(key, revocation, const []), isFalse);
  });
}
