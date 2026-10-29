// D13a: a ledger revocation record without a MAC (version 1) is kept only when
// a member of the group signed it; a forged pair is dropped with a backup.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'sync_security_test_support.dart';

void main() {
  late Directory scratch;

  setUp(() async => scratch = await Directory.systemTemp.createTemp('sync-ledger-mac-'));
  tearDown(() => scratch.delete(recursive: true));

  Future<Map<String, dynamic>> readLedger(SecurityDevice device) async =>
      jsonDecode(await device.keyStore.ledgerFile.readAsString()) as Map<String, dynamic>;

  Future<void> writeLedger(SecurityDevice device, Map<String, dynamic> json) =>
      device.keyStore.ledgerFile.writeAsString(jsonEncode(json));

  Future<SyncMembershipService> restart(SecurityDevice device) async {
    final service = SyncMembershipService(
      keyStore: device.keyStore,
      changeStore: device.database.store,
      peerStateStore: device.peerStates,
    );
    expect(await service.loadKeyFile(), isTrue);
    return service;
  }

  Future<Map<String, Object?>> forgedPair(SecurityDevice device) async {
    final attacker = await Ed25519KeyPair.fromSeed(secureRandomBytes(32));
    final victim =
        device.service.membership.activeMembers.firstWhere((m) => m.memberId != device.service.membership.memberId);
    final record = await RevocationRecord.sign(
      groupId: device.service.membership.groupId!,
      revokedPub: victim.ed25519Pub,
      revoker: attacker,
      cutoffs: {},
    );
    final attackerEntry = MemberEntry(
      memberId: 'attacker',
      x25519Pub: victim.x25519Pub,
      ed25519Pub: attacker.publicKey,
      name: 'attacker',
      addedBy: 'attacker',
    );
    return {
      'record': base64Encode(encodeRevocationRecord(record)),
      'revoker_entry': base64Encode(attackerEntry.encode()),
      'carrier_origin': '11' * 16,
      'carrier_seq': 1,
    };
  }

  test('a restart keeps the MACed record, and a forged pair in a version 1 ledger is dropped', () async {
    final a = await SecurityDevice.open('A', scratch);
    final b = await SecurityDevice.open('B', scratch);
    final c = await SecurityDevice.open('C', scratch);
    for (final device in [a, b, c]) {
      addTearDown(device.close);
    }
    await pairDevices(a, b);
    await pairDevices(a, c);
    await a.service.removeMember(c.service.membership.memberId);
    final genuine = a.keyStore.revocations.single;

    await restart(a);
    expect(a.keyStore.revocations.single.carrierId, genuine.carrierId, reason: 'a MACed record survives a restart');

    final json = await readLedger(a);
    json['version'] = 1;
    final records = (json['revocations'] as List).cast<Map<String, dynamic>>();
    for (final record in records) {
      record.remove('mac');
    }
    records.add(await forgedPair(a));
    await writeLedger(a, json);

    await restart(a);

    expect(a.keyStore.revocations.map((r) => r.carrierId), [genuine.carrierId], reason: 'forged pair is gone');
    final backup = File('${a.root.path}/state/$droppedLegacyLedgerFileName');
    expect(jsonDecode(await backup.readAsString()), hasLength(1));
    expect((await readLedger(a))['version'], 2);
  });
}
