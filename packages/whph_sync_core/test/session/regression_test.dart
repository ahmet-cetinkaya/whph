/// Regressions found by randomized engine runs (T12 part A).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_test_support.dart';

void main() {
  // ACF-45 probe 3: the exact 100006 order - everything synced quiet FIRST
  // (rows learned), THEN the receiver restores an older DB (rows lost),
  // then sessions run: the rows must come back AND root.
  test('receiver_restore_after_quiet_loses_and_relearns_rows', () async {
    final [a, b, c, d2] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 780 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    await SyncDevice.pair(inviter: c, joiner: d2);
    await syncUntilQuiet([a, b, c, d2]);
    final oldD2 = d2.memberId;
    final d2Db = await d2.snapshotDb();
    final receiverDb = await c.snapshotDb();

    await d2.loseKeyFile(oldDb: d2Db, loseLedger: true);
    await b.removeMember(oldD2);
    await SyncDevice.pair(inviter: b, joiner: d2);
    await syncUntilQuiet([a, b, c, d2], maxRounds: 10);
    expect(c.membership.memberById(d2.memberId), isNotNull, reason: 'learned before the restore');

    await c.restoreDb(receiverDb);
    expect((await runSessionPair(b, c)).bothComplete, isTrue);
    expect(c.membership.memberById(d2.memberId), isNotNull, reason: 'roots again after the restore');
  });

  // ACF-45 probe 2: the 100006 shape - the receiver's restore keeps the
  // ledger current (startup switches the receiver to a NEW origin), the
  // registration belongs to the inviter's post-keyLost origin, and the
  // re-invited member's row is carried by it.
  test('receiver_with_origin_switch_relearns_registration_and_roots_invited_member', () async {
    final [a, b, c, d2] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 770 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    await SyncDevice.pair(inviter: c, joiner: d2);
    await syncUntilQuiet([a, b, c, d2]);
    final oldD2 = d2.memberId;
    final d2Db = await d2.snapshotDb();
    final receiverDb = await c.snapshotDb();

    await d2.loseKeyFile(oldDb: d2Db, loseLedger: true);
    await b.removeMember(oldD2);
    await SyncDevice.pair(inviter: b, joiner: d2);
    final inviterOrigin = b.store.localOrigin;
    final inviterReg = b.store.registrations.where((r) => r.origin == inviterOrigin).toList();
    expect(inviterReg, isNotEmpty);

    await c.restoreDb(receiverDb);
    expect((await runSessionPair(b, c)).bothComplete, isTrue);

    expect(
      c.store.registrations.where((r) => r.origin == inviterOrigin),
      isNotEmpty,
      reason: 'the receiver re-learned the inviter origin registration',
    );
    expect(c.membership.memberById(d2.memberId), isNotNull, reason: 'the invited member roots');
  });

  // ACF-45 probe: a device whose restore rolled the origin-registration
  // table back must re-learn registrations from any peer in the next
  // session (the writer sends them unconditionally).
  test('restored_device_relearns_origin_registration_next_session', () async {
    final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 760 + i)];
    await pairAll([a, b, c]);
    await syncUntilQuiet([a, b, c]);
    final bOrigin = b.store.localOrigin;
    final oldDb = await c.snapshotDb();
    // B switches origin after the snapshot, so a NEW registration exists.
    await b.switchOrigin(OriginSwitchReason.restore);
    expect((await runSessionPair(b, a)).bothComplete, isTrue);
    final newOrigin = b.store.localOrigin;
    expect(newOrigin, isNot(bOrigin));
    final newReg = a.store.registrations
        .firstWhere((r) => r.origin == newOrigin, orElse: () => fail('no new registration learned'));

    await c.restoreDb(oldDb);
    expect(
      c.store.registrations.where((r) => r.origin == newReg.origin),
      isEmpty,
      reason: 'the restored DB predates the registration',
    );
    expect((await runSessionPair(a, c)).bothComplete, isTrue);
    expect(
      c.store.registrations.where((r) => r.origin == newReg.origin),
      isNotEmpty,
      reason: 'the next session must re-teach the registration',
    );
  });

  test('a later edit by a device that never saw the delete revives the item with its other fields (FR-006)', () async {
    final ca = TestClock();
    final cc = TestClock();
    final a = await newDevice('A', seed: 1, clock: ca);
    final c = await newDevice('C', seed: 2, clock: cc);
    await SyncDevice.pair(inviter: a, joiner: c);
    createRow(a, 'x', 'title before the delete');
    a.write(const CellKey('task', 'x', 'note'), 'note before the delete');
    expect((await runSessionPair(a, c)).bothComplete, isTrue);
    // A deletes x; C, offline and unaware of the delete, edits x 200 days
    // later (the tombstone is kept, so A still holds the whole item).
    ca.advance(1000);
    a.delete(row('x'));
    ca.advance(200 * day);
    cc.advance(200 * day);
    c.write(const CellKey('task', 'x', 'note'), 'offline edit');
    final r = await runSessionPair(c, a);
    expect(r.bothComplete, isTrue, reason: '$r');
    for (final d in [a, c]) {
      expect(d.store.isRowAlive('task', 'x'), isTrue, reason: '${d.name}: the later edit revives x');
      expect(d.store.read(const CellKey('task', 'x', 'title'))?.value, 'title before the delete', reason: d.name);
      expect(d.store.read(const CellKey('task', 'x', 'note'))?.value, 'offline edit', reason: d.name);
    }
    expect(content(a.store), content(c.store));
  });

  test('the key-file anchors keep members learned after pairing across a DB restore', () async {
    final clock = TestClock();
    final a = await newDevice('A', seed: 3, clock: clock);
    final b = await newDevice('B', seed: 4, clock: clock);
    final d = await newDevice('D', seed: 5, clock: clock);
    await SyncDevice.pair(inviter: a, joiner: b);
    final old = await b.snapshotDb();
    await SyncDevice.pair(inviter: a, joiner: d);
    expect((await runSessionPair(a, b)).bothComplete, isTrue);
    expect(b.membership.activeMembers.map((m) => m.memberId), contains(d.memberId));
    await b.restoreDb(old);
    expect(b.store.rowsOf(SecurityTables.member), isNot(contains(d.memberId)), reason: 'the DB predates D');
    expect((await runSessionPair(d, b)).bothComplete, isTrue, reason: 'B still accepts D (anchors)');
  });

  test('replace-import before any sync: never-sent security rows are adopted and still reach the group', () async {
    final clock = TestClock();
    final a = await newDevice('A', seed: 6, clock: clock);
    final b = await newDevice('B', seed: 7, clock: clock);
    final c = await newDevice('C', seed: 8, clock: clock);
    await pairAll([a, b, c]);
    final oldOrigin = a.store.localOrigin.hex;
    await a.replaceImport([(const CellKey('task', 'imp', 'title'), 'imported')]);
    expect(a.store.cells.where((cell) => cell.origin == oldOrigin), isEmpty,
        reason: 'the member rows A authored but never sent moved to the new origin');
    expect(a.store.rowsOf(SecurityTables.member), hasLength(3));
    expect((await runSessionPair(b, a)).bothComplete, isTrue);
    expect(b.membership.activeMembers.map((m) => m.memberId), contains(c.memberId),
        reason: 'B learns C from the rows A authored before the import');
    expect((await runSessionPair(b, c)).bothComplete, isTrue);
  });

  test('after replace-import, sent security rows held above the own cursor are still served', () async {
    final clock = TestClock();
    final a = await newDevice('A', seed: 9, clock: clock);
    final b = await newDevice('B', seed: 10, clock: clock);
    final c = await newDevice('C', seed: 11, clock: clock);
    final d = await newDevice('D', seed: 12, clock: clock);
    await pairAll([a, b, c]);
    await SyncDevice.pair(inviter: a, joiner: d);
    expect((await runSessionPair(a, b)).bothComplete, isTrue, reason: 'A\'s rows get manifests');
    await a.replaceImport(const []);
    expect(a.store.cursorOf(a.store.sealedOrigins.single), 0, reason: 'local_reset cleared the vector');
    final r = await runSessionPair(c, a);
    expect(r.bothComplete, isTrue);
    expect(r.responder.stats.aboveCursorSent, greaterThan(0));
    expect(c.membership.activeMembers.map((m) => m.memberId), contains(d.memberId));
    expect((await runSessionPair(c, d)).bothComplete, isTrue);
  });

  test('a reordered frame with no later frame is delivered late instead of hanging the session', () async {
    final (a, b) = InMemoryTransport.pair(faults: const TransportFaults(reorder: {0}));
    await a.send(Uint8List.fromList([7]));
    expect((await b.receive()).single, 7);
  });

  test('random ops with faults, cascades, revivals, DB restores and replace-imports converge', () async {
    for (var seed = 1; seed <= 6; seed++) {
      await _randomRun(seed);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('restore_after_cut_send', () async {
    for (var cut = 1; cut <= 40; cut++) {
      final ca = TestClock();
      final a = await newDevice('A', seed: 1, clock: ca);
      final b = await newDevice('B', seed: 2);
      await SyncDevice.pair(inviter: a, joiner: b);
      createRow(a, 'x', 'sent');
      await runSessionPair(a, b);
      ca.advance(10);
      createRow(a, 'u', 'in snapshot, unsent');
      final snapshot = await a.snapshotDb();
      ca.advance(10);
      createRow(a, 'v', 'after snapshot');
      await runSessionPair(a, b, faults: TransportFaults(cutAfter: cut));
      await a.restoreDb(snapshot);
      await syncUntilQuiet([a, b]);
      expect(fingerprint(a.store), fingerprint(b.store), reason: 'diverged after a cut at $cut');
    }
  });

  // Card A: the ledger's written watermark (persisted at snapshot time)
  // remembers seqs and hlcs the device authored but never sent, so a data-dir
  // restore below them switches the origin instead of silently re-authoring
  // them under new content.
  test('restore_below_own_written_seqs_switches_origin', () async {
    final ca = TestClock();
    final a = await newDevice('A', seed: 1, clock: ca);
    final b = await newDevice('B', seed: 2);
    await SyncDevice.pair(inviter: a, joiner: b);
    createRow(a, 'x', 'sent');
    await runSessionPair(a, b);
    final earlier = await a.snapshotDb();
    final originAtSnapshot = a.store.localOrigin;
    createRow(a, 'u', 'unsent, remembered by a later snapshot');
    final later = await a.snapshotDb();
    createRow(a, 'v', 'unsent, beyond any snapshot');
    expect(await a.restoreDb(earlier), StartupAction.restore);
    expect(a.store.localOrigin, isNot(originAtSnapshot),
        reason: 'seqs above the earlier snapshot were never sent, so the ledger mark alone cannot catch the reuse');
    expect(later, isNotNull);
  });

  // Efe P2 (no explicit flush): a write between taking snapshot S and
  // restoring S, with no later snapshot, must still switch the origin. The
  // watermark is flushed by the engine itself (session start/end, and before
  // a restore replaces the DB), not only by the app on pause.
  test('restore_below_unflushed_written_seqs_switches_origin', () async {
    final ca = TestClock();
    final a = await newDevice('A', seed: 1, clock: ca);
    final b = await newDevice('B', seed: 2);
    await SyncDevice.pair(inviter: a, joiner: b);
    createRow(a, 'x', 'sent');
    await runSessionPair(a, b);
    final snapshot = await a.snapshotDb();
    final originAtSnapshot = a.store.localOrigin;
    createRow(a, 'u', 'unsent, never snapshotted, never explicitly flushed');
    expect(await a.restoreDb(snapshot), StartupAction.restore);
    expect(a.store.localOrigin, isNot(originAtSnapshot),
        reason: 'restoreDb flushes the live watermark before the DB is replaced');
  });

  // The app-pause path: an explicit flush persists the watermark between
  // sessions, so even a restart-then-restore (restore below a flushed write)
  // is caught.
  test('explicit_flush_on_pause_persists_the_written_watermark', () async {
    final ca = TestClock();
    final a = await newDevice('A', seed: 1, clock: ca);
    final b = await newDevice('B', seed: 2);
    await SyncDevice.pair(inviter: a, joiner: b);
    createRow(a, 'x', 'sent');
    await runSessionPair(a, b);
    final snapshot = await a.snapshotDb();
    final originAtSnapshot = a.store.localOrigin;
    createRow(a, 'u', 'unsent');
    expect(a.store.authoredSinceWatermark, isTrue);
    expect(await a.flushWrittenWatermark(), isTrue);
    expect(a.store.authoredSinceWatermark, isFalse);
    expect(await a.flushWrittenWatermark(), isFalse, reason: 'idempotent when nothing is dirty');
    expect(await a.restoreDb(snapshot), StartupAction.restore);
    expect(a.store.localOrigin, isNot(originAtSnapshot));
  });

  // Efe P4: security rows and revocations are written through the store
  // directly (pairing, removal), not through SyncDevice.write; they must mark
  // the watermark dirty too, so a pair-after-snapshot is covered.
  test('security_writes_after_a_snapshot_are_covered_by_the_watermark', () async {
    final ca = TestClock();
    final a = await newDevice('A', seed: 1, clock: ca);
    final b = await newDevice('B', seed: 2);
    final c = await newDevice('C', seed: 3);
    await SyncDevice.pair(inviter: a, joiner: b);
    createRow(a, 'x', 'sent');
    await runSessionPair(a, b);
    final snapshot = await a.snapshotDb();
    final originAtSnapshot = a.store.localOrigin;
    await SyncDevice.pair(inviter: a, joiner: c); // member/origin/grant rows, written directly
    expect(a.store.authoredSinceWatermark, isTrue, reason: 'pairing wrote security rows');
    expect(await a.restoreDb(snapshot), StartupAction.restore);
    expect(a.store.localOrigin, isNot(originAtSnapshot),
        reason: 'the pairing rows were never sent, so the restore must not re-author their seqs');
  });

  test('restore_never_reuses_hlc_of_unsent_write', () async {
    final ca = TestClock();
    final a = await newDevice('A', seed: 1, clock: ca);
    final b = await newDevice('B', seed: 2, clock: TestClock(baseWall + day));
    await SyncDevice.pair(inviter: a, joiner: b);
    createRow(b, 'x', 'from B');
    await runSessionPair(a, b);
    final earlier = await a.snapshotDb();
    ca.advance(1);
    const title = CellKey('task', 'u', 'title');
    final unsent = a.write(title, 'unsent, remembered by a later snapshot');
    await a.snapshotDb();
    await a.restoreDb(earlier);
    ca.advance(1);
    final afterRestore = a.write(title, 'written after the restore');
    expect(afterRestore.clock, greaterThan(unsent.clock),
        reason: 'the unsent write hlc must be floored by the ledger watermark');
  });

  test('restore_floors_hlc_from_ledger', () async {
    final ca = TestClock();
    final a = await newDevice('A', seed: 1, clock: ca);
    final b = await newDevice('B', seed: 2, clock: TestClock(baseWall + day));
    await SyncDevice.pair(inviter: a, joiner: b);
    createRow(b, 'x', 'from B');
    await runSessionPair(a, b);
    final snapshot = await a.snapshotDb();
    ca.advance(1);
    const title = CellKey('task', 'x', 'title');
    final lost = a.write(title, 'edit lost by restore');
    await runSessionPair(a, b);
    expect(await a.restoreDb(snapshot), StartupAction.restore);
    ca.advance(1);
    final later = a.write(title, 'edit after restore');
    expect(later.clock, greaterThan(lost.clock));
    await syncUntilQuiet([a, b]);
    expect(content(a.store), content(b.store));
    expect(b.store.read(title)?.value, 'edit after restore');
  });

  test('stale_superseded_index_entry_is_dropped_not_a_permanent_stall', () async {
    final [a, b] = [for (var i = 0; i < 2; i++) await newDevice('D$i', seed: 80 + i)];
    await pairAll([a, b]);
    await syncUntilQuiet([a, b]);
    createRow(a, 'live', 'first');
    a.write(const CellKey('task', 'live', 'title'), 'second');
    final own = a.store.localOrigin.hex;
    final (supersededSeq, _) = a.store.nextSupersededOfOrigin(own, 0)!;
    // Point the entry at a key without a cell, as left by a row removed behind the index.
    a.store.debugIndexSuperseded(own, supersededSeq, const CellKey('task', 'gone', 'title'));

    final result = await runSessionPair(a, b);

    expect(result.bothComplete, isTrue, reason: '$result');
    expect(result.initiator.stats.staleSupersededDropped, 1);
    expect(a.store.supersededIndexed, 0, reason: 'the stale entry is healed');
    expect(content(b.store), content(a.store), reason: 'nothing is stalled behind it');
  });

  test('relay_restore_after_cut_resends_superseded', () async {
    // F5 (U11): a relay holds the author's change and its own newer edit of
    // the same cell; a cut keeps the edit from the receiver, then the relay
    // restores a snapshot from before the edit. The author's change must not
    // be lost behind the receiver's cursor.
    const title = CellKey('task', 'f5', 'title');
    const oldChange = 'old change by the author';
    const newerEdit = 'newer edit by the relay';
    var newerEditCut = 0;
    for (var cut = 1; cut <= 60; cut++) {
      final config = testConfig(maxBatchChanges: 2);
      final clocks = [TestClock(), TestClock(), TestClock(baseWall + day)];
      final devices = [
        for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 31 + i, clock: clocks[i], config: config),
      ];
      await pairAll(devices);
      await syncUntilQuiet(devices);
      // The author's origin sorts first, so the relay streams its range
      // (where the edit supersedes the change) before its own origin's.
      final [
        author,
        relay
      ] = [devices[0], devices[1]]..sort((x, y) => x.store.localOrigin.hex.compareTo(y.store.localOrigin.hex));
      final receiver = devices[2];
      createRow(author, 'f5', oldChange);
      // More author cells after the change, so its range fills whole batches.
      createRow(author, 'g1', 'author filler');
      createRow(author, 'g2', 'author filler');
      await runSessionPair(author, relay);
      final beforeEdit = await relay.snapshotDb();
      clocks[devices.indexOf(relay)].advance(10);
      relay.write(title, newerEdit);

      await runSessionPair(relay, receiver, faults: TransportFaults(cutAfter: cut));
      final edit = receiver.store.read(title)?.value;
      await relay.restoreDb(beforeEdit);
      await syncUntilQuiet(devices);

      for (final device in devices) {
        expect(fingerprint(device.store), fingerprint(receiver.store), reason: '${device.name} diverged, cut $cut');
      }
      if (edit == newerEdit) continue;
      newerEditCut++;
      expect(receiver.store.read(title)?.value, oldChange, reason: 'the old change was lost, cut $cut');
    }
    expect(newerEditCut, greaterThan(0), reason: 'some cuts keep the newer edit from the receiver');
  });

  test('same_origin_supersede_beyond_batch_progresses', () async {
    // The author overwrites its own first edit after more winners than one
    // batch holds, so the superseded seq and its winner never share a plain
    // range (F5, 8.1). Streaming must terminate and converge, with cuts and a
    // restore of the author from before the overwrite.
    const title = CellKey('task', 'same', 'title');
    var overwriteCut = 0;
    for (var cut = 1; cut <= 40; cut += 3) {
      final config = testConfig(maxBatchChanges: 2);
      final clocks = [TestClock(), TestClock()];
      final devices = [
        for (var i = 0; i < 2; i++) await newDevice('D$i', seed: 51 + i, clock: clocks[i], config: config),
      ];
      final [author, receiver] = devices;
      await pairAll(devices);
      await syncUntilQuiet(devices);
      author.write(title, 'first edit');
      for (var i = 0; i < 5; i++) {
        author.write(CellKey('task', 'filler$i', 'title'), 'filler');
      }
      final beforeOverwrite = await author.snapshotDb();
      clocks[0].advance(10);
      author.write(title, 'overwrite');

      await runSessionPair(author, receiver, faults: TransportFaults(cutAfter: cut));
      final delivered = receiver.store.read(title)?.value;
      await author.restoreDb(beforeOverwrite);
      expect(await syncUntilQuiet(devices), lessThanOrEqualTo(4), reason: 'cut $cut: does not settle');

      expect(fingerprint(receiver.store), fingerprint(author.store), reason: 'diverged, cut $cut');
      // A delivered overwrite is relayed back to the restored author; an
      // undelivered one is gone, and the first edit must still be there.
      final overwriteDelivered = delivered == 'overwrite';
      if (overwriteDelivered) overwriteCut++;
      expect(receiver.store.read(title)?.value, overwriteDelivered ? 'overwrite' : 'first edit', reason: 'cut $cut');
    }
    expect(overwriteCut, greaterThan(0), reason: 'some cuts deliver the overwrite before the restore');
  });

  test('held_winner_is_never_relayed_as_w', () async {
    // The relay holds a newer, failed-to-apply version of a cell. The winner
    // that travels with an omitted superseded seq is the committed one.
    final clock = TestClock();
    final devices = [
      for (var i = 0; i < 4; i++) await newDevice('H$i', seed: 61 + i, clock: clock),
    ];
    final [first, second, relay, receiver] = devices;
    await pairAll(devices);
    await syncUntilQuiet(devices);
    const key = CellKey('task', 'held', 'title');
    first.write(key, 'v0');
    await runSessionPair(first, relay);
    clock.advance(10);
    second.write(key, 'v1');
    await runSessionPair(second, relay);
    clock.advance(10);
    second.write(key, 'v2');
    relay.store.applyFault = (change) => change.pk == key.pk;
    await runSessionPair(second, relay);
    relay.store.applyFault = null;
    final held = relay.store.heldEnvelopes.single;
    expect(held.reason, HeldReason.applyFailed);
    final committed = relay.store.storedCell(key)!.record;
    expect(committed.value, 'v1');

    final result = await runSessionPair(relay, receiver);
    expect(result.bothComplete, isTrue, reason: '$result');
    final sent = result.initiator.stats.sentVersions;
    expect(sent, contains('${committed.origin}#${committed.originSeq}'), reason: 'the committed winner travels');
    expect(sent.toSet().length, sent.length, reason: 'no version twice');
    // The async engine's writer scans after the receiver's key handover already
    // retried (and applied) the held item, so it may travel as a plain cell.
    expect(result.initiator.stats.heldRelayed, useAsyncEngine ? inInclusiveRange(0, 1) : 1,
        reason: 'the held version goes as a held item only');
    expect(receiver.store.read(key)?.value, 'v2');
  });

  test('manifestless_w_stops_origin_for_session', () async {
    // A winner without a manifest cannot be relayed. With its superseded seq
    // first in line, the origin is given up for the session instead of
    // looping or moving the receiver's cursor past that seq.
    final clock = TestClock();
    final relay = await newDevice('R', seed: 71, clock: clock);
    final receiver = await newDevice('C', seed: 72, clock: clock);
    await SyncDevice.pair(inviter: relay, joiner: receiver);
    final stranger = OriginId(Uint8List(16)..[15] = 7).hex;
    const key = CellKey('task', 'mf', 'title');
    CellRecord version(int seq) =>
        CellRecord(key: key, value: 'v$seq', clock: seq << 16, node: 'm-x', origin: stranger, originSeq: seq);
    relay.store
      ..applyBatch(ChangeBatch(origin: stranger, fromSeq: 0, toSeq: 1, cells: [version(1)]))
      ..applyBatch(ChangeBatch(origin: stranger, fromSeq: 1, toSeq: 2, cells: [version(2)]));
    expect(relay.store.nextSupersededOfOrigin(stranger, 0)?.$1, 1);

    final result = await runSessionPair(relay, receiver);
    expect(result.bothComplete, isTrue, reason: '$result');
    expect(result.initiator.stats.sentVersions.where((v) => v.startsWith(stranger)), isEmpty);
    expect(receiver.store.cursorOf(stranger), 0, reason: 'the cursor never passes the superseded seq');
  });

  test('batch_apply_is_atomic_on_cut', () async {
    // Every batch a side hands to the transport, checked on the other side:
    // batches cut in transit must leave no trace, delivered ones commit whole.
    final outcomes = <bool>{};
    for (var cut = 3; cut <= 60; cut += 3) {
      final (a, b) = await _setupSmallBatches();
      final sentByA = <ChangeBatchMessage>[];
      final sentByB = <ChangeBatchMessage>[];
      await runSessionPair(
        a,
        b,
        faults: TransportFaults(cutAfter: cut),
        hooksA: SessionHooks(outgoingBatch: _recordInto(sentByA)),
        hooksB: SessionHooks(outgoingBatch: _recordInto(sentByB)),
      );
      outcomes
        ..addAll(_expectBatchesAllOrNothing(b.store, sentByA, 'A to B, cut $cut'))
        ..addAll(_expectBatchesAllOrNothing(a.store, sentByB, 'B to A, cut $cut'));
      await syncUntilQuiet([a, b]);
      expect(fingerprint(a.store), fingerprint(b.store), reason: 'diverged after a cut at $cut');
    }
    expect(outcomes, {true, false}, reason: 'some sent batches committed, some were cut before the commit');
  });

  test('batch_apply_is_atomic_on_cut: an item failing inside a batch is held alone (D15)', () async {
    final (a, b) = await _setupSmallBatches();
    const failing = CellKey('task', 'r7', 'title');
    b.store.applyFault = (change) => change.pk == failing.pk && change.col == failing.col;
    final seenByB = <ChangeBatchMessage>[];
    await runSessionPair(a, b, hooksB: SessionHooks(beforeApply: seenByB.add));

    final authorOrigin = a.store.localOrigin.hex;
    final batch =
        seenByB.singleWhere((batch) => batch.envelopes.any((e) => e.pk == failing.pk && e.col == failing.col));
    expect(batch.envelopes.length, greaterThan(1), reason: 'the failing item shares its batch with others');
    final held = b.store.heldEnvelopes.single;
    expect(held.reason, HeldReason.applyFailed);
    expect(held.envelope.pk, failing.pk, reason: 'the failed envelope is kept, not lost');
    expect(b.store.read(failing), isNull, reason: 'the failed item rolled back alone');
    for (final envelope in batch.envelopes.where((e) => e.pk != failing.pk)) {
      expect(b.store.commitLog['${envelope.origin.hex}#${envelope.originSeq}'], 1, reason: 'sibling ${envelope.pk}');
    }
    expect(b.store.cursorOf(authorOrigin), greaterThanOrEqualTo(batch.ranges[batch.ranges.keys.first]!.first.to));
    expect(b.store.cursorOf(authorOrigin), a.store.highestOwnSeq, reason: 'cursor at the declared bound');

    b.store.applyFault = null;
    expect((await runSessionPair(a, b)).bothComplete, isTrue);
    expect(b.store.read(failing)?.value, 'title 7', reason: 'refetched and applied');
    expect(b.store.heldEnvelopes, isEmpty);
  });

  group('data_dir_restore_ledger_current', () {
    test('a data-directory restore trips the startup check and the pair converges', () async {
      final ca = TestClock();
      final a = await newDevice('A', seed: 1, clock: ca);
      final b = await newDevice('B', seed: 2);
      await SyncDevice.pair(inviter: a, joiner: b);
      createRow(a, 'k0', 'before');
      await runSessionPair(a, b);
      final directory = await a.snapshotDirectory();
      ca.advance(10);
      createRow(a, 'e1', 'lost after backup');
      createRow(a, 'e2', 'lost after backup');
      await runSessionPair(a, b);
      expect(await a.restoreDirectory(directory), StartupAction.restore);
      for (var i = 0; i < 6; i++) {
        ca.advance(10);
        createRow(a, 'n$i', 'post-restore');
      }
      await syncUntilQuiet([a, b]);
      expect(fingerprint(a.store), fingerprint(b.store));
      expect(aliveRows(a.store, 'task'), containsAll(['e1', 'e2', 'n0', 'n5']));
    });

    test('with a lagging peer the group still converges and keeps both the lost and the new items', () async {
      final ca = TestClock();
      final a = await newDevice('A', seed: 1, clock: ca);
      final b = await newDevice('B', seed: 2);
      final c = await newDevice('C', seed: 3);
      await pairAll([a, b, c]);
      createRow(a, 'k0', 'before');
      await syncUntilQuiet([a, b, c]);
      final directory = await a.snapshotDirectory();
      ca.advance(10);
      createRow(a, 'lost', 'authored after the backup');
      expect((await runSessionPair(a, b)).bothComplete, isTrue);
      expect(await a.restoreDirectory(directory), StartupAction.restore);
      ca.advance(10);
      createRow(a, 'new', 'authored after the restore');
      expect((await runSessionPair(a, c)).bothComplete, isTrue);
      await syncUntilQuiet([a, b, c]);
      expect({fingerprint(a.store), fingerprint(b.store), fingerprint(c.store)}, hasLength(1));
      for (final d in [a, b, c]) {
        expect(aliveRows(d.store, 'task'), containsAll(['lost', 'new']), reason: d.name);
      }
    });
  });

  group('U11 key epochs and trust anchors', () {
    test('handover_after_key_file_rollback', () async {
      final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 40 + i)];
      await pairAll([a, b, c]);
      await syncUntilQuiet([a, b, c]);
      final beforeRotation = await b.snapshotDirectory();
      await a.removeMember(c.memberId);
      final rotated = a.membership.keyring.highest!;
      createRow(a, 'sealed-under-new-epoch', 'needs the rotated key');
      createRow(b, 'sent-by-b', 'B sent it, so the ledger mark is above its rolled-back DB');
      expect((await runSessionPair(a, b)).bothComplete, isTrue);
      expect(b.membership.keyring.holds(rotated), isTrue);

      expect(await b.restoreDirectory(beforeRotation), StartupAction.restore);
      expect(b.membership.keyring.holds(rotated), isFalse, reason: 'the key file rolled back');
      await syncUntilQuiet([a, b]);

      expect(b.membership.keyring.holds(rotated), isTrue, reason: 'A re-sent the epoch B no longer lists');
      expect(b.store.heldEnvelopes, isEmpty, reason: 'nothing is held missingKey');
      expect(aliveRows(b.store, 'task'), contains('sealed-under-new-epoch'));
      expect(fingerprint(a.store, security: true), fingerprint(b.store, security: true));
    });

    test('rotate_after_rollback_no_epoch_collision', () async {
      final [a, b, c, d] = [for (var i = 0; i < 4; i++) await newDevice('D$i', seed: 50 + i)];
      await pairAll([a, b, c, d]);
      await syncUntilQuiet([a, b, c, d]);
      final beforeRotation = await a.snapshotDirectory();
      await a.removeMember(c.memberId);
      final first = a.membership.keyring.highest!;
      expect(first, EpochId(2, a.memberId));
      expect(a.ledger.epochCounterHigh, 2);
      expect((await runSessionPair(a, b)).bothComplete, isTrue);

      expect(await a.restoreDirectory(beforeRotation), StartupAction.restore);
      expect(a.membership.keyring.highest, EpochId(1, a.memberId), reason: 'the key file rolled back');
      await a.removeMember(d.memberId);

      expect(a.membership.keyring.highest, EpochId(3, a.memberId), reason: 'counter 2 was already created');
      final results = [for (var i = 0; i < 3; i++) await runSessionPair(a, b)];
      for (final r in results) {
        expect(r.bothComplete, isTrue, reason: '$r');
        expect(r.initiator.stats.rejected + r.responder.stats.rejected, 0);
      }
      expect(b.membership.keyring.conflictedEpochs, isEmpty);
      expect(b.membership.keyring.holds(EpochId(3, a.memberId)), isTrue);
      expect(await syncUntilQuiet([a, b]), lessThanOrEqualTo(3));
      expect(fingerprint(a.store, security: true), fingerprint(b.store, security: true));
    });

    test('revoked_anchor_signer_still_verifies', () async {
      final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 60 + i)];
      await SyncDevice.pair(inviter: a, joiner: b);
      createRow(a, 'before-revocation', 'signed by A');
      expect((await runSessionPair(a, b)).bothComplete, isTrue);
      await SyncDevice.pair(inviter: b, joiner: c);
      await b.removeMember(a.memberId);
      // The revocation row reaches C alone; A's own rows (member row, data)
      // are still on the way, and C knows A only through the pairing anchor.
      final revocationPk = b.store.rowsOf(SecurityTables.revocation).single;
      final cell = b.store.storedCell(CellKey(SecurityTables.revocation, revocationPk, CellKey.rowCol))!;
      final change = Change.fromCellRecord(cell.record, groupId: b.membership.groupId!);
      c.store.applyRemote(
        change,
        OriginManifest(
            origin: change.origin, fromSeq: 0, toSeq: change.originSeq, hashes: const [], sig: Uint8List(64)),
        nowMs: baseWall,
      );
      await c.membership.rebuild(c.store);
      expect(c.membership.members, contains(a.memberId));

      final relay = await runSessionPair(b, c);
      expect(relay.bothComplete, isTrue, reason: '$relay');
      expect(c.membership.isExcluded(a.membership.identity.ed25519Pub), isTrue);
      expect(c.store.heldEnvelopes, isEmpty, reason: 'nothing from A is held unverified');
      expect(aliveRows(c.store, 'task'), contains('before-revocation'));
      expect(c.membership.members, contains(a.memberId), reason: 'a revoked signer stays in the directory');

      final refused = await runSessionPair(c, a);
      expect((refused.initiator as SessionFailed).category, SessionFailure.notAuthorized);
    });

    test('db_restore_before_revocation_refuses_revoked_member', () async {
      final [a, b, c] = [for (var i = 0; i < 3; i++) await newDevice('D$i', seed: 70 + i)];
      await pairAll([a, b, c]);
      await syncUntilQuiet([a, b, c]);
      final beforeRemoval = await a.snapshotDb();
      await a.removeMember(c.memberId);
      final rotated = a.membership.keyring.highest!;
      expect((await runSessionPair(a, b)).bothComplete, isTrue);

      await a.restoreDb(beforeRemoval);
      final cPub = c.membership.identity.ed25519Pub;
      expect(a.store.rowsOf(SecurityTables.revocation), isEmpty, reason: 'the DB predates the revocation');
      expect(a.membership.isRevokedEd(cPub), isTrue, reason: 'the ledger keeps the record (U11/Efe-1)');
      expect(a.membership.isExcluded(cPub), isTrue, reason: 'the anchor flag survives');
      expect(a.membership.activeMembers.map((m) => m.memberId), isNot(contains(c.memberId)));

      final attempt = await runSessionPair(c, a);
      expect((attempt.responder as SessionFailed).category, SessionFailure.notAuthorized);
      expect(attempt.responder.stats.keysHandedOver, 0);
      expect(c.membership.keyring.holds(rotated), isFalse);

      expect((await runSessionPair(a, b)).bothComplete, isTrue);
      expect(a.store.rowsOf(SecurityTables.revocation), isNotEmpty, reason: 'the revocation came back from B');
    });
  });
}

/// Two paired devices with many rows on A and one on B, streamed in small
/// batches so that cuts land between and inside batches.
Future<(SyncDevice, SyncDevice)> _setupSmallBatches() async {
  final clock = TestClock();
  final config = testConfig(maxBatchChanges: 5);
  final a = await newDevice('A', seed: 11, clock: clock, config: config);
  final b = await newDevice('B', seed: 12, clock: clock, config: config);
  await SyncDevice.pair(inviter: a, joiner: b);
  for (var i = 0; i < 40; i++) {
    createRow(a, 'r$i', 'title $i');
    clock.advance(1);
  }
  createRow(b, 'b0', 'from B');
  return (a, b);
}

/// An outgoing-batch hook that records each batch into [sent] unchanged.
ChangeBatchMessage Function(ChangeBatchMessage) _recordInto(List<ChangeBatchMessage> sent) => (batch) {
      sent.add(batch);
      return batch;
    };

/// Every batch [seen] by [store] is either fully committed (each envelope
/// applied or held, every range covered by the cursor) or not at all (no
/// envelope stored, cursor below the range end). Returns the outcomes seen:
/// `true` for a committed batch, `false` for one cut before its commit.
Set<bool> _expectBatchesAllOrNothing(SyncStore store, List<ChangeBatchMessage> seen, String reason) {
  final outcomes = <bool>{};
  for (final batch in seen) {
    final committed = [
      for (final e in batch.envelopes)
        store.commitLog.containsKey('${e.origin.hex}#${e.originSeq}') || store.heldAt(e.origin.hex, e.originSeq) != null
    ];
    final covered = [for (final e in batch.ranges.entries) store.cursorOf(e.key.hex) >= e.value.first.to];
    final batchReason = '$reason, batch ${batch.batchId}';
    expect(committed.toSet().length, lessThanOrEqualTo(1), reason: '$batchReason: envelopes partially applied');
    if (committed.isNotEmpty) {
      expect(covered, everyElement(committed.first), reason: '$batchReason: cursor disagrees with the envelopes');
    }
    expect(covered.toSet().length, lessThanOrEqualTo(1), reason: '$batchReason: cursor moved for some origins only');
    outcomes.add(committed.isNotEmpty ? committed.first : covered.first);
  }
  return outcomes;
}

/// A small random run over 3 devices (not the simulator): creates, edits,
/// deletes, cascade deletes, revivals, DB snapshots/restores, replace-imports
/// and faulty sessions; at the end all devices hold identical synced content.
Future<void> _randomRun(int seed) async {
  final rng = Random(seed);
  final clocks = [for (var i = 0; i < 3; i++) TestClock(baseWall + rng.nextInt(2 * day) - day)];
  final devices = [
    for (var i = 0; i < 3; i++)
      await newDevice('D$i', seed: seed * 10 + i, clock: clocks[i], config: testConfig(maxBatchChanges: 30)),
  ];
  await pairAll(devices);
  final rows = <String>[];
  final snapshots = <int, DeviceDbSnapshot>{};
  for (var op = 0; op < 300; op++) {
    for (final c in clocks) {
      c.advance(1 + rng.nextInt(1000));
    }
    final i = rng.nextInt(3);
    final d = devices[i];
    final roll = rng.nextDouble();
    if (roll < 0.25 || rows.isEmpty) {
      rows.add('r${rows.length}');
      createRow(d, rows.last, 't$op');
    } else if (roll < 0.7) {
      d.write(CellKey('task', rows[rng.nextInt(rows.length)], rng.nextBool() ? 'title' : 'note'), 'e$op');
    } else if (roll < 0.8) {
      d.delete(row(rows[rng.nextInt(rows.length)]));
    } else if (roll < 0.85) {
      d.cascadeDelete(row(rows[rng.nextInt(rows.length)]), [row(rows[rng.nextInt(rows.length)])]);
    } else if (roll < 0.9) {
      d.write(CellKey('task', rows[rng.nextInt(rows.length)], CellKey.existenceCol), null);
    } else if (roll < 0.94) {
      snapshots[i] = await d.snapshotDb();
    } else if (roll < 0.96 && snapshots[i] != null) {
      await d.restoreDb(snapshots.remove(i)!);
    } else if (roll < 0.97) {
      await d.replaceImport([for (final pk in rows.take(3)) (CellKey('task', pk, 'title'), 'imported $op')]);
    }
    if (rng.nextDouble() < 0.3) {
      var j = rng.nextInt(2);
      if (j >= i) j++;
      final f = rng.nextDouble();
      final faults = f < 0.1
          ? TransportFaults(cutAfter: 3 + rng.nextInt(30))
          : f < 0.14
              ? TransportFaults(duplicate: {3 + rng.nextInt(20)})
              : f < 0.18
                  ? TransportFaults(reorder: {3 + rng.nextInt(20)})
                  : TransportFaults.none;
      final p = await runSessionPair(d, devices[j], faults: faults);
      for (final side in [p.initiator, p.responder]) {
        expect(side is SessionFailed && side.category == SessionFailure.internal, isFalse, reason: '$side');
        expect(side, isNot(isA<SessionPartial>()), reason: 'seed $seed op $op');
      }
    }
  }
  await syncUntilQuiet(devices);
  expect({for (final d in devices) fingerprint(d.store)}, hasLength(1), reason: 'seed $seed converges');
}
