/// Signed revocation records kept in the sync ledger (U11/Efe-1..3): they
/// survive a data-folder restore, travel with the flags at pairing, leave
/// with the group, and their write is never skipped silently. The revoker key
/// kept next to a record grants no trust, a ledger write failure stops the
/// session's commits, and a flagged signer without a record is held
/// (U11/Efe-R1). A ledger-only record never self-extends, rotates or removes
/// this device (U11/Efe-R2, R3).
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

void main() {
  test('data_dir_restore_before_revocation_refuses_revoked_member', () async {
    final [a, b, r] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 110 + i)];
    await pairAll([a, b, r]);
    await syncUntilQuiet([a, b, r]);
    createRow(r, 'before', 'written before the revocation');
    expect((await runSessionPair(r, a)).bothComplete, isTrue);
    final beforeRemoval = await a.snapshotDirectory();
    await a.removeMember(r.memberId);
    final rotated = a.membership.keyring.highest!;
    createRow(r, 'after', 'written after the revocation');

    await a.restoreDirectory(beforeRemoval);
    final rPub = r.membership.identity.ed25519Pub;
    expect(a.store.rowsOf(SecurityTables.revocation), isEmpty, reason: 'the DB predates the revocation');
    expect(a.membership.keyring.holds(rotated), isFalse, reason: 'the key file predates the rotation');
    expect(a.membership.isRevokedEd(rPub), isTrue, reason: 'the ledger record was re-ingested');
    expect(a.membership.isExcluded(rPub), isTrue);
    expect(a.membership.flaggedAnchorsWithoutRecord, isEmpty);

    final attempt = await runSessionPair(r, a);
    expect((attempt.responder as SessionFailed).category, SessionFailure.notAuthorized);
    expect(attempt.responder.stats.keysHandedOver, 0);
    expect(r.membership.keyring.epochs, isNot(contains(rotated)));

    // B never heard of the revocation and relays R's cells to A.
    expect((await runSessionPair(r, b)).bothComplete, isTrue);
    await runSessionPair(b, a);
    expect(aliveRows(a.store, 'task'), contains('before'));
    expect(aliveRows(a.store, 'task'), isNot(contains('after')), reason: "R's post-revocation cell is rejected");
  });

  test('joiner_receives_revocation_records_for_flagged_anchors', () async {
    final [a, b, r, joiner] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 120 + i)];
    await pairAll([a, b, r]);
    await syncUntilQuiet([a, b, r]);
    createRow(r, 'before', 'written before the revocation');
    expect((await runSessionPair(r, a)).bothComplete, isTrue);
    await a.removeMember(r.memberId);
    createRow(r, 'after', 'written after the revocation');
    expect((await runSessionPair(r, b)).bothComplete, isTrue, reason: 'B is not informed yet');

    await SyncDevice.pair(inviter: a, joiner: joiner);
    final rPub = r.membership.identity.ed25519Pub;
    expect(joiner.membership.revokedAnchorIds, {r.memberId});
    expect(joiner.store.rowsOf(SecurityTables.revocation), isEmpty, reason: 'no normal sync ran yet');
    expect(joiner.membership.revocations!.cutoffOf(rPub, r.store.localOrigin), isNotNull);
    expect(joiner.membership.flaggedAnchorsWithoutRecord, isEmpty);

    // B pairs the joiner too, so the uninformed B can relay R's cells to it.
    await SyncDevice.pair(inviter: b, joiner: joiner);
    final relay = await runSessionPair(b, joiner);
    expect(relay.responder, isNot(isA<SessionFailed>()), reason: '$relay');
    expect(aliveRows(joiner.store, 'task'), contains('before'), reason: 'pre-cutoff cells are accepted');
    expect(aliveRows(joiner.store, 'task'), isNot(contains('after')), reason: 'post-cutoff cells are rejected');
  });

  test('group exit clears the revocation records of the ledger', () async {
    final [a, b, c, e, f] = [for (var i = 0; i < 5; i++) await newDevice('D$i', seed: 130 + i)];
    await pairAll([a, b, c]);
    await a.removeMember(c.memberId);
    expect(a.ledger.revocations, hasLength(1), reason: 'own revocation');
    expect((await runSessionPair(a, b)).bothComplete, isTrue);
    expect(b.ledger.revocations, hasLength(1), reason: 'received revocation');

    expect(await a.loseKeyFile(), StartupAction.keyLost);
    expect(a.ledger.revocations, isEmpty, reason: 'key loss');

    await SyncDevice.pair(inviter: e, joiner: f);
    await SyncDevice.pair(inviter: e, joiner: b, confirmGroupSwitch: true);
    expect(b.ledger.revocations, isEmpty, reason: 'group switch');
  });

  group('a revocation ledger write failure blocks the commit', () {
    test('own revocation: nothing is written', () async {
      final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 140 + i)];
      await pairAll([a, b, c]);
      final epochBefore = a.membership.keyring.highest;
      final ledger = a.ledger as InMemorySyncLedger;
      ledger.failAllRevocationWrites = true;
      await expectLater(a.removeMember(c.memberId), throwsA(isA<SyncLedgerWriteException>()));
      expect(a.store.rowsOf(SecurityTables.revocation), isEmpty);
      expect(a.membership.keyring.highest, epochBefore, reason: 'no rotation either');
    });

    test('received revocation: the batch is not committed and comes again', () async {
      final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 150 + i)];
      await pairAll([a, b, c]);
      await syncUntilQuiet([a, b, c]);
      await a.removeMember(c.memberId);
      final ledger = b.ledger as InMemorySyncLedger;
      ledger.failAllRevocationWrites = true;
      final failed = await runSessionPair(a, b);
      final responder = failed.responder;
      expect(responder, isA<SessionPartial>(), reason: '$failed');
      expect((responder as SessionPartial).reasons, contains(PartialReason.storageError));
      expect(b.store.rowsOf(SecurityTables.revocation), isEmpty);

      ledger.failAllRevocationWrites = false;
      expect((await runSessionPair(a, b)).bothComplete, isTrue);
      expect(b.store.rowsOf(SecurityTables.revocation), hasLength(1));
      expect(b.ledger.revocations, hasLength(1));
    });
  });

  test('must_rotate_honours_anchor_flag', () async {
    final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 160 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    final beforeRevocation = await b.snapshotDb();
    await a.removeMember(c.memberId);
    // The revocation reaches B's DB alone, bypassing the session and so the
    // ledger: the same state as a lost ledger. B's top epoch is still the one
    // C holds.
    final revocationPk = a.store.rowsOf(SecurityTables.revocation).single;
    final cell = a.store.storedCell(CellKey(SecurityTables.revocation, revocationPk, CellKey.rowCol))!;
    final change = Change.fromCellRecord(cell.record, groupId: a.membership.groupId!);
    b.store.applyRemote(
      change,
      OriginManifest(origin: change.origin, fromSeq: 0, toSeq: change.originSeq, hashes: const [], sig: Uint8List(64)),
      nowMs: baseWall,
    );
    await b.membership.rebuild(b.store);
    expect(b.membership.revokedAnchorIds, contains(c.memberId));

    await b.restoreDb(beforeRevocation);
    final cPub = c.membership.identity.ed25519Pub;
    expect(b.membership.isRevokedEd(cPub), isFalse, reason: 'neither the DB nor the ledger has the record');
    expect(b.membership.flaggedAnchorsWithoutRecord, {c.memberId});
    expect(b.membership.mustRotate, isTrue, reason: 'the anchor flag alone forces the rotation');
  });

  test('ledger_revocation_with_bad_signature_is_stored_but_not_honoured', () async {
    final [a, b] = [for (var i = 0; i < 2; i++) await newDevice('D$i', seed: 190 + i)];
    await pairAll([a, b]);
    final signed = await RevocationRecord.sign(
      groupId: a.membership.groupId!,
      revokedPub: b.membership.identity.ed25519Pub,
      revoker: a.membership.identity.ed25519,
      cutoffs: const {},
    );
    // Keys and revoker entry are consistent with the group; only the signature is wrong.
    final tampered = RevocationRecord(
      revokedPub: signed.revokedPub,
      revokerPub: signed.revokerPub,
      cutoffs: signed.cutoffs,
      sig: Uint8List.fromList(signed.sig)..[0] ^= 0xff,
    );
    await a.ledger.persistRevocations([
      LedgerRevocation(
        recordBytes: encodeRevocationRecord(tampered),
        revokerEntryBytes: a.membership.identity.entry(addedBy: a.memberId).encode(),
        carrierOrigin: a.store.localOrigin,
        carrierSeq: 1,
      ),
    ]);
    await a.membership.reload(a.store);
    expect(a.ledger.revocations, isNotEmpty, reason: 'the record is stored');
    expect(a.membership.isRevokedEd(b.membership.identity.ed25519Pub), isFalse);
    expect(a.membership.memberById(b.memberId), isNotNull);
  });

  test('forged_ledger_revocation_entry_grants_no_trust', () async {
    final [a, b, forger, bystander] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 170 + i)];
    await pairAll([a, b]);
    final groupId = a.membership.groupId!;
    final forgerIdentity = forger.membership.identity;
    final forged = await RevocationRecord.sign(
      groupId: groupId,
      revokedPub: bystander.membership.identity.ed25519Pub,
      revoker: forgerIdentity.ed25519,
      cutoffs: const {},
    );
    await a.ledger.persistRevocations([
      LedgerRevocation(
        recordBytes: encodeRevocationRecord(forged),
        revokerEntryBytes: forgerIdentity.entry(addedBy: a.memberId).encode(),
        carrierOrigin: a.store.localOrigin,
        carrierSeq: 1,
      ),
    ]);
    await a.membership.reload(a.store);
    expect(a.membership.memberById(forger.memberId), isNull);
    expect(a.membership.anchors.map((m) => m.memberId), isNot(contains(forger.memberId)));

    // The forger claims the group with an epoch of its own and tries to connect.
    final forgedEpoch = EpochId(1, forger.memberId);
    forger.membership.joinGroup(
      groupId,
      epochKeys: {forgedEpoch: secureRandomBytes(32)},
      anchors: a.membership.anchors,
      revokedAnchors: const {},
    );
    forger.store.groupId = groupId;
    final registration = await forger.membership.registerOrigin(forger.store.localOrigin, forger.store);
    await forger.membership.rebuild(forger.store);
    final attempt = await runSessionPair(forger, a);
    expect((attempt.responder as SessionFailed).category, SessionFailure.notAuthorized);
    expect(attempt.responder.stats.keysHandedOver, 0);
    expect(forger.membership.keyring.epochs, {forgedEpoch}, reason: 'no key was handed over');
    expect(a.membership.anchors.map((m) => m.memberId), isNot(contains(forger.memberId)));

    // A's registry stores the forger's origin claim, but a non-member's claim
    // is no claim: its manifests do not verify.
    await a.membership.mergeRegistrations([registration], a.store);
    createRow(forger, 'forged', 'signed by the forger');
    final cell = forger.store.storedCell(cellKey('forged', 'title'))!;
    final change = Change.fromCellRecord(cell.record, groupId: groupId);
    final manifest = (await ManifestSigner(groupId: groupId, origin: change.origin, signer: forgerIdentity.ed25519)
            .sign(fromSeq: change.originSeq - 1, toSeq: change.originSeq, changes: [change]))
        .single;
    expect(await a.membership.verifier.verify(manifest), isA<ManifestRejected>());
  });

  test('forged_ledger_revocation_is_not_self_extended', () async {
    final [a, b, c, forger] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 180 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    createRow(b, 'held', 'a cell A holds above the forged cutoff');
    expect((await runSessionPair(b, a)).bothComplete, isTrue);
    await persistLedgerRevocation(a, revoker: forger, revoked: b);
    await a.membership.reload(a.store);
    final bPub = b.membership.identity.ed25519Pub;
    final topEpoch = a.membership.keyring.highest;
    final grantCount = a.store.rowsOf(SecurityTables.epochGrant).length;
    expect(a.membership.isExcluded(bPub), isTrue, reason: 'the ledger record still sets a local cutoff');

    await a.maintainMembership();

    expect(a.store.rowsOf(SecurityTables.revocation), isEmpty, reason: 'no revocation signed from ledger data');
    expect(a.membership.keyring.highest, topEpoch, reason: 'no rotation from ledger data');
    expect(a.store.rowsOf(SecurityTables.epochGrant), hasLength(grantCount), reason: 'no new epoch grant');
    expect((await runSessionPair(a, c)).bothComplete, isTrue);
    expect((await runSessionPair(b, c)).bothComplete, isTrue);
    expect(c.store.rowsOf(SecurityTables.revocation), isEmpty);
    expect(c.membership.isExcluded(bPub), isFalse, reason: 'peers are unaffected');
  });

  // Card B.1: a device that only HOLDS an above-cutoff envelope of a revoked
  // origin (never stored) still extends the cutoff, so the record it signs
  // covers the held seq and the held envelope can apply once peers accept it.
  test('self_extension_counts_held_envelopes', () async {
    final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 200 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    createRow(b, 'held', 'cell A stores below the cutoff');
    expect((await runSessionPair(b, a)).bothComplete, isTrue);
    final bOrigin = b.store.localOrigin.hex;
    final storedMax = a.store.maxCellSeq(bOrigin);
    // A real held envelope: B writes more and A fails to apply that one cell
    // once (scenario 1.9 shape), so the envelope stays held, never stored.
    createRow(b, 'later', 'the envelope A only holds');
    a.store.applyFault = (change) => change.pk == 'later';
    await runSessionPair(b, a);
    a.store.applyFault = null;
    final heldSeqs = [
      for (final h in a.store.heldEnvelopes.where((h) => h.origin == bOrigin)) h.seq,
    ]..sort();
    expect(heldSeqs, isNotEmpty, reason: 'A holds B envelopes');
    expect(heldSeqs.last, greaterThan(storedMax));
    expect(a.store.maxKnownSeq(bOrigin), greaterThan(storedMax), reason: 'the held seq counts');
    final topEpoch = a.membership.keyring.highest;
    await persistLedgerRevocation(a, revoker: c, revoked: b);
    await a.membership.reload(a.store);
    // selfExtension must report the HELD seq, not just the stored one.
    final extension = a.membership.directoryRevocations!.selfExtension(
      a.membership.registry!,
      (o) => a.store.maxKnownSeq(o.hex),
    );
    final bOriginId = OriginId.fromHex(bOrigin);
    final oldSelector = a.membership.directoryRevocations!.selfExtension(
      a.membership.registry!,
      (o) => a.store.maxCellSeq(o.hex),
    );
    final oldForB = [
      for (final e in oldSelector.entries)
        if (e.value.containsKey(bOriginId)) e.value[bOriginId],
    ];
    expect(oldForB.first ?? 0, lessThan(heldSeqs.last),
        reason: 'fail-before: the old stored-only selector misses the held seq');
    final extForB = [
      for (final e in extension.entries)
        if (e.value.containsKey(bOriginId)) e.value[bOriginId],
    ];
    expect(a.store.maxKnownSeq(bOrigin), greaterThanOrEqualTo(storedMax));
    expect(extForB, isNotEmpty, reason: 'held envelopes extend the cutoff like stored cells');
    expect(extForB.first, greaterThanOrEqualTo(heldSeqs.last),
        reason: 'the signed cutoff covers the highest HELD seq, which maxCellSeq alone would miss');
    await a.maintainMembership();
    expect(a.store.rowsOf(SecurityTables.revocation), isNotEmpty, reason: 'A signs its own record');
    expect(a.membership.keyring.highest, isNot(topEpoch), reason: 'the exclusion rotates the epoch');
  });

  // Card B.2 (publish what you enforce): A's own revocation of B sits on an
  // origin A sealed before any peer fetched it, so peers can never learn it.
  // A re-signs it on its live origin and C ends up excluding B.
  test('own_revocation_stranded_on_sealed_origin_is_published', () async {
    final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 210 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    await a.removeMember(b.memberId);
    final bPub = b.membership.identity.ed25519Pub;
    final stranded = a.store.localOrigin.hex;
    await a.switchOrigin(OriginSwitchReason.restore);
    expect(a.store.sealedOrigins, contains(stranded));
    expect(c.membership.isExcluded(bPub), isFalse, reason: 'no peer has the record');

    await a.maintainMembership();
    expect((await runSessionPair(a, c)).bothComplete, isTrue);
    await c.maintainMembership();

    expect(c.membership.isExcluded(bPub), isTrue, reason: 'the re-issued record reached C');
    expect(a.store.rowsOf(SecurityTables.revocation), hasLength(greaterThan(1)), reason: 'a live-origin copy exists');
  });

  test('stranded_revocation_republish_is_idempotent', () async {
    final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 220 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    await a.removeMember(b.memberId);
    await a.switchOrigin(OriginSwitchReason.restore);
    await a.maintainMembership();
    final rows = a.store.rowsOf(SecurityTables.revocation).length;
    final epoch = a.membership.keyring.highest;
    await a.maintainMembership();
    expect(a.store.rowsOf(SecurityTables.revocation), hasLength(rows), reason: 'one record, not one per call');
    expect(a.membership.keyring.highest, epoch);
  });

  // C1: a ledger-only record (not in the DB directory) carried on a sealed
  // origin of this device is never re-issued, even though the carrier looks
  // own-authored.
  test('ledger_only_record_on_sealed_origin_is_not_republished', () async {
    final [a, b, c, forger] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 230 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    await persistLedgerRevocation(a, revoker: forger, revoked: b);
    await a.switchOrigin(OriginSwitchReason.restore);
    await a.membership.reload(a.store);
    final topEpoch = a.membership.keyring.highest;

    await a.maintainMembership();

    expect(a.store.rowsOf(SecurityTables.revocation), isEmpty, reason: 'nothing signed from ledger data');
    expect(a.membership.keyring.highest, topEpoch);
  });

  // C4: two devices both stranded their revocation of B; both re-issue and the
  // group converges on B excluded with a bounded number of rotations.
  test('concurrent_stranded_revocations_converge', () async {
    final [a, b, c, d] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 240 + i)];
    await pairAll([a, b, c, d]);
    await syncUntilQuiet([a, b, c, d]);
    await a.removeMember(b.memberId);
    await c.removeMember(b.memberId);
    await a.switchOrigin(OriginSwitchReason.restore);
    await c.switchOrigin(OriginSwitchReason.restore);
    await a.maintainMembership();
    await c.maintainMembership();
    await syncUntilQuiet([a, c, d]);
    await d.maintainMembership();
    await syncUntilQuiet([a, c, d]);

    final bPub = b.membership.identity.ed25519Pub;
    for (final device in [a, c, d]) {
      expect(device.membership.isExcluded(bPub), isTrue);
    }
    final epochs = {
      for (final device in [a, c, d]) device.membership.keyring.highest
    };
    expect(epochs, hasLength(1), reason: 'one converged epoch');
    expect((await runSessionPair(b, d)).responder, isA<SessionFailed>(), reason: 'D rejects revoked B');
  });

  // ACF-49: A revokes X on A's own origin and C holds the record. A second
  // member then registers the same origin (a copied data folder), so the origin
  // is conflicted: peers reject its cells as unrooted and the record can no
  // longer be fetched from it. C, a converged member, re-signs the record on
  // its own origin.
  test('third_party_revocation_with_conflicted_carrier_is_reissued_by_a_converged_member', () async {
    final [a, b, c, x] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 270 + i)];
    await pairAll([a, b, c, x]);
    await syncUntilQuiet([a, b, c, x]);
    await a.removeMember(x.memberId);
    await syncUntilQuiet([a, b, c]);
    final xPub = x.membership.identity.ed25519Pub;
    expect(c.membership.isExcluded(xPub), isTrue);
    expect(await c.maintainMembership(), isFalse, reason: 'the carrier origin has one owner: nothing to publish');
    final before = c.store.rowsOf(SecurityTables.revocation).length;

    final clash = await signOriginRegistration(
      groupId: c.membership.groupId!,
      origin: a.store.localOrigin,
      member: b.membership.identity.ed25519,
      createdHlc: c.store.hlc + 1,
    );
    c.store.addRegistration(clash);
    await c.membership.rebuild(c.store);
    expect(c.membership.registry!.ownerOf(a.store.localOrigin), isA<OriginConflicted>());

    expect(await c.maintainMembership(), isTrue, reason: 'the record is stranded on a conflicted origin');
    expect(c.store.rowsOf(SecurityTables.revocation).length, greaterThan(before));
    expect(c.membership.isExcluded(xPub), isTrue);
    expect(await c.maintainMembership(), isFalse, reason: 'the re-issue is idempotent');
  });

  // C3: a sent mark above the carrier seq does not make a record servable when
  // the carrying cell has no manifest (peers were never handed it).
  test('sent_mark_without_manifest_does_not_count_as_served', () async {
    final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 250 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    await a.removeMember(b.memberId);
    final origin = a.store.localOrigin;
    await a.ledger.persistSentMark(origin, 1000, a.store.hlc);
    await a.switchOrigin(OriginSwitchReason.restore, sentMark: 1000);
    final bPub = b.membership.identity.ed25519Pub;
    expect(c.membership.isExcluded(bPub), isFalse);

    await a.maintainMembership();
    expect((await runSessionPair(a, c)).bothComplete, isTrue);
    await c.maintainMembership();

    expect(c.membership.isExcluded(bPub), isTrue, reason: 'unmanifested carrier is re-issued despite the sent mark');
  });

  // C2: a key-lost device re-issues its stranded own revocation only after it
  // re-pairs, and then under its NEW key.
  test('key_lost_device_reissues_stranded_revocation_only_after_repair', () async {
    final [b, c, d1, x] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 260 + i)];
    await pairAll([b, c, d1, x]);
    await syncUntilQuiet([b, c, d1, x]);
    await d1.removeMember(x.memberId);
    final oldDb = await d1.snapshotDb();
    final oldD1 = d1.memberId;
    final xPub = x.membership.identity.ed25519Pub;

    await d1.loseKeyFile(oldDb: oldDb, loseLedger: true);
    final before = d1.store.rowsOf(SecurityTables.revocation).length;
    await d1.maintainMembership();
    expect(d1.store.rowsOf(SecurityTables.revocation), hasLength(before), reason: 'nothing before re-pair');

    await b.removeMember(oldD1);
    await SyncDevice.pair(inviter: b, joiner: d1);
    await d1.maintainMembership();
    await syncUntilQuiet([b, c, d1]);
    await c.maintainMembership();

    expect(d1.memberId, isNot(oldD1));
    expect(c.membership.isExcluded(xPub), isTrue, reason: 'the stranded revocation reached the group');
    final newKey = d1.membership.identity.ed25519Pub;
    final revokers = [
      for (final pk in d1.store.rowsOf(SecurityTables.revocation))
        decodeRevocationRecord(
            d1.store.read(CellKey(SecurityTables.revocation, pk, CellKey.rowCol))!.value as Uint8List),
    ].where((r) => _sameBytes(r.revokedPub, xPub)).map((r) => r.revokerPub);
    expect(revokers.any((key) => _sameBytes(key, newKey)), isTrue, reason: 're-issued under the NEW key');
  });

  test('ledger_revocation_by_db_member_still_self_extends', () async {
    final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 190 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    createRow(b, 'held', 'a cell A holds above the cutoff');
    expect((await runSessionPair(b, a)).bothComplete, isTrue);
    final topEpoch = a.membership.keyring.highest;
    await persistLedgerRevocation(a, revoker: c, revoked: b);
    await a.membership.reload(a.store);

    await a.maintainMembership();

    expect(a.store.rowsOf(SecurityTables.revocation), isNotEmpty, reason: 'A signs its own revocation');
    expect(a.membership.keyring.highest, isNot(topEpoch), reason: 'the exclusion rotates the epoch');
  });

  test('forged_ledger_revocation_of_self_keeps_keys', () async {
    final [a, b, forger] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 200 + i)];
    await pairAll([a, b]);
    await syncUntilQuiet([a, b]);
    final epochs = {...a.membership.keyring.epochs};
    await persistLedgerRevocation(a, revoker: forger, revoked: a, carrier: forger);
    await a.membership.reload(a.store);

    expect(a.membership.removed, isFalse, reason: 'a ledger-only record never removes this device');
    expect(a.membership.keyring.epochs, epochs, reason: 'group keys stay intact');
  });

  test('ledger_revocation_of_self_by_db_member_removes', () async {
    final [a, b] = [for (var i = 0; i < 2; i++) await newDevice('D$i', seed: 210 + i)];
    await pairAll([a, b]);
    await syncUntilQuiet([a, b]);
    await persistLedgerRevocation(a, revoker: b, revoked: a, carrier: b);
    await a.membership.reload(a.store);

    expect(a.membership.removed, isTrue, reason: 'a genuine restore still removes this device');
  });

  test('receive_after_storage_error_commits_nothing', () async {
    final [
      a,
      b,
      c
    ] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 180 + i, config: testConfig(maxBatchChanges: 2))];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    await a.removeMember(c.memberId);
    final laterRows = {for (var i = 0; i < 6; i++) 'later$i'};
    for (final pk in laterRows) {
      createRow(a, pk, 'written after the revocation');
    }
    final ledger = b.ledger as InMemorySyncLedger;
    ledger.failAllRevocationWrites = true;
    final failed = await runSessionPair(a, b);
    expect((failed.responder as SessionPartial).reasons, contains(PartialReason.storageError));
    expect(b.store.rowsOf(SecurityTables.revocation), isEmpty);
    expect(aliveRows(b.store, 'task').intersection(laterRows), isEmpty, reason: 'later batches commit nothing');

    ledger.failAllRevocationWrites = false;
    expect((await runSessionPair(a, b)).bothComplete, isTrue);
    expect(b.store.rowsOf(SecurityTables.revocation), hasLength(1));
    expect(aliveRows(b.store, 'task'), containsAll(laterRows));
  });

  test('flagged_anchor_without_record_holds_unverified', () async {
    final [a, b, relay, r] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 190 + i)];
    await pairAll([a, b, relay, r]);
    await syncUntilQuiet([a, b, relay, r]);
    final beforeRevocation = await b.snapshotDb();
    createRow(r, 'before', 'written before the revocation');
    expect((await runSessionPair(r, a)).bothComplete, isTrue);
    await a.removeMember(r.memberId);
    createRow(r, 'after', 'written after the revocation');
    expect((await runSessionPair(r, relay)).bothComplete, isTrue, reason: 'the relay is not informed yet');

    // B's DB alone learns the revocation (flagging the anchor), then B loses
    // it with a DB restore while the ledger never had it: a lost ledger.
    final revocationPk = a.store.rowsOf(SecurityTables.revocation).single;
    final revocationCell = a.store.storedCell(CellKey(SecurityTables.revocation, revocationPk, CellKey.rowCol))!;
    final revocation = Change.fromCellRecord(revocationCell.record, groupId: a.membership.groupId!);
    b.store.applyRemote(
      revocation,
      OriginManifest(
          origin: revocation.origin, fromSeq: 0, toSeq: revocation.originSeq, hashes: const [], sig: Uint8List(64)),
      nowMs: baseWall,
    );
    await b.membership.rebuild(b.store);
    await b.restoreDb(beforeRevocation);
    expect(b.membership.flaggedAnchorsWithoutRecord, {r.memberId});

    final relayed = await runSessionPair(relay, b);
    expect(relayed.responder, isNot(isA<SessionFailed>()), reason: '$relayed');
    final rOrigin = r.store.localOrigin.hex;
    final heldFromR = [
      for (final h in b.store.heldEnvelopes)
        if (h.origin == rOrigin) h
    ];
    expect(aliveRows(b.store, 'task'), isNot(anyOf(contains('before'), contains('after'))), reason: 'not applied');
    expect(heldFromR, isNotEmpty, reason: 'held, not rejected');
    expect(heldFromR.map((h) => h.reason), everyElement(HeldReason.unverified));

    // A peer resends the record: the held cells are re-checked against it.
    await runSessionPair(a, b);
    expect(b.membership.flaggedAnchorsWithoutRecord, isEmpty);
    expect(aliveRows(b.store, 'task'), contains('before'), reason: 'pre-cutoff cells apply');
    expect(aliveRows(b.store, 'task'), isNot(contains('after')), reason: 'post-cutoff cells are rejected');
  });
}

/// Puts a genuine, [revoker]-signed record revoking [revoked] (no cutoffs) in
/// the ledger of [device], with the revoker's own member entry next to it,
/// carried on [carrier]'s origin (default [device]).
Future<void> persistLedgerRevocation(SyncDevice device,
    {required SyncDevice revoker, required SyncDevice revoked, SyncDevice? carrier}) async {
  final revokerIdentity = revoker.membership.identity;
  final record = await RevocationRecord.sign(
    groupId: device.membership.groupId!,
    revokedPub: revoked.membership.identity.ed25519Pub,
    revoker: revokerIdentity.ed25519,
    cutoffs: const {},
  );
  await device.ledger.persistRevocations([
    LedgerRevocation(
      recordBytes: encodeRevocationRecord(record),
      revokerEntryBytes: revokerIdentity.entry(addedBy: device.memberId).encode(),
      carrierOrigin: (carrier ?? device).store.localOrigin,
      carrierSeq: 1,
    ),
  ]);
}

bool _sameBytes(List<int> a, List<int> b) =>
    a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);
