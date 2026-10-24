// T20 acceptance 3, 4, 5, 6, 8, 10 on real Drift stores.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../../../../infrastructure/shared/features/sync/sync_security_test_support.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temp;
  final opened = <SecurityDevice>[];

  Future<SecurityDevice> open(String name) async {
    final device = await SecurityDevice.open(name, temp);
    opened.add(device);
    return device;
  }

  setUp(() async =>
      temp = await Directory.systemTemp.createTemp('t20-membership-'));

  tearDown(() async {
    for (final device in opened) {
      await device.close();
    }
    opened.clear();
    await temp.delete(recursive: true);
  });

  group('group rules (acc 5)', () {
    test('first pairing of two groupless devices creates exactly one group id',
        () async {
      final a = await open('a');
      final b = await open('b');
      expect(a.membership.groupId, isNull);

      await pairDevices(a, b);

      expect(a.membership.groupId, isNotNull);
      expect(b.membership.groupId, a.membership.groupId);
      expect(
          await a.database.count(
              "SELECT COUNT(DISTINCT group_id) FROM sync_state WHERE group_id IS NOT NULL"),
          1);
      expect(
        (await a.service.currentView()).activeMembers.map((m) => m.memberId),
        unorderedEquals([a.memberId, b.memberId]),
      );
    });

    test('a groupless device joins the inviter group without confirmation',
        () async {
      final a = await open('a');
      final b = await open('b');
      final c = await open('c');
      await pairDevices(a, b);
      final group = a.membership.groupId;

      expect(c.service.requiresGroupSwitchConfirmation(group), isFalse);
      await pairDevices(a, c);

      expect(c.membership.groupId, group);
    });

    test(
        'joining while in a multi-member group needs confirmation; cancel changes nothing',
        () async {
      final a = await open('a');
      final b = await open('b');
      final c = await open('c');
      final d = await open('d');
      await pairDevices(a, b);
      await pairDevices(c, d);
      final groupA = a.membership.groupId;
      final groupC = c.membership.groupId;
      final originBefore = await c.database.store.localOrigin();

      expect(c.service.requiresGroupSwitchConfirmation(groupA), isTrue);
      await expectLater(pairDevices(a, c), throwsMembership());
      final handover = await a.service
          .prepareHandover(c.membership.identity.entry(addedBy: a.memberId));
      await expectLater(c.service.acceptHandover(handover), throwsMembership());
      handover.destroy();

      expect(c.membership.groupId, groupC);
      expect(a.membership.groupId, groupA);
      expect(await c.database.store.localOrigin(), originBefore);
    });
  });

  group('removal (acc 3, 4)', () {
    test(
        'revocation carries cutoffs for every origin of the removed member and a new epoch',
        () async {
      final a = await open('a');
      final b = await open('b');
      final c = await open('c');
      await pairDevices(a, b);
      await pairDevices(a, c);
      await c.database.insertNote('c1', 'from c');
      await syncDevices(a, c);
      await syncDevices(a, b);
      final epochBefore = a.membership.keyring.highest!;
      final cOrigin = OriginId.fromHex(await c.database.store.localOrigin());

      final vector = await a.database.store.readVector();
      await a.service.removeMember(c.memberId);
      await syncDevices(a, b);

      final record = a.membership.directoryRevocations!.records.single;
      expect(record.cutoffs.keys, contains(cOrigin));
      expect(record.cutoffs[cOrigin], vector[cOrigin.hex]);
      expect(a.membership.keyring.highest, isNot(epochBefore));
      expect(
          b.membership.isRevokedEd(c.membership.identity.ed25519Pub), isTrue);
      expect(await handshakeRefused(c, b), isTrue);
      expect(c.membership.keyring.keyFor(a.membership.keyring.highest!), isNull,
          reason:
              'changes after removal use an epoch the removed member lacks');
    });

    test('a member with two origins gets a cutoff for both', () async {
      final a = await open('a');
      final b = await open('b');
      await pairDevices(a, b);
      await b.database.insertNote('b1', 'first origin');
      await syncDevices(a, b);
      final first = OriginId.fromHex(await b.database.store.localOrigin());
      await b.service.switchOrigin(OriginSwitchReason.restore);
      await b.database.insertNote('b2', 'second origin');
      final second = OriginId.fromHex(await b.database.store.localOrigin());
      await syncDevices(a, b);

      final vector = await a.database.store.readVector();
      await a.service.removeMember(b.memberId);

      final record = a.membership.directoryRevocations!.records.single;
      expect(record.cutoffs.keys, containsAll([first, second]));
      expect(first, isNot(second));
      expect(record.cutoffs[first], vector[first.hex]);
      expect(record.cutoffs[second], vector[second.hex]);
      final revocations = a.membership.directoryRevocations!;
      final removedKey = b.membership.identity.ed25519Pub;
      expect(revocations.cutoffOf(removedKey, first), vector[first.hex],
          reason: 'seqs up to the cutoff are accepted');
      expect(revocations.cutoffOf(removedKey, second), vector[second.hex]);
    });
  });

  group('missing key file (acc 6)', () {
    test(
        'a new member id and origin; the old origin is sealed and never reused',
        () async {
      final a = await open('a');
      final b = await open('b');
      await pairDevices(a, b);
      await b.database.insertNote('n1', 'never sent');
      final oldMember = b.memberId;
      final oldOrigin = await b.database.store.localOrigin();

      await b.keyStore.keyFile.delete();
      await b.service.recoverFromLostKeyFile(name: 'b');
      expect(await SyncUpgradeJob(b.database.db).runChunks(), isTrue);

      expect(b.memberId, isNot(oldMember));
      expect(await b.database.store.localOrigin(), isNot(oldOrigin));
      Future<Iterable<String>> noteTables(String origin) async => (await b
              .database.store
              .readChanges(origin, afterSeq: 0, upToSeq: 1 << 30, limit: 1000))
          .cells
          .map((cell) => cell.key.table);
      expect(await noteTables(oldOrigin), isNot(contains('note_table')),
          reason: 'never-sent cells left the sealed origin');
      expect(await noteTables(await b.database.store.localOrigin()),
          contains('note_table'),
          reason: 'never-sent cells were adopted by the new origin');
      expect(
          (await b.service.currentView()).state, SyncGroupState.needsRepairing);
      expect(b.keyStore.entries.map((e) => e.origin.hex), contains(oldOrigin));
    });
  });

  group('needs re-pairing (acc 10)', () {
    test(
        'a key of no member marks the member; another member key corrects addresses',
        () async {
      final a = await open('a');
      final b = await open('b');
      final c = await open('c');
      final stranger = await open('s');
      await pairDevices(a, b);
      await pairDevices(a, c);
      await syncDevices(a, b);
      await syncDevices(a, c);
      await a.peerStates.moveAddress('10.0.0.2:1',
          fromMemberId: 'seed', toMemberId: b.memberId);
      await a.peerStates.moveAddress('10.0.0.3:1',
          fromMemberId: 'seed', toMemberId: c.memberId);

      final unknown = await a.service.checkOutboundStaticKey(
        expectedMemberId: b.memberId,
        observedX25519: stranger.membership.identity.x25519Pub,
        address: '10.0.0.2:1',
      );
      expect(unknown, OutboundKeyVerdict.needsRepairing);
      expect(
          (await a.service.currentView()).peersNeedingRepairing, {b.memberId});

      final other = await a.service.checkOutboundStaticKey(
        expectedMemberId: c.memberId,
        observedX25519: b.membership.identity.x25519Pub,
        address: '10.0.0.3:1',
      );
      expect(other, OutboundKeyVerdict.addressBelongsToOtherMember);
      expect(
          (await a.service.currentView()).peersNeedingRepairing, {b.memberId},
          reason: 'c is unchanged');
      expect(await a.peerStates.addressesOf(b.memberId),
          unorderedEquals(['10.0.0.2:1', '10.0.0.3:1']));
      expect(await a.peerStates.addressesOf(c.memberId), isEmpty);
    });
  });
}
