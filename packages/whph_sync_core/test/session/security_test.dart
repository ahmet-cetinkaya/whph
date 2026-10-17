/// T12 security at engine level: membership refusal (FR-020, FR-028),
/// tampering (FR-021, FR-022), revocation cutoffs (FR-026), missing epoch
/// keys (SC-014), protocol incompatibility (FR-041).
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

Future<List<SyncDevice>> _paired(List<String> names, int seed, {TestClock? clock}) async {
  final c = clock ?? TestClock();
  final devices = [for (var i = 0; i < names.length; i++) await newDevice(names[i], seed: seed + i, clock: c)];
  await pairAll(devices);
  return devices;
}

ChangeEnvelope _withCiphertext(ChangeEnvelope e, Uint8List ciphertext) => ChangeEnvelope(
      tbl: e.tbl,
      pk: e.pk,
      col: e.col,
      hlc: e.hlc,
      node: e.node,
      origin: e.origin,
      originSeq: e.originSeq,
      cause: e.cause,
      epoch: e.epoch,
      nonce: e.nonce,
      ciphertext: ciphertext,
      keyWrap: e.keyWrap,
      protocolVersion: e.protocolVersion,
    );

ChangeBatchMessage _replace(ChangeBatchMessage b, {List<OriginManifest>? manifests, List<ChangeEnvelope>? envelopes}) =>
    ChangeBatchMessage(
      batchId: b.batchId,
      ranges: b.ranges,
      manifests: manifests ?? b.manifests,
      envelopes: envelopes ?? b.envelopes,
    );

void main() {
  group('membership (FR-020, FR-028)', () {
    test('a non-member static key is refused before any user data', () async {
      final [a, b] = await _paired(['A', 'B'], 1);
      final [x, y] = await _paired(['X', 'Y'], 10);
      createRow(a, 'secret', 'not for X');
      final before = content(x.store);
      for (final (i, r) in [(x, a), (a, x)]) {
        final p = await SyncDevice.syncPair(i, r);
        expect(
            (p.initiator as SessionFailed).category, anyOf(SessionFailure.notAuthorized, SessionFailure.notReachable));
        expect(p.responder, isA<SessionFailed>());
        expect(p.initiator.stats.envelopesReceived + p.responder.stats.envelopesReceived, 0);
      }
      expect(content(x.store), before);
      expect((await SyncDevice.syncPair(a, b)).bothComplete, isTrue);
      expect((await SyncDevice.syncPair(x, y)).bothComplete, isTrue);
    });

    test('a removed member that still trusts the group is refused at authentication (FR-026)', () async {
      final [a, b, c] = await _paired(['A', 'B', 'C'], 20);
      await syncUntilQuiet([a, b, c]);
      await a.removeMember(c.memberId);
      final p = await SyncDevice.syncPair(c, a);
      expect((p.responder as SessionFailed).category, SessionFailure.notAuthorized);
      expect((p.initiator as SessionFailed).category, SessionFailure.refusedByPeer);
      expect(p.initiator.stats.envelopesSent, 0);
      // B learns the removal from A and refuses C too; the new epoch never
      // reaches C.
      expect((await SyncDevice.syncPair(a, b)).bothComplete, isTrue);
      expect((await SyncDevice.syncPair(c, b)).responder, isA<SessionFailed>());
      final newest = a.membership.keyring.highest!;
      expect(b.membership.keyring.holds(newest), isTrue);
      expect(c.membership.keyring.holds(newest), isFalse, reason: 'changes after removal are unreadable for C');
    });
  });

  group('tampering (FR-021, FR-022)', () {
    test('an envelope altered in transit is rejected and counted; the others apply', () async {
      final [a, b] = await _paired(['A', 'B'], 30);
      for (var i = 0; i < 5; i++) {
        createRow(a, 'r$i', 'title $i');
      }
      var tampered = 0;
      final r = await SyncDevice.syncPair(
        a,
        b,
        hooksA: SessionHooks(outgoingBatch: (batch) {
          final envelopes = [
            for (final e in batch.envelopes)
              if (e.pk == 'r2' && e.col == 'title' && tampered++ == 0)
                _withCiphertext(e, Uint8List.fromList(e.ciphertext)..[0] ^= 1)
              else
                e,
          ];
          return _replace(batch, envelopes: envelopes);
        }),
      );
      expect(tampered, 1);
      final bSide = r.responder as SessionPartial;
      expect(bSide.reasons, {PartialReason.itemsRejected});
      expect(bSide.stats.rejectedByReason, {'envelope': 1});
      expect(b.store.read(const CellKey('task', 'r2', 'title')), isNull);
      expect(b.store.read(const CellKey('task', 'r3', 'title'))?.value, 'title 3');
    });

    test('a manifest altered in transit is rejected and none of its changes is applied', () async {
      final [a, b] = await _paired(['A', 'B'], 40);
      createRow(a, 'r0', 'x');
      final r = await SyncDevice.syncPair(
        a,
        b,
        hooksA: SessionHooks(outgoingBatch: (batch) {
          final manifests = [
            for (final m in batch.manifests)
              OriginManifest(
                origin: m.origin,
                fromSeq: m.fromSeq,
                toSeq: m.toSeq,
                hashes: [for (final (i, h) in m.hashes.indexed) i == 0 ? (Uint8List.fromList(h)..[0] ^= 1) : h],
                sig: m.sig,
              ),
          ];
          return _replace(batch, manifests: manifests);
        }),
      );
      final bSide = r.responder as SessionPartial;
      expect(bSide.reasons, {PartialReason.itemsRejected});
      expect(bSide.stats.rejectedByReason.keys, contains('badSignature'));
      expect(bSide.stats.applied, 0);
      expect(aliveRows(b.store, 'task'), isEmpty);
    });

    for (final (name, faults) in [
      ('replayed', const TransportFaults(duplicate: {7})),
      ('reordered', const TransportFaults(reorder: {6})),
    ]) {
      test('a $name Noise frame tears the session down; the next session converges', () async {
        final [a, b] = await _paired(['A', 'B'], 50);
        for (var i = 0; i < 50; i++) {
          createRow(a, 'r$i', 't$i');
        }
        final r = await SyncDevice.syncPair(a, b, faults: faults);
        final failures = [r.initiator, r.responder].whereType<SessionFailed>().map((f) => f.category).toSet();
        expect(failures, contains(SessionFailure.securityError), reason: '$r');
        final ok = await SyncDevice.syncPair(a, b);
        expect(ok.bothComplete, isTrue);
        expect(content(a.store), content(b.store));
      });
    }

    test('an altered Noise frame tears the session down', () async {
      final [a, b] = await _paired(['A', 'B'], 60);
      createRow(a, 'r', 't');
      final r = await SyncDevice.syncPair(
        a,
        b,
        faults: TransportFaults(tamper: (i, f) => i == 8 ? (f..[f.length - 1] ^= 1) : f),
      );
      expect([r.initiator, r.responder].whereType<SessionFailed>().map((f) => f.category),
          contains(SessionFailure.securityError));
    });
  });

  test('a revoked member\'s changes above its cutoff are rejected; relayed ones converge via self-extension', () async {
    final clock = TestClock();
    final [a, b, c] = await _paired(['A', 'B', 'C'], 70, clock: clock);
    createRow(c, 'c1', 'before removal');
    await syncUntilQuiet([a, b, c]);
    await a.removeMember(c.memberId);
    final cOrigin = c.store.localOrigin;
    final cutoff = a.membership.revocations!.cutoffFor(cOrigin, a.membership.registry!);
    expect(cutoff, c.store.highestOwnSeq);

    // C keeps writing; B has not learned of the removal and takes it.
    clock.advance(1000);
    createRow(c, 'c2', 'after removal');
    expect((await SyncDevice.syncPair(c, b)).bothComplete, isTrue);
    // B relays C's post-removal change to A: A rejects it (above cutoff).
    final relay = await SyncDevice.syncPair(b, a);
    expect(relay.responder, isA<SessionPartial>());
    expect(relay.responder.stats.rejectedByReason['revokedAboveCutoff'], greaterThan(0));
    expect(a.store.isRowAlive('task', 'c2'), isFalse);
    // B now knows the removal and refuses C.
    expect((await SyncDevice.syncPair(c, b)).responder, isA<SessionFailed>());
    // B held c2 when it learned the removal: it extends the cutoff (D7), so
    // every member ends with the same accepted set.
    await syncUntilQuiet([a, b]);
    expect(a.store.isRowAlive('task', 'c2'), isTrue);
    expect(content(a.store), content(b.store));
    // Anything C writes now never enters the group.
    createRow(c, 'c3', 'never accepted');
    expect((await SyncDevice.syncPair(c, a)).initiator, isA<SessionFailed>());
    expect((await SyncDevice.syncPair(c, b)).initiator, isA<SessionFailed>());
    expect(a.store.rowsOf('task'), isNot(contains('c3')));
  });

  test('SC-014: a change whose epoch key is missing is held, forwarded as ciphertext, applied when the key arrives',
      () async {
    final [a, b, c] = await _paired(['A', 'B', 'C'], 80);
    await syncUntilQuiet([a, b, c]);
    // An epoch key only A will hold, handed over later.
    final laterEpoch = EpochId(9, a.memberId);
    final laterKey = Uint8List.fromList(List.generate(32, (i) => i * 7 + 3));
    final sideRing = GroupKeyring()..add(laterEpoch, laterKey);
    final g = a.membership.groupId!;
    createRow(a, 'k', 'sealed under a later epoch');
    ChangeBatchMessage reseal(ChangeBatchMessage batch) {
      final open = EnvelopeCipher(groupId: g, keyring: a.membership.keyring);
      final seal = EnvelopeCipher(groupId: g, keyring: sideRing);
      final nonces = NonceSource();
      return _replace(batch, envelopes: [
        for (final e in batch.envelopes)
          if (e.pk == 'k') seal.seal((open.open(e) as EnvelopeOpened).change, nonces, epoch: laterEpoch) else e,
      ]);
    }

    final first = await SyncDevice.syncPair(a, b, hooksA: SessionHooks(outgoingBatch: reseal));
    expect(first.bothComplete, isTrue, reason: 'held for a missing key is not a failure');
    expect(first.responder.stats.heldMissingKey, 2);
    expect(b.store.heldEnvelopes.map((h) => h.reason).toSet(), {HeldReason.missingKey});
    expect(b.store.isRowAlive('task', 'k'), isFalse);

    // B forwards the ciphertext verbatim to C, which cannot read it either.
    final ciphertexts = {for (final h in b.store.heldEnvelopes) h.envelope.ciphertext.toString()};
    final relay = await SyncDevice.syncPair(b, c);
    expect(relay.bothComplete, isTrue);
    expect(relay.initiator.stats.heldRelayed, 2);
    expect({for (final h in c.store.heldEnvelopes) h.envelope.ciphertext.toString()}, ciphertexts);
    expect(c.store.isRowAlive('task', 'k'), isFalse);

    // The key reaches A's keyring; A hands it to B, B to C; both apply.
    a.membership.keyring.add(laterEpoch, laterKey);
    final handover = await SyncDevice.syncPair(a, b);
    expect(handover.bothComplete, isTrue);
    expect(handover.initiator.stats.keysHandedOver, 1);
    expect(b.store.isRowAlive('task', 'k'), isTrue);
    expect(b.store.heldEnvelopes, isEmpty);
    expect((await SyncDevice.syncPair(b, c)).bothComplete, isTrue);
    expect(c.store.isRowAlive('task', 'k'), isTrue);
    expect(c.store.heldEnvelopes, isEmpty);
    expect(c.peerState(b.memberId).itemsCannotBeApplied, isFalse);
  });

  test('UpdateRequired on incompatible protocol versions with 0 changes exchanged (FR-041)', () async {
    final clock = TestClock();
    final a = await newDevice('A', seed: 90, clock: clock);
    final b = await newDevice('B',
        seed: 91,
        clock: clock,
        config: testConfig(protocolVersion: syncProtocolVersion + 1, minCompatible: syncProtocolVersion + 1));
    await SyncDevice.pair(inviter: a, joiner: b);
    createRow(a, 'r', 'v');
    createRow(b, 's', 'w');
    for (final (i, r) in [(a, b), (b, a)]) {
      final p = await SyncDevice.syncPair(i, r);
      for (final side in [p.initiator, p.responder]) {
        final f = side as SessionFailed;
        expect(f.category, SessionFailure.needsUpdate);
        expect(f.mustUpdate?.memberId, a.memberId, reason: 'the older device is named on both sides');
        expect(f.stats.envelopesSent + f.stats.envelopesReceived, 0);
      }
    }
    expect(a.store.rowsOf('task'), ['r']);
    expect(b.store.rowsOf('task'), ['s']);
  });
}
