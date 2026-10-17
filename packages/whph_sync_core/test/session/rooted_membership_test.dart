/// Rooted membership (U11/rooted): a member cell counts only when its carrier
/// origin is owned, through a verified registration, by a member already
/// rooted in the key-file trust anchors.
library;

import 'dart:math';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

Future<void> _syncAll(List<SyncDevice> devices, {int rounds = 4}) async {
  for (var round = 0; round < rounds; round++) {
    for (var i = 0; i < devices.length; i++) {
      for (var j = i + 1; j < devices.length; j++) {
        await SyncDevice.syncPair(devices[i], devices[j]);
      }
    }
  }
}

/// Stores a member cell for [member] as change [seq] of [origin], as if it
/// had been received (plain merge, no session).
void _storeMemberCell(SyncStore store, OriginId origin, int seq, MemberEntry member) {
  final record = CellRecord(
    key: memberCellKey(member.memberId),
    value: member.encode(),
    clock: store.hlc + seq,
    node: member.addedBy,
    origin: origin.hex,
    originSeq: seq,
  );
  store.applyBatch(ChangeBatch(origin: origin.hex, fromSeq: seq - 1, toSeq: seq, cells: [record]));
}

Future<OriginRegistration> _registration(GroupId group, OriginId origin, DeviceIdentity owner) =>
    signOriginRegistration(groupId: group, origin: origin, member: owner.ed25519, createdHlc: 1);

Set<String> _memberIds(SyncDevice d) => d.membership.members.keys.toSet();

void main() {
  group('keylost cycle', () {
    test('keylost_cycle_bystander_verifies_everything', () async {
      final [b, c, d1, x] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 700 + i)];
      await pairAll([b, c, d1]);
      await syncUntilQuiet([b, c, d1]);

      // D1 invites X; X's member row exists only on D1's origin and is never sent.
      await SyncDevice.pair(inviter: d1, joiner: x);
      final oldDb = d1.snapshotDb();
      final oldD1 = d1.memberId;

      await d1.loseKeyFile(oldDb: oldDb, loseLedger: true);
      await b.removeMember(oldD1);
      await SyncDevice.pair(inviter: x, joiner: d1);
      await _syncAll([d1, x], rounds: 2);

      // X loses its key too, keeps a DB with both rows, and B re-invites it.
      final xDb = x.snapshotDb();
      final oldX = x.memberId;
      await x.loseKeyFile(oldDb: xDb, loseLedger: false);
      await d1.removeMember(oldX);
      // Both devices lost their invite rows, so the group re-invites them.
      await SyncDevice.pair(inviter: b, joiner: x);
      await SyncDevice.pair(inviter: b, joiner: d1);

      await _syncAll([b, c, x], rounds: 6);
      await _syncAll([b, c, d1, x], rounds: 6);

      expect(c.store.heldEnvelopes, isEmpty, reason: 'C must verify every member row eventually');
      expect(c.membership.memberById(d1.memberId), isNotNull, reason: 'C learns the new D1');
      expect(c.membership.memberById(x.memberId), isNotNull, reason: 'C learns the new X');
    });

    test('keylost_before_reinvite_new_origin_carries_no_member_row', () async {
      final [b, c, d1, x] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 730 + i)];
      await pairAll([b, c, d1]);
      await syncUntilQuiet([b, c, d1]);
      await SyncDevice.pair(inviter: d1, joiner: x);
      final oldDb = d1.snapshotDb();
      final oldD1 = d1.memberId;
      await d1.loseKeyFile(oldDb: oldDb, loseLedger: true);
      expect(d1.needsRepairing, isTrue);
      await b.removeMember(oldD1);
      await SyncDevice.pair(inviter: x, joiner: d1);

      await _syncAll([b, c, d1, x], rounds: 6);

      final newOrigin = d1.store.localOrigin.hex;
      expect(d1.store.read(memberCellKey(x.memberId))?.origin, isNot(newOrigin),
          reason: 'D1 holds no X row on its new origin');
      final onNewOrigin = [
        for (final cell in c.store.cells)
          if (cell.origin == newOrigin && cell.key.table == 'sync_member') cell,
      ];
      expect(onNewOrigin, isEmpty, reason: 'the old invite row is not re-keyed onto the new origin');
      expect(c.store.heldEnvelopes.where((h) => h.origin == newOrigin && h.row.table == 'sync_member'), isEmpty);
    });

    test('keylost_unsent_security_row_stays_on_old_origin_and_needs_repairing', () async {
      final [b, d1, x] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 710 + i)];
      await pairAll([b, d1]);
      await syncUntilQuiet([b, d1]);
      await SyncDevice.pair(inviter: d1, joiner: x);
      createRow(d1, 'unsent-task', 'kept');
      final inviteOrigin = d1.store.localOrigin.hex;
      final oldDb = d1.snapshotDb();

      await d1.loseKeyFile(oldDb: oldDb, loseLedger: true);

      expect(d1.needsRepairing, isTrue);
      final inviteRow = d1.store.read(memberCellKey(x.memberId))!;
      expect(inviteRow.origin, inviteOrigin, reason: 'the security row is not re-keyed');
      expect(d1.store.sealedOrigins, contains(inviteOrigin));
      expect(d1.store.read(cellKey('unsent-task', 'title'))!.origin, d1.store.localOrigin.hex,
          reason: 'user rows still move');
    });

    test('reinvited_device_converges', () async {
      final [b, c, d1, x] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 720 + i)];
      await pairAll([b, c, d1]);
      await syncUntilQuiet([b, c, d1]);
      await SyncDevice.pair(inviter: d1, joiner: x);
      createRow(d1, 'unsent-task', 'kept');
      final oldDb = d1.snapshotDb();
      final oldD1 = d1.memberId;

      await d1.loseKeyFile(oldDb: oldDb, loseLedger: true);
      await b.removeMember(oldD1);
      await SyncDevice.pair(inviter: b, joiner: d1);
      await SyncDevice.pair(inviter: b, joiner: x);

      expect(await syncUntilQuiet([b, c, d1, x], maxRounds: 10), lessThanOrEqualTo(10));
      expect(d1.needsRepairing, isFalse);
      for (final d in [b, c, d1, x]) {
        expect(d.store.heldEnvelopes, isEmpty, reason: d.name);
      }
      expect(content(c.store), containsPair(cellKey('unsent-task', 'title').toString(), contains('kept')));
    });
  });

  group('rooting', () {
    test('joiner_bootstrap_roots_inviter_chain', () async {
      final [a, b, i, j, k] = [for (var n = 0; n < 5; n++) await newDevice('D$n', seed: 730 + n)];
      await pairAll([a, b, i]);
      await SyncDevice.pair(inviter: i, joiner: j);
      await syncUntilQuiet([a, b, i, j]);
      expect(_memberIds(j), containsAll([a, b, i, j].map((d) => d.memberId)));

      // I is revoked at A (cutoff covers J's row); offline, it still invites K
      // above the cutoff.
      await a.removeMember(i.memberId);
      await SyncDevice.pair(inviter: i, joiner: k);
      final aboveCutoff = i.store.read(memberCellKey(k.memberId))!;
      a.store.applyBatch(ChangeBatch(
        origin: aboveCutoff.origin,
        fromSeq: aboveCutoff.originSeq - 1,
        toSeq: aboveCutoff.originSeq,
        cells: [aboveCutoff],
      ));
      await a.membership.rebuild(a.store);

      expect(a.membership.memberById(j.memberId), isNotNull, reason: 'below the cutoff');
      expect(a.membership.memberById(k.memberId), isNull, reason: 'above the cutoff');
    });

    test('late_registration_roots_on_rebuild', () async {
      final [a, c] = [for (var n = 0; n < 2; n++) await newDevice('D$n', seed: 740 + n)];
      await SyncDevice.pair(inviter: a, joiner: c);
      final ids = SyncIdSource(Random(9741));
      final newcomer = await DeviceIdentity.generate(ids, name: 'N');
      final lateOrigin = ids.origin();
      _storeMemberCell(c.store, lateOrigin, 1, newcomer.entry(addedBy: a.memberId));

      await c.membership.rebuild(c.store);
      expect(c.membership.memberById(newcomer.memberId), isNull, reason: 'carrier unregistered');

      final row = await _registration(c.membership.groupId!, lateOrigin, a.membership.identity);
      await c.membership.mergeRegistrations([row], c.store);
      await c.membership.rebuild(c.store);
      expect(c.membership.memberById(newcomer.memberId), isNotNull);
    });

    test('restore_older_db_keeps_rooted_members', () async {
      final [a, b, c, d] = [for (var n = 0; n < 4; n++) await newDevice('D$n', seed: 750 + n)];
      await pairAll([a, b, c]);
      await syncUntilQuiet([a, b, c]);
      final oldDb = c.snapshotDb();
      await SyncDevice.pair(inviter: a, joiner: d);
      await syncUntilQuiet([a, b, c, d]);

      await c.restoreDb(oldDb);

      expect(_memberIds(c), containsAll([a, b, c, d].map((x) => x.memberId)));
      await syncUntilQuiet([a, b, c, d], maxRounds: 10);
      for (final x in [a, b, c, d]) {
        expect(x.store.heldEnvelopes, isEmpty, reason: x.name);
      }
    });

    test('sealed_former_origin_still_roots', () async {
      final [a, b, c] = [for (var n = 0; n < 3; n++) await newDevice('D$n', seed: 760 + n)];
      await pairAll([a, b]);
      await syncUntilQuiet([a, b]);
      await SyncDevice.pair(inviter: a, joiner: c);
      final formerOrigin = a.store.localOrigin.hex;

      await a.switchOrigin(OriginSwitchReason.restore);
      await a.membership.rebuild(a.store);

      expect(a.store.sealedOrigins, contains(formerOrigin));
      expect(a.store.read(memberCellKey(c.memberId))!.origin, formerOrigin);
      expect(a.membership.memberById(c.memberId), isNotNull, reason: 'own sealed origin roots');
      expect(a.needsRepairing, isTrue);
    });
  });

  group('rooted fixpoint', () {
    test('rooted_set_is_order_independent_and_converges', () async {
      const chainLength = 12; // longer than the revocation-filter round bound
      final ids = SyncIdSource(Random(9770));
      final identities = [for (var n = 0; n < chainLength; n++) await DeviceIdentity.generate(ids, name: 'N$n')];
      final origins = [for (var n = 0; n <= chainLength; n++) ids.origin()];
      Set<String>? reference;
      for (var seed = 0; seed < 6; seed++) {
        final root = await newDevice('root', seed: 771);
        final bystander = await newDevice('by', seed: 772 + seed);
        await SyncDevice.pair(inviter: root, joiner: bystander);
        final g = bystander.membership.groupId!;
        final rooted = [root.membership.identity, ...identities];
        // Link n: its carrier origin is registered by link n-1; its own row
        // is carried by that origin.
        final links = [
          for (var n = 0; n < chainLength; n++) (n, origins[n], rooted[n], identities[n]),
        ];
        final registrations = [for (final (_, origin, owner, _) in links) await _registration(g, origin, owner)]
          ..shuffle(Random(seed));
        final cells = [...links]..shuffle(Random(seed + 100));
        for (final (_, origin, _, member) in cells) {
          _storeMemberCell(bystander.store, origin, 1, member.entry(addedBy: root.memberId));
        }
        for (final row in registrations) {
          await bystander.membership.mergeRegistrations([row], bystander.store);
        }

        await bystander.membership.rebuild(bystander.store);
        final ids0 = _memberIds(bystander);
        expect(await bystander.membership.rebuild(bystander.store), isFalse, reason: 'stable on a second rebuild');

        expect(ids0, containsAll(identities.map((i) => i.memberId)));
        expect(ids0, hasLength(chainLength + 2));
        final chainOnly = ids0.difference({bystander.memberId});
        expect(reference ??= chainOnly, chainOnly);
      }
    });

    test('mutually_vouching_members_without_a_seed_are_not_rooted', () async {
      final [a, c] = [for (var n = 0; n < 2; n++) await newDevice('D$n', seed: 780 + n)];
      await SyncDevice.pair(inviter: a, joiner: c);
      final g = c.membership.groupId!;
      final ids = SyncIdSource(Random(9781));
      final p = await DeviceIdentity.generate(ids, name: 'P');
      final q = await DeviceIdentity.generate(ids, name: 'Q');
      final originP = ids.origin();
      final originQ = ids.origin();
      // P's row sits on Q's origin and Q's row on P's origin, each registered
      // by the member whose row it carries.
      _storeMemberCell(c.store, originQ, 1, p.entry(addedBy: q.memberId));
      _storeMemberCell(c.store, originP, 1, q.entry(addedBy: p.memberId));
      await c.membership
          .mergeRegistrations([await _registration(g, originP, p), await _registration(g, originQ, q)], c.store);

      await c.membership.rebuild(c.store);
      expect(c.membership.memberById(p.memberId), isNull);
      expect(c.membership.memberById(q.memberId), isNull);

      // A rooted member claiming P's origin roots Q, whose registration then roots P.
      await c.membership.mergeRegistrations([await _registration(g, originP, a.membership.identity)], c.store);
      await c.membership.rebuild(c.store);
      expect(c.membership.memberById(q.memberId), isNotNull);
      expect(c.membership.memberById(p.memberId), isNotNull);
    });
  });
}
