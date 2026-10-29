// T20 acceptance 8 (NB-1): five Drift devices, G1 = {A, B}, G2 = {C, D, E};
// C joins G1 via A and confirms.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';

import '../../../../../infrastructure/shared/features/sync/sync_security_test_support.dart';

Future<Set<String>> _column(
        SecurityDevice device, String table, String column) async =>
    {
      for (final row
          in await device.database.rows('SELECT $column AS value FROM $table'))
        row['value'] as String,
    };

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temp;
  late SecurityDevice a, b, c, d, e;
  late Set<String> g2Origins;
  late Set<String> viewBeforeSwitch;

  Future<Set<String>> activeMemberIds(SecurityDevice device) async =>
      (await device.service.currentView())
          .activeMembers
          .map((member) => member.memberId)
          .toSet();

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('t20-switch-');
    [a, b, c, d, e] = [
      for (final name in ['a', 'b', 'c', 'd', 'e'])
        await SecurityDevice.open(name, temp)
    ];
    await pairDevices(a, b);
    await pairDevices(c, d);
    await pairDevices(c, e);
    await d.database.insertNote('from-d', 'authored by D');
    await a.database.insertNote('from-a', 'authored by A');
    for (final pair in [(a, b), (c, d), (c, e), (d, e)]) {
      await syncDevices(pair.$1, pair.$2);
    }
    g2Origins = {
      for (final device in [c, d, e]) await device.database.store.localOrigin()
    };
    viewBeforeSwitch = await activeMemberIds(a);

    await pairDevices(a, c, confirmGroupSwitch: true);
    expect(await SyncUpgradeJob(c.database.db).runChunks(), isTrue);
    for (final pair in [(a, c), (a, b), (b, c), (a, c)]) {
      await syncDevices(pair.$1, pair.$2);
    }
  });

  tearDown(() async {
    for (final device in [a, b, c, d, e]) {
      await device.close();
    }
    await temp.delete(recursive: true);
  });

  test('C holds no G2 member, origin, revocation, grant or manifest row',
      () async {
    expect(await _column(c, 'sync_member_table', 'member_id'),
        {a.memberId, b.memberId, c.memberId});
    expect(
        await _column(c, 'sync_origin', 'origin_id')
            .then((ids) => ids.intersection(g2Origins)),
        isEmpty);
    expect(
        await _column(c, 'sync_origin_batch', 'origin_id')
            .then((ids) => ids.intersection(g2Origins)),
        isEmpty);
    expect(await _column(c, 'sync_revocation', 'revoked_pub'), isEmpty);
    expect(await _column(c, 'sync_epoch_grant', 'creator'), {a.memberId});
    expect(await _column(c, 'sync_member_table', 'member_id'),
        isNot(contains(d.memberId)));
  });

  test('D and E sessions to A, B and C are refused at Noise authentication',
      () async {
    for (final initiator in [d, e]) {
      for (final responder in [a, b, c]) {
        expect(await handshakeRefused(initiator, responder), isTrue,
            reason: '${initiator.name} -> ${responder.name}');
      }
    }
  });

  test('A and B view equals the pre-switch view plus C; no G2 origin on A or B',
      () async {
    for (final device in [a, b]) {
      expect(await activeMemberIds(device), {...viewBeforeSwitch, c.memberId});
      expect(
          await _column(device, 'sync_origin', 'origin_id')
              .then((ids) => ids.intersection(g2Origins)),
          isEmpty);
    }
  });

  test("C's former user data, including D's note, is on A and B", () async {
    for (final device in [a, b]) {
      expect(await _column(device, 'note_table', 'id'),
          containsAll(['from-d', 'from-a']));
    }
  });

  test('D and E show C as needing re-pairing once C refuses them', () async {
    for (final device in [d, e]) {
      expect(await handshakeRefused(device, c), isTrue);
      await device.service.markPeerRefused(c.memberId);
      expect((await device.service.currentView()).peersNeedingRepairing,
          {c.memberId});
    }
  });

  test('a group switch without confirmation is refused and nothing changes',
      () async {
    final groupBefore = d.membership.groupId;
    await expectLater(pairDevices(a, d), throwsMembership());
    expect(d.membership.groupId, groupBefore);
    expect(await _column(d, 'sync_member_table', 'member_id'),
        {c.memberId, d.memberId, e.memberId});
    expect((await d.service.currentView()).state, SyncGroupState.member);
  });
}
