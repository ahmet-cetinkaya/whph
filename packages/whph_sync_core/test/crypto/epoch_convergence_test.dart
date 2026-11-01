// T11 acc 5: 1,000 random concurrent-removal schedules converge on one
// highest epoch that no revoked key holds (re-rotation rule, D7), including
// schedules where a member about to be removed plants epochs without a
// self-grant, hands over colliding epoch ids, hands over far-future epochs
// (M1, M2), publishes phantom grant rows for unheld epochs (F2) or ratchets
// an honest member up by two within-bound jumps (F1).
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _pubOf(int i) => Uint8List.fromList(List.generate(32, (j) => (i * 37 + j) & 0xff));

final class _Member {
  _Member(this.id, this.pub);

  final String id;
  final Uint8List pub;
  GroupKeyring keyring = GroupKeyring();
  final Set<EpochGrant> grants = {};
  final Set<String> revoked = {};
  bool removed = false;

  bool isRevoked(List<int> pub) => revoked.contains(_hex(pub));

  Set<EpochId> get known => {...grants.map((g) => g.epoch), ...keyring.epochs};

  String get signature =>
      '${keyring.epochs.length}/${keyring.conflictedEpochs.length}/${grants.length}/${revoked.length}/$removed';

  /// Rotation; an honest member records its self-grant, a planter may not.
  EpochId rotate({bool selfGrant = true}) {
    final id = keyring.rotate(this.id);
    if (selfGrant) grants.add(EpochGrant(id, pub));
    return id;
  }

  void maybeRotate() {
    if (removed) return;
    if (EpochRules.mustRotate(
      knownEpochs: known,
      heldEpochs: keyring.epochs,
      grants: grants,
      isRevoked: isRevoked,
      conflictedEpochs: keyring.conflictedEpochs,
    )) {
      rotate();
    }
  }

  void checkRemoved() {
    if (!removed && revoked.contains(_hex(pub))) {
      removed = true;
      keyring.destroy();
      keyring = GroupKeyring();
    }
  }
}

final class _World {
  _World(this.members) : _pubs = {for (final m in members) m.id: m.pub};

  final List<_Member> members;
  final Map<String, Uint8List> _pubs;

  /// Ground truth, independent of grant rows: every member id that ever
  /// held each `(epoch id, key bytes)`.
  final Map<String, Set<String>> everHeld = {};

  /// Handed-over epochs skipped as too far ahead (F1), across all deliveries.
  int skipped = 0;

  static String keyOf(EpochId e, List<int> key) => '$e/${_hex(key)}';

  Uint8List? pubOf(String memberId) => _pubs[memberId];

  void observe() {
    for (final m in members) {
      for (final e in m.keyring.epochs) {
        everHeld.putIfAbsent(keyOf(e, m.keyring.keyFor(e)!), () => {}).add(m.id);
      }
    }
  }

  /// [taker] stores [keys] from [giver] through the receive-side API and
  /// both record the resulting grant rows.
  HandoverAcceptResult deliver(_Member giver, _Member taker, List<EpochKeyGrant> keys) {
    final res = taker.keyring.acceptHandover(fromPub: giver.pub, ownPub: taker.pub, keys: keys, creatorPubOf: pubOf);
    giver.grants.addAll(res.grants);
    taker.grants.addAll(res.grants);
    skipped += res.skipped.length;
    observe();
    return res;
  }

  /// One authenticated session: refused when either side knows the other is
  /// revoked or has left. Metadata (grants, revocations) is exchanged, then
  /// each side hands over the epoch keys the peer lacks.
  void sync(_Member a, _Member b) {
    if (a.removed || b.removed || a.isRevoked(b.pub) || b.isRevoked(a.pub)) return;
    final grants = {...a.grants, ...b.grants};
    final revoked = {...a.revoked, ...b.revoked};
    for (final m in [a, b]) {
      m.grants
        ..clear()
        ..addAll(grants);
      m.revoked
        ..clear()
        ..addAll(revoked);
      m.checkRemoved();
    }
    if (a.removed || b.removed) return;
    for (final (giver, taker) in [(a, b), (b, a)]) {
      final (keys, giverGrants) = giver.keyring
          .handoverTo(peerPub: taker.pub, peerHas: taker.keyring.epochs, peerIsRevoked: giver.isRevoked(taker.pub));
      a.grants.addAll(giverGrants);
      b.grants.addAll(giverGrants);
      if (keys.isNotEmpty) deliver(giver, taker, keys);
    }
    a.maybeRotate();
    b.maybeRotate();
    observe();
  }
}

void main() {
  test('1,000 random concurrent-removal schedules with hostile planters converge (acc 5, M1, M2)', () {
    final rng = Random(20260927);
    var totalRotations = 0;
    var concurrentSchedules = 0;
    final hostile = {
      'plantNoSelfGrant': 0,
      'plantSelfGrantOnly': 0,
      'collideHeld': 0,
      'collideFuture': 0,
      'jump': 0,
      'phantomLive': 0,
      'phantomRevoked': 0,
      'ratchet': 0,
    };
    var skippedTotal = 0;
    var conflictsSeen = 0;
    for (var schedule = 0; schedule < 1000; schedule++) {
      final n = 4 + rng.nextInt(4); // 4..7 members
      final members = [for (var i = 0; i < n; i++) _Member('m$i', _pubOf(i))];
      final world = _World(members);
      // Two members are never removed and act as revokers; the others may be removed.
      final actors = members.take(2).toList();
      final targets = members.skip(2).toList();
      final revokedGlobal = <String>{};
      final planters = <_Member>{};

      void revoke(_Member actor, _Member target) {
        actor.revoked.add(_hex(target.pub));
        revokedGlobal.add(_hex(target.pub));
        actor.rotate(); // revocation triggers rotation
        world.observe();
      }

      members[0].rotate(); // group creation: epoch (1, m0)
      world.observe();
      for (final m in members.skip(1)) {
        world.sync(members[0], m);
      }

      final steps = 5 + rng.nextInt(40);
      var revocationsBeforeSync = 0;
      for (var s = 0; s < steps; s++) {
        final r = rng.nextInt(14);
        if (r < 3) {
          // Concurrent removal: an actor revokes a target without syncing first.
          revoke(actors[rng.nextInt(actors.length)], targets[rng.nextInt(targets.length)]);
          revocationsBeforeSync++;
        } else if (r < 6) {
          // A target about to be removed misbehaves (only while nobody it
          // talks to knows it is revoked).
          final t = targets[rng.nextInt(targets.length)];
          final victims = members.where((v) => !identical(v, t) && !v.removed && !v.isRevoked(t.pub)).toList();
          if (t.removed || victims.isEmpty) continue;
          final victim = victims[rng.nextInt(victims.length)];
          planters.add(t);
          switch (rng.nextInt(8)) {
            case 0:
              // Plant a new highest epoch without a self-grant; normal
              // handovers spread it.
              t.rotate(selfGrant: false);
              world.observe();
              hostile['plantNoSelfGrant'] = hostile['plantNoSelfGrant']! + 1;
            case 1:
              // Publish a self-grant row for a planted epoch whose key is
              // never handed over (nobody else can ever hold it).
              t.grants.add(EpochGrant(EpochRules.next(EpochRules.highest(t.known), t.id), t.pub));
              hostile['plantSelfGrantOnly'] = hostile['plantSelfGrantOnly']! + 1;
            case 2:
              // Hand over a different key for an epoch id the victim holds
              // (bypassing peerHas).
              final held = victim.keyring.epochs.toList()..sort();
              final id = held.last;
              world.deliver(t, victim, [EpochKeyGrant(epoch: id, key: List.filled(32, 0xA0 ^ (s & 0x3f)))]);
              victim.maybeRotate();
              world.observe();
              hostile['collideHeld'] = hostile['collideHeld']! + 1;
            case 3:
              // Pre-empt an actor's next epoch id with an own key.
              final actor = actors[rng.nextInt(actors.length)];
              final id = EpochRules.next(EpochRules.highest(t.known), actor.id);
              if (!t.keyring.holds(id)) t.keyring.add(id, List.filled(32, 0xC0 ^ (s & 0x3f)));
              world.deliver(t, victim, [EpochKeyGrant(epoch: id, key: t.keyring.keyFor(id)!)]);
              victim.maybeRotate();
              world.observe();
              hostile['collideFuture'] = hostile['collideFuture']! + 1;
            case 4:
              // Far-future epoch (M1, F1): skipped, nothing stored, no grant.
              final top = victim.keyring.highest!;
              final far = EpochId(top.counter + EpochRules.maxCounterJump + 1 + rng.nextInt(1 << 20), t.id);
              final before = victim.keyring.epochs;
              final res = world.deliver(t, victim, [EpochKeyGrant(epoch: far, key: List.filled(32, 7))]);
              expect(res.skipped, [far]);
              expect(res.added, isEmpty);
              expect(res.grants, isEmpty);
              expect(victim.keyring.epochs, before);
              hostile['jump'] = hostile['jump']! + 1;
            case 5:
              // Phantom grant row (F2): an unheld epoch at the victim's
              // highest held counter + 2^16, granted to a live key.
              final top = victim.keyring.highest!;
              final phantom = EpochId(top.counter + EpochRules.maxCounterJump, t.id);
              final row = EpochGrant(phantom, actors[rng.nextInt(actors.length)].pub);
              t.grants.add(row);
              victim.grants.add(row);
              victim.maybeRotate();
              world.observe();
              hostile['phantomLive'] = hostile['phantomLive']! + 1;
            case 6:
              // Phantom grant row (F2) granted to a revoked key (or to the
              // planter, which is revoked by the end of the schedule).
              final top = victim.keyring.highest!;
              final phantom = EpochId(top.counter + EpochRules.maxCounterJump, t.id);
              final revokedMembers = members.where((m) => revokedGlobal.contains(_hex(m.pub))).toList();
              final pub = revokedMembers.isEmpty ? t.pub : revokedMembers[rng.nextInt(revokedMembers.length)].pub;
              final row = EpochGrant(phantom, pub);
              t.grants.add(row);
              victim.grants.add(row);
              victim.maybeRotate();
              world.observe();
              hostile['phantomRevoked'] = hostile['phantomRevoked']! + 1;
            default:
              // Double ratchet within the bound (F1): the victim is handed
              // top + 2^16, then top + 2^17, in two sessions; its peers catch
              // up one 2^16 window per session.
              final top = victim.keyring.highest!.counter;
              for (final (i, e) in [
                EpochId(top + EpochRules.maxCounterJump, t.id),
                EpochId(top + 2 * EpochRules.maxCounterJump, t.id),
              ].indexed) {
                if (!t.keyring.holds(e)) t.keyring.add(e, List.filled(32, 0xE0 ^ (i << 4) ^ (s & 0x0f)));
                final res = world.deliver(t, victim, [EpochKeyGrant(epoch: e, key: t.keyring.keyFor(e)!)]);
                expect(res.skipped, isEmpty);
                expect(victim.keyring.holds(e), isTrue);
              }
              victim.maybeRotate();
              world.observe();
              hostile['ratchet'] = hostile['ratchet']! + 1;
          }
        } else {
          final a = members[rng.nextInt(n)];
          final b = members[rng.nextInt(n)];
          if (!identical(a, b)) world.sync(a, b);
          if (revocationsBeforeSync > 1) concurrentSchedules++;
          revocationsBeforeSync = 0;
        }
      }
      if (revokedGlobal.isEmpty) revoke(actors[1], targets.first);
      // Every planter is eventually removed (the premise of D7 convergence).
      for (final p in planters) {
        if (!revokedGlobal.contains(_hex(p.pub))) revoke(actors[1], p);
      }

      // Anti-entropy until quiescent.
      var rounds = 0;
      while (true) {
        final before = members.map((m) => m.signature).join('|');
        for (var i = 0; i < n; i++) {
          for (var j = 0; j < n; j++) {
            if (i != j) world.sync(members[i], members[j]);
          }
        }
        if (members.map((m) => m.signature).join('|') == before) break;
        expect(++rounds, lessThan(50), reason: 'schedule $schedule does not quiesce');
      }

      final live = members.where((m) => !revokedGlobal.contains(_hex(m.pub))).toList();
      // The top epoch is the highest one a live member holds; phantom grant
      // rows (never held) do not count. Every live member must hold it with
      // the same key (no live member is partitioned).
      final top = EpochRules.highest(live.expand((m) => m.keyring.epochs))!;
      final topKey = live.first.keyring.keyFor(top);
      expect(topKey, isNotNull, reason: 'schedule $schedule: ${live.first.id} lacks $top');
      for (final m in live) {
        expect(m.removed, isFalse);
        expect(m.keyring.highest, top, reason: 'schedule $schedule: ${m.id} highest');
        expect(m.keyring.keyFor(top), orderedEquals(topKey!), reason: 'schedule $schedule: ${m.id} key of $top');
        expect(m.revoked, containsAll(revokedGlobal));
        conflictsSeen += m.keyring.conflictedEpochs.length;
      }
      final allGrants = live.expand((m) => m.grants).toSet();
      expect(EpochRules.grantedToRevoked(top, allGrants, (p) => revokedGlobal.contains(_hex(p))), isFalse,
          reason: 'schedule $schedule: top epoch granted to a revoked key');
      // Ground truth: no revoked member ever held a key under the top id.
      final revokedIds = {
        for (final m in members)
          if (revokedGlobal.contains(_hex(m.pub))) m.id
      };
      expect(world.everHeld[_World.keyOf(top, topKey!)]!.intersection(revokedIds), isEmpty,
          reason: 'schedule $schedule: the key of $top was held by a revoked member');
      // A revoked planter may still hold its own forged key under the top id
      // (it was never delivered to a live member); it must not hold the
      // group's key.
      for (final m in members.where((m) => revokedGlobal.contains(_hex(m.pub)))) {
        final held = m.keyring.keyFor(top);
        expect(held != null && _hex(held) == _hex(topKey), isFalse,
            reason: 'schedule $schedule: revoked ${m.id} holds the key of $top');
      }
      totalRotations += top.counter;
      skippedTotal += world.skipped;
    }
    for (final e in hostile.entries) {
      expect(e.value, greaterThan(50), reason: 'hostile action ${e.key} exercised too rarely');
    }
    expect(conflictsSeen, greaterThan(0));
    expect(skippedTotal, greaterThan(0), reason: 'the double ratchet never forced a windowed catch-up');
    // ignore: avoid_print
    print('[T11] acc5: 1000 schedules converged; mean top counter ${(totalRotations / 1000).toStringAsFixed(2)}, '
        '$concurrentSchedules bursts of >1 concurrent removal between syncs; hostile actions $hostile; '
        '$conflictsSeen conflicted epochs at the end; $skippedTotal handed-over epochs skipped (F1 windows)');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('concurrent rotations tie-break deterministically on the creator id', () {
    final a = EpochId(3, 'member-a');
    final b = EpochId(3, 'member-b');
    expect(EpochRules.highest([a, b]), b);
    expect(EpochRules.highest([b, a]), b);
    expect(EpochRules.next(b, 'member-a'), EpochId(4, 'member-a'));
    expect(EpochRules.initial('m'), EpochId(1, 'm'));
  });

  test('keyring refuses a conflicting key via add (local load); handover skips revoked peers', () {
    final k = GroupKeyring()..add(EpochId(1, 'a'), Uint8List(32));
    expect(k.add(EpochId(1, 'a'), Uint8List(32)), isFalse);
    expect(() => k.add(EpochId(1, 'a'), Uint8List(32)..[0] = 1), throwsA(isA<InvalidKeyMaterialException>()));
    final (keys, grants) = k.handoverTo(peerPub: Uint8List(32), peerHas: const {}, peerIsRevoked: true);
    expect(keys, isEmpty);
    expect(grants, isEmpty);
    k.destroy();
    expect(() => k.keyFor(EpochId(1, 'a')), throwsStateError);
  });

  group('M1: epoch counter bounds', () {
    final own = _pubOf(1);
    final peer = _pubOf(2);

    test('next throws a typed exception at 2^53 instead of wrapping', () {
      expect(EpochRules.next(EpochId(EpochId.maxCounter - 1, 'a'), 'b'), EpochId(EpochId.maxCounter, 'b'));
      expect(() => EpochRules.next(EpochId(EpochId.maxCounter, 'a'), 'b'), throwsA(isA<EpochCounterException>()));
      final k = GroupKeyring()..add(EpochId(EpochId.maxCounter, 'a'), Uint8List(32));
      expect(() => k.rotate('b'), throwsA(isA<EpochCounterException>()));
    });

    test('F1: a far-future epoch is skipped, never thrown; the rest of the handover is stored', () {
      final k = GroupKeyring()..add(EpochId(5, 'a'), Uint8List(32));
      final hostile = EpochId(5 + EpochRules.maxCounterJump + 1, 'x');
      final huge = EpochId(EpochId.maxCounter, 'x');
      final res = k.acceptHandover(fromPub: peer, ownPub: own, keys: [
        EpochKeyGrant(epoch: EpochId(6, 'b'), key: List.filled(32, 1)),
        EpochKeyGrant(epoch: hostile, key: List.filled(32, 2)),
        EpochKeyGrant(epoch: huge, key: List.filled(32, 3)),
      ]);
      expect(res.added, [EpochId(6, 'b')]);
      expect(res.skipped, [hostile, huge]);
      expect(res.grants.map((g) => g.epoch).toSet(), {EpochId(6, 'b')}, reason: 'no grant for skipped epochs');
      expect(k.epochs, {EpochId(5, 'a'), EpochId(6, 'b')});
      // Hostile grant rows naming the far epochs (granted to a revoked key)
      // neither force nor shape rotation.
      final hostileGrants = [EpochGrant(huge, peer), EpochGrant(hostile, peer)];
      bool revoked(Uint8List p) => _hex(p) == _hex(peer);
      expect(
        EpochRules.mustRotate(
            knownEpochs: [huge, hostile], heldEpochs: k.epochs, grants: hostileGrants, isRevoked: revoked),
        isFalse,
      );
      expect(k.rotate('a'), EpochId(7, 'a'));
      // The bound is measured from the highest epoch held before the call:
      // the edge is stored, one past it is skipped even though the edge is
      // stored by the same call.
      final edge = EpochId(7 + EpochRules.maxCounterJump, 'x');
      final past = EpochId(7 + EpochRules.maxCounterJump + 1, 'x');
      final res2 = k.acceptHandover(fromPub: peer, ownPub: own, keys: [
        EpochKeyGrant(epoch: edge, key: Uint8List(32)),
        EpochKeyGrant(epoch: past, key: Uint8List(32)),
      ]);
      expect(res2.added, [edge]);
      expect(res2.skipped, [past]);
      expect(k.rotate('a'), EpochId(past.counter, 'a'));
    });

    test('F1: a double ratchet within the bound delays a peer but never partitions it', () {
      const t = 10;
      const j = EpochRules.maxCounterJump;
      final planter = _pubOf(3);
      final hPub = _pubOf(4);
      final base = EpochId(t, 'm0');
      final h = GroupKeyring()..add(base, List.filled(32, 1));
      final m = GroupKeyring()..add(base, List.filled(32, 1));
      final e1 = EpochId(t + j, 'p');
      final e2 = EpochId(t + 2 * j, 'p');
      // H is ratcheted up in two sessions, each within the bound.
      expect(
          h.acceptHandover(
              fromPub: planter, ownPub: hPub, keys: [EpochKeyGrant(epoch: e1, key: List.filled(32, 2))]).added,
          [e1]);
      expect(
          h.acceptHandover(
              fromPub: planter, ownPub: hPub, keys: [EpochKeyGrant(epoch: e2, key: List.filled(32, 3))]).added,
          [e2]);
      expect(h.highest, e2);
      // Session 1: H (at T + 2^17) hands over to M (at T).
      var (keys, _) = h.handoverTo(peerPub: own, peerHas: m.epochs, peerIsRevoked: false);
      expect(keys.map((k) => k.epoch), [e1, e2]);
      final r1 = m.acceptHandover(fromPub: hPub, ownPub: own, keys: keys);
      expect(r1.added, [e1]);
      expect(r1.skipped, [e2]);
      expect(r1.grants.any((g) => g.epoch == e2), isFalse);
      expect(m.highest, e1);
      // Session 2: M catches up.
      (keys, _) = h.handoverTo(peerPub: own, peerHas: m.epochs, peerIsRevoked: false);
      final r2 = m.acceptHandover(fromPub: hPub, ownPub: own, keys: keys);
      expect(r2.added, [e2]);
      expect(r2.skipped, isEmpty);
      expect(m.highest, e2);
      expect(m.keyFor(e2), h.keyFor(e2));
    });

    test('an empty keyring (joining at pairing) accepts any bounded counter', () {
      final k = GroupKeyring();
      final e = EpochId(1 << 40, 'a');
      expect(
          k.acceptHandover(fromPub: peer, ownPub: own, keys: [EpochKeyGrant(epoch: e, key: Uint8List(32))]).added, [e]);
    });
  });

  group('M2: receive-side grants and colliding epoch ids', () {
    final own = _pubOf(1);
    final sender = _pubOf(2);
    final creator = _pubOf(3);
    final pubs = {'me': own, 'sender': sender, 'planter': creator};

    test('acceptHandover records receiver, sender and creator grants', () {
      final k = GroupKeyring()..add(EpochId(1, 'me'), Uint8List(32));
      final planted = EpochId(2, 'planter');
      final res = k.acceptHandover(
        fromPub: sender,
        ownPub: own,
        keys: [EpochKeyGrant(epoch: planted, key: List.filled(32, 9))],
        creatorPubOf: (id) => pubs[id],
      );
      expect(res.added, [planted]);
      expect(res.conflicted, isEmpty);
      expect(res.grants.toSet(), {EpochGrant(planted, own), EpochGrant(planted, sender), EpochGrant(planted, creator)});
      // The planter never self-granted, yet once it is revoked the holder rotates.
      bool isRevoked(Uint8List p) => _hex(p) == _hex(creator);
      expect(
        EpochRules.mustRotate(knownEpochs: k.epochs, heldEpochs: k.epochs, grants: res.grants, isRevoked: isRevoked),
        isTrue,
      );
      // Without the creator resolver the sender grant still names the planter
      // when it handed the key over itself.
      final k2 = GroupKeyring()..add(EpochId(1, 'me'), Uint8List(32));
      final res2 = k2.acceptHandover(
          fromPub: creator, ownPub: own, keys: [EpochKeyGrant(epoch: planted, key: List.filled(32, 9))]);
      expect(EpochRules.grantedToRevoked(planted, res2.grants, isRevoked), isTrue);
    });

    test('a colliding key never throws, keeps the first key, and forces rotation past it', () {
      final e = EpochId(3, 'other');
      final k = GroupKeyring()..add(e, List.filled(32, 1));
      final res = k.acceptHandover(fromPub: sender, ownPub: own, keys: [
        EpochKeyGrant(epoch: e, key: List.filled(32, 2)),
        EpochKeyGrant(epoch: e, key: List.filled(32, 2)), // repeated: reported once
      ]);
      expect(res.added, isEmpty);
      expect(res.conflicted, [e]);
      expect(k.keyFor(e), List.filled(32, 1), reason: 'first key kept');
      expect(k.conflictedEpochs, {e});
      // Repeating the hostile handover is still no error.
      expect(
          k.acceptHandover(
              fromPub: sender, ownPub: own, keys: [EpochKeyGrant(epoch: e, key: List.filled(32, 3))]).conflicted,
          isEmpty);
      bool none(Uint8List _) => false;
      bool mustRotate() => EpochRules.mustRotate(
          knownEpochs: k.epochs,
          heldEpochs: k.epochs,
          grants: const [],
          isRevoked: none,
          conflictedEpochs: k.conflictedEpochs);
      expect(mustRotate(), isTrue);
      expect(k.rotate('me'), EpochId(4, 'me'));
      expect(mustRotate(), isFalse, reason: 'the conflict is superseded');
      // A same-key re-delivery is not a conflict.
      expect(
          k.acceptHandover(
              fromPub: sender,
              ownPub: own,
              keys: [EpochKeyGrant(epoch: EpochId(4, 'me'), key: k.keyFor(EpochId(4, 'me'))!)]).conflicted,
          isEmpty);
    });

    test('F2: an unheld phantom epoch does NOT force or shape rotation (planted grant, key withheld)', () {
      final k = GroupKeyring()..add(EpochId(2, 'me'), Uint8List(32));
      final planted = EpochId(3, 'planter');
      final phantomRevoked = EpochId(2 + EpochRules.maxCounterJump, 'planter');
      final phantomLive = EpochId(2 + EpochRules.maxCounterJump, 'other');
      bool isRevoked(Uint8List p) => _hex(p) == _hex(creator);
      final grants = [
        EpochGrant(planted, creator),
        EpochGrant(phantomRevoked, creator),
        EpochGrant(phantomLive, sender),
      ];
      final known = [...k.epochs, planted, phantomRevoked, phantomLive];
      bool mustRotate() => EpochRules.mustRotate(
          knownEpochs: known,
          heldEpochs: k.epochs,
          grants: grants,
          isRevoked: isRevoked,
          conflictedEpochs: k.conflictedEpochs);
      expect(mustRotate(), isFalse, reason: 'phantom rows granted to a revoked key do not force rotation');
      // A rotation for another reason builds on the highest held epoch only.
      expect(k.rotate('me'), EpochId(3, 'me'));
      expect(mustRotate(), isFalse);
      // Only the highest held epoch counts: a flagged lower held epoch does not.
      final k2 = GroupKeyring()
        ..add(planted, Uint8List(32))
        ..add(EpochId(4, 'me'), Uint8List(32));
      expect(
          EpochRules.mustRotate(
              heldEpochs: k2.epochs, grants: grants, isRevoked: isRevoked, conflictedEpochs: {planted}),
          isFalse);
      // Once the flagged epoch is actually held and highest, the rule fires.
      final k3 = GroupKeyring()
        ..add(EpochId(2, 'me'), Uint8List(32))
        ..add(planted, Uint8List(32));
      expect(EpochRules.mustRotate(heldEpochs: k3.epochs, grants: grants, isRevoked: isRevoked), isTrue);
    });
  });
}
