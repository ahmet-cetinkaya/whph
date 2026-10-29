// T18 acceptance (second part): manifests, security rows, duplicate identity,
// held-envelope refetch and the pipelined read/apply of the Drift change store.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'drift_sync_test_support.dart';

const String _originAHex = '0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a';
const String _groupHex = '0102030405060708090a0b0c0d0e0f10';
const int _noteCount = 12;
const int _pageSize = 7;
const int _farHlc = (1 << 46) << 16;

Uint8List _bytes(int length, int fill) =>
    Uint8List.fromList(List.filled(length, fill));

MemberEntry _member(String id) => MemberEntry(
      memberId: id,
      x25519Pub: _bytes(32, 1),
      ed25519Pub: _bytes(32, 2),
      name: 'Phone $id',
      addedBy: 'founder',
    );

RevocationRecord _revocation() => RevocationRecord(
      revokedPub: _bytes(32, 3),
      revokerPub: _bytes(32, 4),
      cutoffs: {
        OriginId(_bytes(16, 5)): 9,
        OriginId(_bytes(16, 6)): 0,
      },
      sig: _bytes(64, 7),
    );

EpochGrant _grant() => EpochGrant(EpochId(2, 'founder'), _bytes(32, 8));

CellRecord _securityCell(CellKey key, Uint8List value, int clock) => CellRecord(
    key: key,
    value: value,
    clock: clock,
    node: 'node-x',
    origin: 'origin-x',
    originSeq: clock);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestDevice a;
  late SyncTestDevice b;

  setUp(() async {
    a = await SyncTestDevice.open('a', origin: _originAHex);
    b = await SyncTestDevice.open('b');
    await a.sql('UPDATE sync_state SET group_id = ?', [_groupHex]);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<void> seedNotes(SyncTestDevice device, int count) async {
    for (var i = 0; i < count; i++) {
      await device.insertNote('n$i', 'title $i');
    }
  }

  group('manifests (D7)', () {
    late ManifestSigner signer;

    setUp(() async {
      signer = ManifestSigner(
          groupId: GroupId.fromHex(_groupHex),
          origin: OriginId.fromHex(_originAHex),
          signer: await Ed25519KeyPair.generate());
    });

    test('signs only the unsigned own range and sets manifest_id', () async {
      await seedNotes(a, _noteCount);
      final top = (await a.store.readVector())[_originAHex]!;

      final first = await a.store.signOwnManifests(signer);
      expect(first.map((m) => (m.fromSeq, m.toSeq)), [(0, top)]);
      expect(
          await a.count(
              'SELECT COUNT(*) FROM sync_clock WHERE manifest_id IS NULL'),
          0);
      expect(await a.count('SELECT COUNT(*) FROM sync_origin_batch'), 1);
      expect(await a.store.signOwnManifests(signer), isEmpty);

      await a.setTitle('n0', 'edited');
      final second = await a.store.signOwnManifests(signer);
      expect(second.single.fromSeq, top);
      expect(
          await a.count(
              'SELECT COUNT(*) FROM sync_clock WHERE manifest_id IS NULL'),
          0);
    });

    test('serves stored manifests and attaches them on the receiver', () async {
      await seedNotes(a, _noteCount);
      await a.store.signOwnManifests(signer);
      final top = (await a.store.readVector())[_originAHex]!;

      final served =
          await a.store.readManifests(_originAHex, afterSeq: 0, upToSeq: top);
      final batch = await a.store.readChanges(_originAHex, afterSeq: 0);
      await b.store.applyBatch(batch, manifest: served.single);

      expect(
          await b.count(
              'SELECT COUNT(*) FROM sync_clock WHERE manifest_id IS NULL'),
          0);
      final again =
          await b.store.readManifests(_originAHex, afterSeq: 0, upToSeq: top);
      expect(again.single.hashes, served.single.hashes);
      expect(again.single.sig, served.single.sig);
    });
  });

  group('security rows (D7, D13)', () {
    test('apply stores the row and serves the identical record bytes',
        () async {
      final member = _member('m1');
      final revocation = _revocation();
      final grant = _grant();
      final cells = [
        _securityCell(memberCellKey('m1'), member.encode(), 100),
        _securityCell(revocationCellKey(revocation),
            encodeRevocationRecord(revocation), 101),
        _securityCell(epochGrantCellKey(grant), encodeEpochGrant(grant), 102),
      ];

      final report = await b.store.applyBatch(ChangeBatch(
          origin: 'origin-x', fromSeq: 0, toSeq: 102, cells: cells));
      expect(report.applied, 3);
      expect(await b.count('SELECT COUNT(*) FROM sync_member_table'), 1);
      expect(await b.count('SELECT COUNT(*) FROM sync_revocation'), 1);
      expect(await b.count('SELECT COUNT(*) FROM sync_epoch_grant'), 1);

      final served =
          await b.store.readChanges('origin-x', afterSeq: 0, upToSeq: 102);
      expect(served.cells.map((c) => c.key), cells.map((c) => c.key));
      for (var i = 0; i < cells.length; i++) {
        expect(served.cells[i].value, cells[i].value);
      }
    });

    test('a record under the wrong pk fails its savepoint and is held',
        () async {
      final report = await b.store.applyBatch(ChangeBatch(
          origin: 'origin-x',
          fromSeq: 0,
          toSeq: 100,
          cells: [
            _securityCell(memberCellKey('other'), _member('m1').encode(), 100)
          ]));
      expect(report.failed, 1);
      expect(await b.count('SELECT COUNT(*) FROM sync_member_table'), 0);
      expect(await b.store.refetchKeys(), [memberCellKey('other')]);
    });

    test('registrations are stored once and served back', () async {
      final registration = OriginRegistration(
          origin: OriginId(_bytes(16, 9)),
          memberPub: _bytes(32, 2),
          createdHlc: 5 << 16,
          sig: _bytes(64, 7));
      expect(await b.store.mergeRegistrations([registration]), 1);
      expect(await b.store.mergeRegistrations([registration]), 0);
      final stored = (await b.store.readRegistrations()).single;
      expect(stored.origin, registration.origin);
      expect(stored.sig, registration.sig);
    });

    group('never-sent rule on origin switch', () {
      setUp(() async {
        await seedNotes(a, 3);
        await a.store
            .writeSecurityCell(memberCellKey('m1'), _member('m1').encode());
      });

      test('restore leaves the unsigned security cell and flags re-pairing',
          () async {
        final report = await a.store
            .switchOrigin(OriginSwitchReason.restore, newOrigin: 'origin-a2');
        expect(report.securityLeftBehind, 1);
        expect(report.needsRepairing, isTrue);
        expect(report.strandedMemberIds, ['m1']);
        expect(await SyncUpgradeJob(a.db).runChunks(), isTrue);

        final securityOrigin = await a.rows('''
SELECT o.value AS origin FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id
JOIN sync_row r ON r.id = c.key / 256 WHERE r.tbl_id >= 100''');
        expect(securityOrigin.single['origin'], _originAHex);
        expect(await a.count('SELECT COUNT(*) FROM sync_member_table'), 1);
        expect(
            await a.count(
                "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = 'origin-a2'"),
            greaterThan(0));
      });

      test('restore lists only other members, sorted, and ignores other security tables', () async {
        const ownId = 'm-own';
        await a.store.bindIdentity(memberId: ownId);
        await a.store.writeSecurityCell(memberCellKey(ownId), _member(ownId).encode());
        await a.store.writeSecurityCell(memberCellKey('m0'), _member('m0').encode());
        final revocation = _revocation();
        await a.store.writeSecurityCell(revocationCellKey(revocation), encodeRevocationRecord(revocation));

        final report = await a.store.switchOrigin(OriginSwitchReason.restore, newOrigin: 'origin-a2');

        expect(report.securityLeftBehind, 4, reason: 'two members + own member + revocation never left');
        expect(report.strandedMemberIds, ['m0', 'm1'], reason: 'own id and the revocation row are not joiners');
      });

      test('local_reset keeps the security row and adopts its cell', () async {
        final report = await a.store.localReset(newOrigin: 'origin-a2');
        expect(report.securityLeftBehind, 0);
        expect(report.strandedMemberIds, isEmpty);
        expect(await a.count('SELECT COUNT(*) FROM note_table'), 0);
        expect(await a.count('SELECT COUNT(*) FROM sync_member_table'), 1);
        final adopted = await a.rows('''
SELECT o.value AS origin FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id
JOIN sync_row r ON r.id = c.key / 256 WHERE r.tbl_id >= 100''');
        expect(adopted.single['origin'], 'origin-a2');
        final vector = await a.store.readVector();
        expect(vector['origin-a2'], 1);
      });

      test('group_switch purges security rows and their clock rows', () async {
        await a.store.switchOrigin(OriginSwitchReason.groupSwitch,
            newOrigin: 'origin-a2');
        expect(await a.count('SELECT COUNT(*) FROM sync_member_table'), 0);
        expect(
            await a.count(
                'SELECT COUNT(*) FROM sync_clock c JOIN sync_row r ON r.id = c.key / 256 WHERE r.tbl_id >= 100'),
            0);
      });
    });
  });

  group('duplicate identity (D14)', () {
    CellRecord noteCell(String pk, int clock, int seq) => CellRecord(
        key: CellKey('note_table', pk, 'title'),
        value: 't',
        clock: clock,
        node: 'node-z',
        origin: 'origin-z',
        originSeq: seq);

    test('a different change under a stored (origin, seq) flags the peer',
        () async {
      await b.store.applyBatch(ChangeBatch(
          origin: 'origin-z',
          fromSeq: 0,
          toSeq: 5,
          cells: [noteCell('n1', 1 << 20, 5)]));

      final same = await b.store.applyBatch(
          ChangeBatch(
              origin: 'origin-z',
              fromSeq: 0,
              toSeq: 5,
              cells: [noteCell('n1', 1 << 20, 5)]),
          peerMemberId: 'peer');
      expect(same.duplicateIdentityOrigins, isEmpty);

      final clash = await b.store.applyBatch(
          ChangeBatch(
              origin: 'origin-z',
              fromSeq: 0,
              toSeq: 5,
              cells: [noteCell('n2', 2 << 20, 5)]),
          peerMemberId: 'peer');
      expect(clash.duplicateIdentityOrigins, {'origin-z'});
      expect(
          (await b.rows(
                  "SELECT last_result_category AS c FROM sync_peer_state_table WHERE member_id = 'peer'"))
              .single['c'],
          'duplicated_identity');
    });
  });

  group('held envelopes (FR-010, FR-011)', () {
    CellRecord title(int clock) => CellRecord(
        key: const CellKey('note_table', 'n1', 'title'),
        value: 't',
        clock: clock,
        node: 'node-z',
        origin: 'origin-z',
        originSeq: 1);

    test('a failed item is refetchable, counted, and cleared by a good copy',
        () async {
      final bad = ChangeBatch(
          origin: 'origin-z', fromSeq: 0, toSeq: 1, cells: [title(_farHlc)]);
      expect((await b.store.applyBatch(bad)).failed, 1);
      await b.store.applyBatch(bad);
      expect(await b.store.refetchKeys(),
          [const CellKey('note_table', 'n1', 'title')]);
      expect(await b.count('SELECT fail_count FROM sync_held_envelope'), 2);

      final good = ChangeBatch(
          origin: 'origin-z', fromSeq: 0, toSeq: 1, cells: [title(1 << 20)]);
      expect((await b.store.applyBatch(good)).failed, 0);
      expect(await b.store.refetchKeys(), isEmpty);
    });
  });

  group('pipelined session (T12)', () {
    test('reading the next page while the previous one applies converges',
        () async {
      await seedNotes(a, 20);
      final top = (await a.store.readVector())[_originAHex]!;
      var after = 0;
      var nextRead = a.store.readChanges(_originAHex,
          afterSeq: after, upToSeq: top, limit: _pageSize);
      while (after < top) {
        final batch = await nextRead;
        after = batch.toSeq;
        if (after >= top) {
          await b.store.applyBatch(batch);
          break;
        }
        nextRead = a.store.readChanges(_originAHex,
            afterSeq: after, upToSeq: top, limit: _pageSize);
        await b.store.applyBatch(batch);
      }
      expect(await b.content(), await a.content());
      expect((await b.store.readVector())[_originAHex], top);
    });

    test('a read issued during an apply sees the whole batch or none of it',
        () async {
      await seedNotes(a, 6);
      final batch = await a.store.readChanges(_originAHex, afterSeq: 0);
      final results = await Future.wait([
        b.store.applyBatch(batch),
        b.store.readChanges(_originAHex, afterSeq: 0, upToSeq: batch.toSeq),
      ]);
      final seen = (results[1] as ChangeBatch).cells.length;
      expect(seen == 0 || seen == batch.cells.length, isTrue);
    });
  });

  group('AsyncReplicaStore port', () {
    test('changesSince and mergeBatch converge two devices', () async {
      await seedNotes(a, 10);
      expect(await a.store.nodeId(), 'node-a');
      final missing = await a.store
          .changesSince(await b.store.vector(), maxCellsPerBatch: 5);
      expect(missing.length, greaterThan(1));
      for (final batch in missing) {
        expect(await b.store.mergeBatch(batch), isTrue);
        expect(await b.store.mergeBatch(batch), isFalse);
      }
      expect(await b.content(), await a.content());
      expect(await a.store.changesSince(await b.store.vector()), isEmpty);
    });
  });
}
