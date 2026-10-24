/// Membership operations of the engine: group creation, pairing, removal
/// with rotation, the removed-from-group state, re-rotation, determinism.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

void main() {
  test('first pairing creates exactly one group with epoch (1, inviter); later joiners join it', () async {
    final clock = TestClock();
    final a = await newDevice('A', seed: 1, clock: clock);
    final b = await newDevice('B', seed: 2, clock: clock);
    final c = await newDevice('C', seed: 3, clock: clock);
    expect(a.membership.hasGroup, isFalse);
    await SyncDevice.pair(inviter: a, joiner: b);
    final g = a.membership.groupId;
    expect(b.membership.groupId, g);
    expect(a.membership.keyring.epochs, {EpochId(1, a.memberId)});
    await SyncDevice.pair(inviter: b, joiner: c);
    expect(c.membership.groupId, g);
    expect(a.membership.isPaired && b.membership.isPaired && c.membership.isPaired, isTrue);
    await syncUntilQuiet([a, b, c]);
    for (final d in [a, b, c]) {
      expect({for (final m in d.membership.activeMembers) m.memberId}, {a.memberId, b.memberId, c.memberId});
      expect(d.store.registrations.length, 3);
    }
  });

  test('removal: revocation with cutoffs + rotation; concurrent removals converge on one epoch no revoked key holds',
      () async {
    final clock = TestClock();
    final devices = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 10 + i, clock: clock)];
    await pairAll(devices);
    final [a, b, c, d] = devices;
    await syncUntilQuiet(devices);
    // A removes C while B concurrently removes D.
    await a.removeMember(c.memberId);
    await b.removeMember(d.memberId);
    for (var round = 0; round < 3; round++) {
      await runSessionPair(a, b);
    }
    final top = a.membership.keyring.highest;
    expect(b.membership.keyring.highest, top);
    for (final x in [a, b]) {
      expect(x.membership.mustRotate, isFalse);
      expect({for (final m in x.membership.activeMembers) m.memberId}, {a.memberId, b.memberId});
      final holders = x.membership.grants.where((g) => g.epoch == top).map((g) => g.memberPub.toString()).toSet();
      expect(holders.contains(c.membership.identity.ed25519Pub.toString()), isFalse);
      expect(holders.contains(d.membership.identity.ed25519Pub.toString()), isFalse);
    }
    expect(c.membership.keyring.holds(top!), isFalse);
    expect(d.membership.keyring.holds(top), isFalse);
  });

  test('a device that learns its own revocation discards its keys and shows "removed from group"', () async {
    final clock = TestClock();
    final [a, b] = [await newDevice('A', seed: 20, clock: clock), await newDevice('B', seed: 21, clock: clock)];
    await SyncDevice.pair(inviter: a, joiner: b);
    await syncUntilQuiet([a, b]);
    await a.removeMember(b.memberId);
    // The revocation row reaches B (e.g. relayed in a session B was already
    // running when A removed it).
    final revocationPk = a.store.rowsOf(SecurityTables.revocation).single;
    final cell = a.store.storedCell(CellKey(SecurityTables.revocation, revocationPk, CellKey.rowCol))!;
    final change = Change.fromCellRecord(cell.record, groupId: a.membership.groupId!);
    b.store.applyRemote(
      change,
      OriginManifest(origin: change.origin, fromSeq: 0, toSeq: change.originSeq, hashes: const [], sig: Uint8List(64)),
      nowMs: clock(),
    );
    await b.membership.rebuild(b.store);
    expect(b.membership.removed, isTrue);
    expect(b.membership.keyring.epochs, isEmpty);
    expect(b.membership.isPaired, isFalse);
    final r = await runSessionPair(b, a);
    expect((r.initiator as SessionFailed).category, SessionFailure.removedFromGroup);
    await expectLater(SyncDevice.pair(inviter: a, joiner: b), throwsA(isA<PairingException>()),
        reason: 're-pairing a removed device needs a fresh identity');
  });

  test('the ledger counts created epochs and key loss resets the counter', () async {
    final a = await newDevice('A', seed: 80);
    final b = await newDevice('B', seed: 81);
    final c = await newDevice('C', seed: 82);
    await pairAll([a, b, c]);
    expect(a.ledger.epochCounterHigh, 1);
    await a.removeMember(c.memberId);
    expect(a.ledger.epochCounterHigh, 2);
    expect(b.ledger.epochCounterHigh, 0, reason: 'B never created an epoch');
    expect(await a.loseKeyFile(), StartupAction.keyLost);
    expect(a.ledger.epochCounterHigh, 0);
  });

  test('a joiner is handed the inviter anchors with their revoked flags', () async {
    final [a, b, c, d] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 90 + i)];
    await pairAll([a, b, c]);
    await a.removeMember(c.memberId);
    await SyncDevice.pair(inviter: a, joiner: d);
    expect(d.membership.revokedAnchorIds, {c.memberId});
    expect(d.membership.anchors.map((m) => m.memberId), contains(c.memberId));
    expect(d.membership.activeMembers.map((m) => m.memberId), isNot(contains(c.memberId)));
  });

  test('runs are deterministic: the same seeds give the same end state and session outcomes', () async {
    Future<String> run() async {
      final clock = TestClock();
      final devices = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 30 + i, clock: clock)];
      await pairAll(devices);
      final outcomes = <String>[];
      for (var i = 0; i < 30; i++) {
        clock.advance(7);
        createRow(devices[i % 3], 'r${i % 11}', 'v$i');
        if (i % 4 == 3) devices[(i + 1) % 3].delete(row('r${i % 5}'));
        final p = await runSessionPair(
          devices[i % 3],
          devices[(i + 1) % 3],
          faults: i % 5 == 0 ? TransportFaults(cutAfter: 6 + i % 7) : TransportFaults.none,
        );
        outcomes.add('${p.initiator.runtimeType}/${p.initiator.stats.envelopesSent}/'
            '${p.responder.runtimeType}/${p.responder.stats.envelopesSent}');
      }
      await syncUntilQuiet(devices);
      return [...outcomes, for (final d in devices) fingerprint(d.store, security: true)].join('\n');
    }

    expect(await run(), await run());
  });
}
