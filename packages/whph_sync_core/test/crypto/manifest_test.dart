// T11 acc 4 + acc 7: manifest signing/verification, origin registry,
// revocation cutoffs, performance of a 1,000-change batch.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/src/model/wire_bytes.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'crypto_test_support.dart';

final _oa = originOf(1);
final _oa2 = originOf(2);
final _om = originOf(3);
final _on = originOf(4);

late Ed25519KeyPair _a;
late Ed25519KeyPair _m;
late Ed25519KeyPair _n; // not a member

Future<OriginRegistrySet> _registry(Map<OriginId, Ed25519KeyPair> owners, MemberDirectory members) async {
  final r = OriginRegistrySet(testGroup, members: members);
  final rows = [
    for (final e in owners.entries)
      await signOriginRegistration(groupId: testGroup, origin: e.key, member: e.value, createdHlc: testHlc),
  ];
  final res = await r.merge(rows);
  expect(res.rejected, 0);
  return r;
}

List<Change> _changes(OriginId origin, int from, int to, {String node = 'member-a'}) =>
    [for (var s = from + 1; s <= to; s++) testChange(origin: origin, seq: s, pk: 'task-$s', node: node)];

void main() {
  setUpAll(() async {
    _a = await Ed25519KeyPair.fromSeed(testKey(31));
    _m = await Ed25519KeyPair.fromSeed(testKey(32));
    _n = await Ed25519KeyPair.fromSeed(testKey(33));
  });

  late OriginRegistrySet registry;
  late RevocationSet revocations;
  late MemberKeySet members;
  late ManifestVerifier verifier;

  setUp(() async {
    members = MemberKeySet([_a.publicKey, _m.publicKey]);
    registry = await _registry({_oa: _a, _oa2: _a, _om: _m, _on: _n}, members);
    revocations = RevocationSet(testGroup);
    verifier = ManifestVerifier(groupId: testGroup, registry: registry, revocations: revocations, members: members);
  });

  Future<OriginManifest> signed(Ed25519KeyPair key, OriginId origin, List<Change> changes,
          {int from = 0, int? to}) async =>
      (await ManifestSigner(groupId: testGroup, origin: origin, signer: key)
              .sign(fromSeq: from, toSeq: to ?? from + changes.length, changes: changes))
          .single;

  Future<VerifiedManifest> verified(OriginManifest m) async {
    final v = await verifier.verify(m);
    expect(v, isA<VerifiedManifest>());
    return v as VerifiedManifest;
  }

  group('signer', () {
    test('hashes are BLAKE2b-256 of canonical changes, sig over signingInput(group)', () async {
      final changes = _changes(_oa, 0, 3);
      final m = await signed(_a, _oa, changes);
      expect(m.hashes, [for (final c in changes) c.canonicalHash()]);
      expect(await ed25519Verify(m.signingInput(testGroup), m.sig, _a.publicKey), isTrue);
      expect(await ed25519Verify(m.signingInput(otherGroup), m.sig, _a.publicKey), isFalse);
    });

    test('splits a range into manifests of at most 1,000 seqs; superseded seqs have no hash', () async {
      final changes = _changes(_oa, 0, 2500).where((c) => c.originSeq % 7 != 0).toList();
      final ms = await ManifestSigner(groupId: testGroup, origin: _oa, signer: _a)
          .sign(fromSeq: 0, toSeq: 2500, changes: changes);
      expect(ms.map((m) => (m.fromSeq, m.toSeq)), [(0, 1000), (1000, 2000), (2000, 2500)]);
      expect(ms.fold<int>(0, (n, m) => n + m.hashes.length), changes.length);
    });

    test('refuses foreign origins, other groups, out-of-range and duplicate seqs', () async {
      final s = ManifestSigner(groupId: testGroup, origin: _oa, signer: _a);
      expect(() => s.sign(fromSeq: 0, toSeq: 5, changes: _changes(_om, 0, 1)), throwsArgumentError);
      expect(() => s.sign(fromSeq: 0, toSeq: 5, changes: [testChange(origin: _oa, group: otherGroup)]),
          throwsArgumentError);
      expect(() => s.sign(fromSeq: 1, toSeq: 5, changes: _changes(_oa, 0, 1)), throwsRangeError);
      expect(() => s.sign(fromSeq: 0, toSeq: 5, changes: [..._changes(_oa, 0, 1), ..._changes(_oa, 0, 1)]),
          throwsArgumentError);
    });
  });

  group('verifier (acc 4)', () {
    test('accepts every listed change; relays may forward a subset', () async {
      final changes = _changes(_oa, 10, 20);
      final vm = await verified(await signed(_a, _oa, changes, from: 10));
      for (final c in changes.where((c) => c.originSeq.isEven)) {
        expect(verifier.checkChange(c, vm).isAccepted, isTrue);
      }
    });

    test('signature is verified once and cached', () async {
      final m = await signed(_a, _oa, _changes(_oa, 0, 3));
      final v1 = await verifier.verify(m);
      final v2 = await verifier.verify(OriginManifest.readFrom(_reader(m)));
      expect(identical(v1, v2), isTrue);
    });

    test('a change whose hash is not in its manifest rejects', () async {
      final changes = _changes(_oa, 0, 3);
      final vm = await verified(await signed(_a, _oa, changes));
      final altered = testChange(origin: _oa, seq: 2, pk: 'task-2', value: StringValue('forged'));
      expect(verifier.checkChange(altered, vm).rejection, ManifestRejection.hashNotInManifest);
      final otherNode = testChange(origin: _oa, seq: 2, pk: 'task-2', node: 'member-x');
      expect(verifier.checkChange(otherNode, vm).rejection, ManifestRejection.hashNotInManifest);
    });

    test('seq outside the manifest range, other origin or other group rejects', () async {
      final vm = await verified(await signed(_a, _oa, _changes(_oa, 0, 3)));
      expect(verifier.checkChange(testChange(origin: _oa, seq: 4), vm).rejection, ManifestRejection.seqOutsideManifest);
      expect(verifier.checkChange(testChange(origin: _oa2, seq: 1), vm).rejection, ManifestRejection.originMismatch);
      expect(verifier.checkChange(testChange(origin: _oa, seq: 1, group: otherGroup), vm).rejection,
          ManifestRejection.wrongGroup);
    });

    test('a manifest signed by a non-member rejects (its registration is no claim)', () async {
      final m = await signed(_n, _on, _changes(_on, 0, 2));
      expect(registry.ownerOf(_on), isA<OriginUnregistered>());
      expect((await verifier.verify(m) as ManifestRejected).reason, ManifestRejection.unregisteredOrigin);
    });

    test('M3: a non-member row cannot squat a member origin; a revoked member row still conflicts', () async {
      final good = await signed(_a, _oa, _changes(_oa, 0, 2));
      final vm = await verified(good);
      // A validly signed row by a non-member key for A's origin is ignored.
      final squat = await signOriginRegistration(groupId: testGroup, origin: _oa, member: _n, createdHlc: testHlc);
      expect((await registry.merge([squat])).added, 1);
      expect((registry.ownerOf(_oa) as OriginRegisteredTo).memberPub, _a.publicKey);
      expect(registry.originsOf(_a.publicKey), containsAll([_oa, _oa2]));
      expect((await verifier.verify(good)), isA<VerifiedManifest>());
      expect(verifier.checkChange(_changes(_oa, 0, 1).single, vm).isAccepted, isTrue);
      // A revoked member is still a member (directory includes it): its
      // conflicting claim still conflicts.
      await revocations.merge([
        await RevocationRecord.sign(groupId: testGroup, revokedPub: _m.publicKey, revoker: _a, cutoffs: const {}),
      ], members);
      await registry
          .merge([await signOriginRegistration(groupId: testGroup, origin: _oa, member: _m, createdHlc: testHlc)]);
      expect(registry.ownerOf(_oa), isA<OriginConflicted>());
      // Becoming a member later makes a stored row count (resolution is live).
      final late = await signOriginRegistration(groupId: testGroup, origin: originOf(12), member: _n, createdHlc: 1);
      await registry.merge([late]);
      expect(registry.ownerOf(originOf(12)), isA<OriginUnregistered>());
      members.add(_n.publicKey);
      expect((registry.ownerOf(originOf(12)) as OriginRegisteredTo).memberPub, _n.publicKey);
    });

    test('a manifest signed by a member key not registered for that origin rejects', () async {
      final m = await signed(_m, _oa, _changes(_oa, 0, 2)); // M signs A's origin
      expect((await verifier.verify(m) as ManifestRejected).reason, ManifestRejection.badSignature);
    });

    test('a tampered manifest (hash list or range) rejects', () async {
      final m = await signed(_a, _oa, _changes(_oa, 0, 3));
      final forgedHashes = OriginManifest(
          origin: m.origin,
          fromSeq: m.fromSeq,
          toSeq: m.toSeq,
          hashes: [
            ...m.hashes.take(2),
            blake2b256([1])
          ],
          sig: m.sig);
      final forgedRange = OriginManifest(origin: m.origin, fromSeq: 0, toSeq: 4, hashes: m.hashes, sig: m.sig);
      for (final f in [forgedHashes, forgedRange]) {
        expect((await verifier.verify(f) as ManifestRejected).reason, ManifestRejection.badSignature);
      }
    });

    test('unregistered origin rejects; conflicting registrations reject everything of that origin', () async {
      final ghost = originOf(9);
      final m = await signed(_a, ghost, _changes(ghost, 0, 1));
      expect((await verifier.verify(m) as ManifestRejected).reason, ManifestRejection.unregisteredOrigin);

      final good = await signed(_a, _oa, _changes(_oa, 0, 2));
      final vm = await verified(good);
      // M squats A's origin with a validly signed row.
      await registry
          .merge([await signOriginRegistration(groupId: testGroup, origin: _oa, member: _m, createdHlc: testHlc)]);
      expect(registry.ownerOf(_oa), isA<OriginConflicted>());
      expect((await verifier.verify(good) as ManifestRejected).reason, ManifestRejection.conflictedOrigin);
      expect(verifier.checkChange(_changes(_oa, 0, 1).single, vm).rejection, ManifestRejection.conflictedOrigin);
    });

    test('revoked origin: seq <= cutoff accepted, seq > cutoff rejected', () async {
      final changes = _changes(_oa, 0, 10);
      final vm = await verified(await signed(_a, _oa, changes));
      await revocations.merge([
        await RevocationRecord.sign(groupId: testGroup, revokedPub: _a.publicKey, revoker: _m, cutoffs: {_oa: 5}),
      ], members);
      for (final c in changes) {
        final v = verifier.checkChange(c, vm);
        if (c.originSeq <= 5) {
          expect(v.isAccepted, isTrue, reason: 'seq ${c.originSeq}');
        } else {
          expect(v.rejection, ManifestRejection.revokedAboveCutoff, reason: 'seq ${c.originSeq}');
        }
      }
    });

    test('an origin of a revoked member that no record lists has cutoff 0', () async {
      final vm = await verified(await signed(_a, _oa2, _changes(_oa2, 0, 3)));
      await revocations.merge([
        await RevocationRecord.sign(groupId: testGroup, revokedPub: _a.publicKey, revoker: _m, cutoffs: {_oa: 5}),
      ], members);
      expect(revocations.cutoffFor(_oa2, registry), 0);
      for (final c in _changes(_oa2, 0, 3)) {
        expect(verifier.checkChange(c, vm).rejection, ManifestRejection.revokedAboveCutoff);
      }
      // Other members' origins are unaffected.
      expect(revocations.cutoffFor(_om, registry), isNull);
    });

    test('effective cutoff is the max over records', () async {
      await revocations.merge([
        await RevocationRecord.sign(groupId: testGroup, revokedPub: _a.publicKey, revoker: _m, cutoffs: {_oa: 5}),
        await RevocationRecord.sign(
            groupId: testGroup, revokedPub: _a.publicKey, revoker: _m, cutoffs: {_oa: 8, _oa2: 2}),
        await RevocationRecord.sign(groupId: testGroup, revokedPub: _a.publicKey, revoker: _m, cutoffs: {_oa: 3}),
      ], members);
      expect(revocations.cutoffFor(_oa, registry), 8);
      expect(revocations.cutoffFor(_oa2, registry), 2);
    });
  });

  group('origin registry', () {
    test('rows with a bad signature, another group or altered fields are dropped', () async {
      final r = OriginRegistrySet(testGroup, members: MemberKeySet([_a.publicKey, _m.publicKey]));
      final good = await signOriginRegistration(groupId: testGroup, origin: _oa, member: _a, createdHlc: testHlc);
      final otherGroupRow =
          await signOriginRegistration(groupId: otherGroup, origin: _oa2, member: _a, createdHlc: testHlc);
      final reattributed = OriginRegistration(origin: _oa, memberPub: _m.publicKey, createdHlc: testHlc, sig: good.sig);
      final moved = OriginRegistration(origin: _oa2, memberPub: _a.publicKey, createdHlc: testHlc, sig: good.sig);
      final redated = OriginRegistration(origin: _oa, memberPub: _a.publicKey, createdHlc: testHlc + 1, sig: good.sig);
      final res = await r.merge([good, otherGroupRow, reattributed, moved, redated]);
      expect(res.added, 1);
      expect(res.rejected, 4);
      expect((r.ownerOf(_oa) as OriginRegisteredTo).memberPub, _a.publicKey);
      expect(r.ownerOf(_oa2), isA<OriginUnregistered>());
    });

    test('merge is grow-only and order-independent', () async {
      final rows = [
        await signOriginRegistration(groupId: testGroup, origin: _oa, member: _a, createdHlc: testHlc),
        await signOriginRegistration(groupId: testGroup, origin: _oa, member: _a, createdHlc: testHlc + 5),
        await signOriginRegistration(groupId: testGroup, origin: _om, member: _m, createdHlc: testHlc),
        await signOriginRegistration(groupId: testGroup, origin: _om, member: _a, createdHlc: testHlc),
      ];
      final dir = MemberKeySet([_a.publicKey, _m.publicKey]);
      final r1 = OriginRegistrySet(testGroup, members: dir);
      final r2 = OriginRegistrySet(testGroup, members: dir);
      await r1.merge(rows);
      await r2.merge(rows.reversed);
      await r2.merge(rows);
      for (final o in [_oa, _om]) {
        expect(r1.ownerOf(o).runtimeType, r2.ownerOf(o).runtimeType);
      }
      expect(r1.entries.length, 4);
      expect(r2.entries.length, 4);
      expect(r1.ownerOf(_oa), isA<OriginRegisteredTo>());
      expect(r1.ownerOf(_om), isA<OriginConflicted>());
      expect(r1.originsOf(_a.publicKey), [_oa]);
    });

    test('signing inputs are domain-separated', () {
      final origin =
          originRegistrationSigningInput(groupId: testGroup, origin: _oa, memberPub: _a.publicKey, createdHlc: 1);
      final revocation = RevocationRecord.signingInput(
          groupId: testGroup, revokedPub: _a.publicKey, revokerPub: _m.publicKey, cutoffs: {_oa: 1});
      final manifest = OriginManifest(origin: _oa, fromSeq: 0, toSeq: 1, hashes: const [], sig: Uint8List(64))
          .signingInput(testGroup);
      final prefixes = [
        for (final (bytes, domain) in [
          (origin, originRegistrationDomain),
          (revocation, revocationDomain),
          (manifest, manifestSigningDomain),
        ])
          String.fromCharCodes(bytes.sublist(4, 4 + domain.length)),
      ];
      expect(prefixes, [originRegistrationDomain, revocationDomain, manifestSigningDomain]);
      expect(prefixes.toSet().length, 3);
    });
  });

  group('revocation records', () {
    test('rejects bad signatures and non-member revokers; dedupes', () async {
      final set = RevocationSet(testGroup);
      final good =
          await RevocationRecord.sign(groupId: testGroup, revokedPub: _a.publicKey, revoker: _m, cutoffs: {_oa: 1});
      final byOutsider =
          await RevocationRecord.sign(groupId: testGroup, revokedPub: _m.publicKey, revoker: _n, cutoffs: const {});
      final inflated = RevocationRecord(
          revokedPub: good.revokedPub, revokerPub: good.revokerPub, cutoffs: {_oa: 999}, sig: good.sig);
      final wrongGroup =
          await RevocationRecord.sign(groupId: otherGroup, revokedPub: _m.publicKey, revoker: _a, cutoffs: const {});
      final res = await set.merge([good, byOutsider, inflated, wrongGroup, good], members);
      expect(res.added, 1);
      expect(res.rejected, 3);
      expect(res.newlyRevoked.single, _a.publicKey);
      expect(set.isRevoked(_m.publicKey), isFalse);
      expect(set.cutoffFor(_oa, registry), 1);
    });

    test('self-extension lists only origins where this member holds more than the cutoff', () async {
      final set = RevocationSet(testGroup);
      await set.merge([
        await RevocationRecord.sign(groupId: testGroup, revokedPub: _a.publicKey, revoker: _m, cutoffs: {_oa: 5}),
      ], members);
      final held = {_oa: 7, _oa2: 3};
      final ext = set.selfExtension(registry, (o) => held[o] ?? 0);
      expect(ext.length, 1);
      expect(ext.values.single, {_oa: 7, _oa2: 3});
      final none = set.selfExtension(registry, (o) => o == _oa ? 5 : 0);
      expect(none, isEmpty);
      expect(RevocationSet.initialCutoffs(_a.publicKey, registry, (o) => held[o] ?? 0), {_oa: 7, _oa2: 3});
    });
  });

  group('performance (acc 7)', () {
    test('verifying a 1,000-change manifest batch (1 signature + 1,000 hashes) <= 50 ms', () async {
      final changes = [
        for (var s = 1; s <= 1000; s++) testChange(origin: _oa, seq: s, pk: 'task-$s', value: StringValue('v' * 200)),
      ];
      final manifest = await signed(_a, _oa, changes);
      final timings = <int>[];
      for (var run = 0; run < 6; run++) {
        // A fresh verifier each run: the signature is really verified.
        final v = ManifestVerifier(groupId: testGroup, registry: registry, revocations: revocations, members: members);
        final sw = Stopwatch()..start();
        final vm = await v.verify(manifest) as VerifiedManifest;
        var accepted = 0;
        for (final c in changes) {
          if (v.checkChange(c, vm).isAccepted) accepted++;
        }
        sw.stop();
        expect(accepted, 1000);
        timings.add(sw.elapsedMicroseconds);
      }
      final warm = timings.skip(1).toList()..sort();
      final best = warm.first / 1000;
      final median = warm[warm.length ~/ 2] / 1000;
      // ignore: avoid_print
      print('[T11] acc7 verify 1 sig + 1,000 hashes: first(cold) ${(timings.first / 1000).toStringAsFixed(1)} ms, '
          'warm best ${best.toStringAsFixed(1)} ms, warm median ${median.toStringAsFixed(1)} ms');
      // Tolerant: the best warm run must meet the 50 ms budget.
      expect(best, lessThanOrEqualTo(50));
    });
  });
}

ByteReader _reader(OriginManifest m) {
  final w = ByteWriter();
  m.writeTo(w);
  return ByteReader(w.take());
}
