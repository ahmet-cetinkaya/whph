/// T12 acc 8: named engine scenarios (restore, group switch, cascade,
/// set-total, replace-import, whole-directory restore, key loss).
library;

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

Future<List<SyncDevice>> _group(List<String> names, int seed, List<TestClock> clocks) async {
  final devices = [
    for (var i = 0; i < names.length; i++) await newDevice(names[i], seed: seed + i, clock: clocks[i]),
  ];
  await pairAll(devices);
  return devices;
}

List<TestClock> _clocks(int n) => [for (var i = 0; i < n; i++) TestClock()];

void main() {
  group('restore', () {
    test('restore of an old snapshot: kept tombstones re-delete (no resurrection)', () async {
      final clocks = _clocks(3);
      final [a, b, c] = await _group(['A', 'B', 'C'], 100, clocks);
      final [ca, cb, cc] = clocks;
      createRow(a, 'x', 'seen by B');
      createRow(a, 'y', 'kept');
      expect((await runSessionPair(a, b)).bothComplete, isTrue);
      cc.advance(5);
      createRow(c, 'c', 'authored by C, reached A before the snapshot');
      expect((await runSessionPair(c, a)).bothComplete, isTrue);
      ca.advance(10);
      createRow(a, 'u', 'in the snapshot, not yet sent');
      final oldDb = await a.snapshotDb();
      expect(aliveRows(b.store, 'task'), {'x', 'y'}, reason: 'B had not seen u or C\'s item at snapshot time');
      createRow(a, 'v', 'written and sent after the snapshot');

      // Later B deletes x; everyone receives the deletion (and keeps it).
      cb.advance(1000);
      b.delete(row('x'));
      await syncUntilQuiet([a, b, c]);
      for (final d in [a, b, c]) {
        expect(d.store.isRowAlive('task', 'x'), isFalse, reason: d.name);
      }

      // A's DB is restored from the old snapshot (key file and sync ledger
      // current): the startup check switches origin (D14 rule 4).
      final oldOrigin = a.store.localOrigin;
      expect(await a.restoreDb(oldDb), StartupAction.restore);
      expect(a.store.localOrigin, isNot(oldOrigin));
      expect(a.store.isRowAlive('task', 'x'), isTrue, reason: 'the snapshot predates the delete');

      final withB = await runSessionPair(a, b);
      expect(withB.bothComplete, isTrue, reason: '$withB');
      expect(a.store.isRowAlive('task', 'x'), isFalse, reason: 'B\'s kept tombstone re-deletes x on A');
      final withC = await runSessionPair(a, c);
      expect(withC.bothComplete, isTrue, reason: '$withC');
      await syncUntilQuiet([a, b, c]);
      for (final d in [a, b, c]) {
        expect(d.store.isRowAlive('task', 'x'), isFalse, reason: '${d.name}: no resurrection');
        expect(aliveRows(d.store, 'task'), {'y', 'u', 'v', 'c'}, reason: d.name);
      }
      expect(content(a.store), content(b.store));
      expect(content(a.store), content(c.store));
      expect(fingerprint(a.store), fingerprint(b.store));
      expect(fingerprint(a.store), fingerprint(c.store));
    });

    test('an item unsigned in the restored snapshot but sent later converges via the peer copy', () async {
      final clocks = _clocks(2);
      final [a, b] = await _group(['A', 'B'], 110, clocks);
      final [ca, cb] = clocks;
      createRow(a, 'x', 'seen');
      expect((await runSessionPair(a, b)).bothComplete, isTrue);
      createRow(a, 'u', 'never sent');
      final oldDb = await a.snapshotDb();
      ca.advance(1000);
      createRow(a, 'v', 'sent after the snapshot');
      expect((await runSessionPair(a, b)).bothComplete, isTrue);
      cb.advance(1000);
      b.delete(row('x'));
      expect(await a.restoreDb(oldDb), StartupAction.restore, reason: 'the DB is behind the sent mark');
      final r = await runSessionPair(a, b);
      expect(r.bothComplete, isTrue, reason: '$r');
      await syncUntilQuiet([a, b]);
      for (final d in [a, b]) {
        expect(aliveRows(d.store, 'task'), {'u', 'v'}, reason: d.name);
      }
      expect(fingerprint(a.store), fingerprint(b.store));
    });
  });

  test('group switch: new-group membership = before ∪ {joiner}; old and new groups never authenticate', () async {
    final clocks = _clocks(5);
    final [a, b] = await _group(['A', 'B'], 200, clocks.sublist(0, 2));
    final [c, d, e] = await _group(['C', 'D', 'E'], 210, clocks.sublist(2));
    createRow(a, 'g1', 'G1 data');
    createRow(d, 'd1', 'authored by D in G2');
    createRow(c, 'c1', 'authored by C in G2');
    await syncUntilQuiet([a, b]);
    await syncUntilQuiet([c, d, e]);
    final g1Before = {for (final m in a.membership.activeMembers) m.memberId};
    final g2Origins = {for (final r in c.store.registrations) r.origin.hex};

    // Without confirmation nothing changes on either side.
    final cGroup = c.membership.groupId;
    await expectLater(SyncDevice.pair(inviter: a, joiner: c), throwsA(isA<PairingException>()));
    expect(c.membership.groupId, cGroup);
    expect(a.membership.activeMembers.map((m) => m.memberId).toSet(), g1Before);

    await SyncDevice.pair(inviter: a, joiner: c, confirmGroupSwitch: true);
    expect(c.membership.groupId, a.membership.groupId);
    await syncUntilQuiet([a, b, c]);

    final g1After = g1Before.union({c.memberId});
    for (final x in [a, b, c]) {
      expect({for (final m in x.membership.activeMembers) m.memberId}, g1After, reason: x.name);
      expect(x.store.registrations.where((r) => g2Origins.contains(r.origin.hex)), isEmpty, reason: x.name);
      for (final pk in x.store.rowsOf(SecurityTables.member)) {
        expect(g1After, contains(pk), reason: '${x.name}: no G2 member row');
      }
      expect(aliveRows(x.store, 'task'), {'g1', 'd1', 'c1'}, reason: '${x.name}: C\'s former data arrived');
    }

    // No authenticated session between an old-group and a new-group member.
    for (final old in [d, e]) {
      for (final fresh in [a, b, c]) {
        for (final (i, r) in [(old, fresh), (fresh, old)]) {
          final p = await runSessionPair(i, r);
          expect(p.initiator, isA<SessionFailed>(), reason: '${i.name}->${r.name}');
          expect(p.responder, isA<SessionFailed>(), reason: '${i.name}->${r.name}');
          expect(p.initiator.stats.envelopesSent + p.responder.stats.envelopesSent, 0);
          expect(p.initiator.stats.envelopesReceived + p.responder.stats.envelopesReceived, 0);
        }
      }
    }
    expect({for (final m in d.membership.activeMembers) m.memberId}, containsAll([d.memberId, e.memberId]));
    expect((await runSessionPair(d, e)).bothComplete, isTrue, reason: 'G2 keeps working without C');
  });

  test('cascade delete concurrent with a later parent edit: parent and cause-linked children alive everywhere',
      () async {
    final clocks = _clocks(3);
    final [a, b, c] = await _group(['A', 'B', 'C'], 300, clocks);
    final [ca, cb, _] = clocks;
    createRow(a, 'p', 'parent');
    for (final child in ['c1', 'c2', 'c3']) {
      createRow(a, child, 'child $child');
    }
    await syncUntilQuiet([a, b, c]);
    // c3 is deleted independently first.
    b.delete(row('c3'));
    await syncUntilQuiet([a, b, c]);

    // A cascade-deletes p; B concurrently edits p later (B has not seen the delete).
    ca.advance(1000);
    a.cascadeDelete(row('p'), [row('c1'), row('c2')]);
    cb.advance(5000);
    b.write(const CellKey('task', 'p', 'title'), 'edited later on B');

    final causes = <RowRef?>[];
    final r = await runSessionPair(
      a,
      c,
      hooksA: SessionHooks(outgoingBatch: (batch) {
        for (final e in batch.envelopes) {
          if (e.col == CellKey.existenceCol && (e.pk == 'c1' || e.pk == 'c2')) causes.add(e.cause);
        }
        return batch;
      }),
    );
    expect(r.bothComplete, isTrue);
    expect(causes, [const RowRef('task', 'p'), const RowRef('task', 'p')], reason: 'cause travels as names');
    await syncUntilQuiet([a, b, c]);
    for (final d in [a, b, c]) {
      expect(aliveRows(d.store, 'task'), {'p', 'c1', 'c2'}, reason: d.name);
      expect(d.store.read(const CellKey('task', 'c1', CellKey.existenceCol))?.cause, const RowRef('task', 'p'),
          reason: '${d.name}: the child tombstone keeps its cause');
    }
    expect(content(a.store), content(b.store));
    expect(content(b.store), content(c.store));
  });

  test('set-total concurrent with an add of d: total = target + d on every device (D12)', () async {
    final clocks = _clocks(2);
    final [a, b] = await _group(['A', 'B'], 400, clocks);
    // Per-device buckets for (owner task t, hour h): row id = t|h|member.
    String bucket(SyncDevice x) => 't1|h0|${x.memberId}';
    int total(SyncDevice x) {
      var sum = 0;
      for (final pk in x.store.rowsOf('time_bucket')) {
        if (!x.store.isRowAlive('time_bucket', pk)) continue;
        sum += (x.store.read(CellKey('time_bucket', pk, CellKey.rowCol))?.value as int?) ?? 0;
      }
      return sum;
    }

    void writeBucket(SyncDevice x, int value) => x
      ..write(CellKey('time_bucket', bucket(x), CellKey.existenceCol), null)
      ..write(CellKey('time_bucket', bucket(x), CellKey.rowCol), value);

    writeBucket(b, 5);
    await syncUntilQuiet([a, b]);
    // A sets the total to 20 (own bucket = 20 − others seen = 15) while B
    // concurrently adds 3 to its own bucket.
    const target = 20;
    const added = 3;
    writeBucket(a, target - (total(a) - 0));
    writeBucket(b, 5 + added);
    await syncUntilQuiet([a, b]);
    expect(total(a), target + added);
    expect(total(b), target + added);
  });

  test('replace-import: imported values win where their HLC is higher, absent items return, 0 tombstones', () async {
    final clocks = _clocks(2);
    final [a, b] = await _group(['A', 'B'], 500, clocks);
    final [ca, cb] = clocks;
    for (final pk in ['i1', 'i2', 'i3']) {
      createRow(a, pk, 'original $pk');
    }
    await syncUntilQuiet([a, b]);
    // B edits i3 concurrently with a clock one hour ahead: its HLC is higher.
    cb.advance(3600 * 1000);
    b.write(const CellKey('task', 'i3', 'title'), 'B edit (later HLC)');
    ca.advance(10);
    final oldOrigin = a.store.localOrigin;
    await a.replaceImport([
      (const CellKey('task', 'i1', CellKey.existenceCol), null),
      (const CellKey('task', 'i1', 'title'), 'imported i1'),
      (const CellKey('task', 'i3', CellKey.existenceCol), null),
      (const CellKey('task', 'i3', 'title'), 'imported i3'),
    ]);
    expect(a.store.localOrigin, isNot(oldOrigin));
    expect(a.store.sealedOrigins, contains(oldOrigin.hex));
    expect(aliveRows(a.store, 'task'), {'i1', 'i3'});
    final tombstones =
        a.store.cells.where((c) => c.key.isExistence && c.value != null && c.origin == a.store.localOrigin.hex);
    expect(tombstones, isEmpty, reason: 'the import creates no tombstone');

    await syncUntilQuiet([a, b]);
    for (final d in [a, b]) {
      expect(aliveRows(d.store, 'task'), {'i1', 'i2', 'i3'}, reason: '${d.name}: absent items return (union)');
      expect(d.store.read(const CellKey('task', 'i1', 'title'))?.value, 'imported i1');
      expect(d.store.read(const CellKey('task', 'i2', 'title'))?.value, 'original i2');
      expect(d.store.read(const CellKey('task', 'i3', 'title'))?.value, 'B edit (later HLC)');
    }
    expect(a.store.cells.where((c) => c.key.isExistence && c.value != null), isEmpty);
    expect(content(a.store), content(b.store));
  });

  test('whole-directory restore: peer-cursor check → switch_origin(restore) → retry, 0 lost edits', () async {
    final clocks = _clocks(2);
    final ledger = InMemorySyncLedger();
    final a = await newDevice('A', seed: 600, clock: clocks[0], ledger: ledger);
    final b = await newDevice('B', seed: 601, clock: clocks[1]);
    await pairAll([a, b]);
    final ca = clocks[0];
    createRow(a, 'k0', 'before the backup');
    expect((await runSessionPair(a, b)).bothComplete, isTrue);
    final backup = await a.snapshotDirectory();
    final ledgerBackup = ledger.snapshot();
    ca.advance(10);
    createRow(a, 'e1', 'after the backup');
    createRow(a, 'e2', 'after the backup');
    expect((await runSessionPair(a, b)).bothComplete, isTrue);

    // DB, key file and sync ledger are rolled back together (the accepted
    // U11 full-rollback case; the engine has no API for it).
    final origin = a.store.localOrigin;
    ledger.restoreFrom(ledgerBackup);
    expect(await a.restoreDirectory(backup), StartupAction.normal, reason: 'nothing local can tell');
    ca.advance(10);
    createRow(a, 'e3', 'after the restore'); // reuses seqs B already holds

    final r = await runSessionPair(a, b);
    expect(r.retried, isTrue);
    expect(a.store.localOrigin, isNot(origin), reason: 'switch_origin(restore) ran');
    expect(r.bothComplete, isTrue, reason: '$r');
    await syncUntilQuiet([a, b]);
    for (final d in [a, b]) {
      expect(aliveRows(d.store, 'task'), {'k0', 'e1', 'e2', 'e3'}, reason: '${d.name}: 0 lost edits');
    }
    expect(content(a.store), content(b.store));
  });

  test('key_lost with an old DB: new identity, never-sent cells adopted, old member revoked elsewhere', () async {
    final clocks = _clocks(2);
    final [a, b] = await _group(['A', 'B'], 700, clocks);
    final [ca, _] = clocks;
    createRow(a, 'x', 'sent before the backup');
    expect((await runSessionPair(a, b)).bothComplete, isTrue);
    ca.advance(10);
    createRow(a, 'u', 'never sent before the backup');
    final oldDb = await a.snapshotDb();
    ca.advance(10);
    createRow(a, 'y', 'sent after the backup');
    expect((await runSessionPair(a, b)).bothComplete, isTrue);
    final oldId = a.memberId;
    final oldOrigin = a.store.localOrigin;

    // The app is restored onto a new device: old DB, no key file, no origins
    // file (both excluded from backups).
    expect(await a.loseKeyFile(oldDb: oldDb, loseLedger: true), StartupAction.keyLost);
    expect(a.memberId, isNot(oldId));
    expect(a.needsRepairing, isTrue);
    expect(a.membership.hasGroup, isFalse);
    final adopted = a.store.cells.where((c) => c.key.pk == 'u' && c.origin == a.store.localOrigin.hex);
    expect(adopted, isNotEmpty, reason: 'never-sent cells moved to the new origin');
    expect(a.store.cells.where((c) => c.key.pk == 'x').every((c) => c.origin == oldOrigin.hex), isTrue);

    // Another device removes the old member, then pairs the new identity.
    await b.removeMember(oldId);
    expect(b.membership.isRevokedEd(b.membership.memberById(oldId)!.ed25519Pub), isTrue);
    await SyncDevice.pair(inviter: b, joiner: a);
    expect(a.needsRepairing, isFalse);
    await syncUntilQuiet([a, b]);
    for (final d in [a, b]) {
      expect(aliveRows(d.store, 'task'), {'x', 'u', 'y'}, reason: d.name);
      expect({for (final m in d.membership.activeMembers) m.memberId}, {a.memberId, b.memberId}, reason: d.name);
    }
    expect(content(a.store), content(b.store));
  });
}
