/// Store-level tests of the engine's in-memory store (T12 part A): origin
/// switch rules (D6b, D14), held envelopes (D15), snapshots and cursors.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

const _t0 = 1767225600000;

OriginId _origin(int n) => OriginId(List<int>.generate(16, (i) => i == 15 ? n : 0xA0 + n));

SyncStore _store({String member = 'm-a', int origin = 1}) => SyncStore(memberId: member, origin: _origin(origin));

OriginManifest _manifest(OriginId origin, int from, int to) =>
    OriginManifest(origin: origin, fromSeq: from, toSeq: to, hashes: const [], sig: Uint8List(64));

/// Writes [n] own cells (one per row) and returns them.
List<CellRecord> _writeCells(SyncStore s, int n, {int start = 0}) => [
      for (var i = start; i < start + n; i++) s.writeLocal(CellKey('task', 'r$i', 'title'), 'v$i', nowMs: _t0 + i),
    ];

/// Attaches unsigned test manifests covering own seqs `(from, to]` in
/// chunks of 10.
void _manifestOwn(SyncStore s, int from, int to) {
  for (var f = from; f < to; f += 10) {
    s.attachOwnManifest(_manifest(s.localOrigin, f, f + 10 < to ? f + 10 : to));
  }
}

Change _remote(String pk, String col, Object? value,
        {required int hlc, String node = 'm-b', int origin = 2, required int seq, RowRef? cause}) =>
    Change(
      groupId: GroupId(Uint8List(16)),
      tbl: 'task',
      pk: pk,
      col: col,
      value: ChangeValue.of(value),
      hlc: hlc,
      node: node,
      origin: _origin(origin),
      originSeq: seq,
      cause: cause,
    );

ChangeEnvelope _envelope(String pk, {int origin = 2, required int seq, int hlc = 1 << 20, String node = 'm-b'}) =>
    ChangeEnvelope(
      tbl: 'task',
      pk: pk,
      col: 'title',
      hlc: hlc,
      node: node,
      origin: _origin(origin),
      originSeq: seq,
      epoch: EpochId(1, 'm-b'),
      nonce: Uint8List(24),
      ciphertext: Uint8List(20),
    );

void main() {
  group('own sequence and cursors', () {
    test('local writes advance next_seq; the vector reports the own origin at next_seq − 1', () {
      final s = _store();
      _writeCells(s, 3);
      expect(s.nextSeq, 4);
      expect(s.vector, {s.localOrigin.hex: 3});
      expect(() => s.writeLocal(const CellKey('task', 'r', 'title'), 'x', nowMs: _t0, cause: const RowRef('task', 'p')),
          throwsArgumentError,
          reason: 'a cause only on an existence cell');
    });

    test('a peer never advances the own origin', () {
      final s = _store();
      _writeCells(s, 2);
      expect(s.advanceCursor(s.localOrigin.hex, fromSeq: 0, toSeq: 10), isFalse);
      expect(s.cursorOf(s.localOrigin.hex), 2);
    });

    test('applyRemote is idempotent and never lets a stale version win (FR-007, FR-013)', () {
      final s = _store();
      final m = _manifest(_origin(2), 0, 10);
      final newer = _remote('r', 'title', 'new', hlc: 2 << 16, seq: 2);
      final older = _remote('r', 'title', 'old', hlc: 1 << 16, seq: 1);
      expect(s.applyRemote(newer, m, nowMs: _t0), ApplyOutcome.applied);
      expect(s.applyRemote(newer, m, nowMs: _t0), ApplyOutcome.unchanged);
      expect(s.applyRemote(older, m, nowMs: _t0), ApplyOutcome.unchanged);
      expect(s.read(const CellKey('task', 'r', 'title'))?.value, 'new');
      expect(s.hlc, 2 << 16, reason: 'HLC receive');
      s.applyFault = (c) => c.pk == 'z';
      expect(s.applyRemote(_remote('z', 'title', 'x', hlc: 3 << 16, seq: 3), m, nowMs: _t0), ApplyOutcome.failed);
      expect(s.read(const CellKey('task', 'z', 'title')), isNull);
    });
  });

  group('switch_origin (D6b)', () {
    test('restore: mark 40, cells to 50 → 1–40 unchanged, 41–50 adopted, cursor 40', () {
      final s = _store();
      final written = _writeCells(s, 50);
      _manifestOwn(s, 0, 40);
      final o1 = s.localOrigin;
      final before = {for (final c in s.cells) c.originSeq: (c, s.storedCell(c.key)!.manifest)};
      final out = s.switchOrigin(reason: OriginSwitchReason.restore, newOrigin: _origin(9), sentMark: 40);
      expect(out.sealedCursor, 40);
      expect(out.moved, 10);
      expect(s.cursorOf(o1.hex), 40);
      for (final c in written) {
        final now = s.storedCell(c.key)!;
        if (c.originSeq <= 40) {
          expect(identical(now.record, before[c.originSeq]!.$1), isTrue);
          expect(identical(now.manifest, before[c.originSeq]!.$2), isTrue);
        } else {
          expect(now.record.origin, _origin(9).hex);
          expect(now.record.clock, c.clock);
          expect(now.record.node, c.node);
          expect(now.record.value, c.value);
          expect(now.manifest, isNull);
        }
      }
      final later = s.writeLocal(const CellKey('task', 'new', 'title'), 'x', nowMs: _t0 + 100);
      expect(later.origin, _origin(9).hex);
      expect(later.originSeq, 11);
      expect(s.sealedOrigins, {o1.hex});
    });

    test('restore: a DB holding seqs up to 30 adopts nothing and gets cursor 30', () {
      final s = _store();
      _writeCells(s, 30);
      _manifestOwn(s, 0, 30);
      final o1 = s.localOrigin.hex;
      final out = s.switchOrigin(reason: OriginSwitchReason.restore, newOrigin: _origin(9), sentMark: 40);
      expect(out.moved, 0);
      expect(s.cursorOf(o1), 30);
    });

    test('restore adopts every un-manifested sealed cell', () {
      final s = _store();
      final written = _writeCells(s, 40);
      _manifestOwn(s, 0, 35);
      final o1 = s.localOrigin;
      final out = s.switchOrigin(reason: OriginSwitchReason.restore, newOrigin: _origin(9), sentMark: 40);
      expect(out.sealedCursor, 35, reason: 'the highest retained (manifested) seq');
      expect(out.moved, 5, reason: 'seqs 36-40 are at or below the mark but un-manifested');
      for (final c in written.skip(35)) {
        final now = s.storedCell(c.key)!;
        expect(now.record.origin, _origin(9).hex);
        expect(now.record.clock, c.clock);
        expect(now.record.node, c.node);
        expect(now.record.value, c.value);
      }
      expect(s.storedCell(written[34].key)!.record.origin, o1.hex, reason: 'manifested cells stay');
    });

    test('restore raises the HLC to the max held hlc', () {
      final s = _store();
      s.applyRemote(_remote('r', 'title', 'x', hlc: 1 << 40, seq: 1), _manifest(_origin(2), 0, 1), nowMs: _t0);
      final restored = _store()..restore(s.snapshot());
      expect(restored.hlc, 1 << 40);
      restored.switchOrigin(reason: OriginSwitchReason.restore, newOrigin: _origin(9), sentMark: 0);
      expect(restored.hlc, greaterThanOrEqualTo(1 << 40));
    });

    test('restore raises the HLC to the ledger floor above every held hlc', () {
      final s = _store();
      _writeCells(s, 3);
      s.switchOrigin(reason: OriginSwitchReason.restore, newOrigin: _origin(9), sentMark: 3, hlcFloor: 1 << 50);
      expect(s.hlc, greaterThanOrEqualTo(1 << 50));
    });

    test('key_lost with the mark unknown adopts every un-manifested cell', () {
      final s = _store();
      _writeCells(s, 20);
      _manifestOwn(s, 0, 10);
      final out = s.switchOrigin(reason: OriginSwitchReason.keyLost, newOrigin: _origin(9));
      expect(out.sealedCursor, 10);
      expect(out.moved, 10);
    });

    test('local_reset clears user cells, held envelopes and the whole vector; security rows stay', () {
      final s = _store();
      _writeCells(s, 5);
      s.writeLocal(memberCellKey('m-a'), Uint8List(4), nowMs: _t0);
      s.applyRemote(_remote('r', 'title', 'x', hlc: 5 << 16, seq: 1), _manifest(_origin(2), 0, 1), nowMs: _t0);
      s.advanceCursor(_origin(2).hex, fromSeq: 0, toSeq: 1);
      s.putHeld(HeldEnvelope(
        envelope: _envelope('h', seq: 2),
        manifest: _manifest(_origin(2), 0, 2),
        reason: HeldReason.applyFailed,
        recordedAt: _t0,
      ));
      final o1 = s.localOrigin.hex;
      final out = s.switchOrigin(reason: OriginSwitchReason.localReset, newOrigin: _origin(9));
      expect(out.sealedCursor, isNull);
      expect(s.rowsOf('task'), isEmpty);
      expect(s.rowsOf(SecurityTables.member), ['m-a']);
      expect(s.heldEnvelopes, isEmpty);
      expect(s.vector, {_origin(9).hex: 1},
          reason: 'every received cursor cleared, including the sealed one; the never-sent member row was adopted');
      expect(s.cursorOf(o1), 0);
      expect(s.sealedOrigins, {o1});
    });

    test('local_reset keeps a sent security row on the sealed origin (at or below the mark)', () {
      final s = _store();
      s.writeLocal(memberCellKey('m-a'), Uint8List(4), nowMs: _t0);
      _manifestOwn(s, 0, 1);
      _writeCells(s, 2);
      final o1 = s.localOrigin.hex;
      final out = s.switchOrigin(reason: OriginSwitchReason.localReset, newOrigin: _origin(9), sentMark: 1);
      expect(out.moved, 0);
      expect(s.read(memberCellKey('m-a'))!.origin, o1);
      expect(s.rowsOf('task'), isEmpty);
    });

    test('group_switch purges security rows and re-authors every user cell (same hlc/node)', () {
      final s = _store();
      _writeCells(s, 3);
      s.writeLocal(memberCellKey('m-a'), Uint8List(4), nowMs: _t0);
      final foreign = _remote('r9', 'title', 'from D', hlc: 7 << 16, node: 'm-d', seq: 4);
      s.applyRemote(foreign, _manifest(_origin(2), 0, 4), nowMs: _t0);
      s.advanceCursor(_origin(2).hex, fromSeq: 0, toSeq: 4);
      final out = s.switchOrigin(reason: OriginSwitchReason.groupSwitch, newOrigin: _origin(9));
      expect(s.rowsOf(SecurityTables.member), isEmpty);
      expect(s.registrations, isEmpty);
      expect(s.vector, {_origin(9).hex: 4});
      expect(out.moved, 4);
      for (final c in s.cells) {
        expect(c.origin, _origin(9).hex);
      }
      final moved = s.read(const CellKey('task', 'r9', 'title'))!;
      expect((moved.clock, moved.node, moved.value), (foreign.hlc, 'm-d', 'from D'));
    });
  });

  group('held envelopes and snapshots', () {
    test('putHeld keeps the fail count; superseded entries are recognised', () {
      final s = _store();
      final m = _manifest(_origin(2), 0, 5);
      s.putHeld(HeldEnvelope(
        envelope: _envelope('h', seq: 3, hlc: 5 << 16),
        manifest: m,
        reason: HeldReason.applyFailed,
        recordedAt: _t0,
        failCount: 2,
      ));
      s.putHeld(HeldEnvelope(
        envelope: _envelope('h', seq: 3, hlc: 5 << 16),
        manifest: m,
        reason: HeldReason.applyFailed,
        recordedAt: _t0,
      ));
      final held = s.heldAt(_origin(2).hex, 3)!;
      expect(held.failCount, 2);
      expect(s.isSuperseded(held), isFalse);
      s.applyRemote(_remote('h', 'title', 'newer', hlc: 6 << 16, seq: 4), m, nowMs: _t0);
      expect(s.isSuperseded(held), isTrue);
    });

    test('isSuperseded breaks an exact (hlc, node) tie like the merge: origin, then seq', () {
      final s = _store();
      final m3 = _manifest(_origin(3), 0, 5);
      // The stored version is on origin 3; the held one ties on (hlc, node).
      s.applyRemote(_remote('t', 'title', 'stored', hlc: 7 << 16, origin: 3, seq: 2), m3, nowMs: _t0);
      HeldEnvelope held(int origin, int seq) => HeldEnvelope(
            envelope: _envelope('t', origin: origin, seq: seq, hlc: 7 << 16),
            manifest: _manifest(_origin(origin), 0, 5),
            reason: HeldReason.applyFailed,
            recordedAt: _t0,
          );
      expect(s.isSuperseded(held(2, 2)), isFalse, reason: 'a smaller origin wins the tie (compareCellVersions)');
      expect(s.isSuperseded(held(4, 2)), isTrue, reason: 'a larger origin loses the tie');
      expect(s.isSuperseded(held(3, 1)), isTrue, reason: 'same origin, lower seq');
      expect(s.isSuperseded(held(3, 2)), isTrue, reason: 'the identical version');
      expect(s.isSuperseded(held(3, 3)), isFalse, reason: 'same origin, higher seq wins');
    });

    test('a snapshot is independent of later writes; restore replaces the whole state', () {
      final s = _store();
      _writeCells(s, 3);
      final snap = s.snapshot();
      _writeCells(s, 3, start: 3);
      expect(s.cellCount, 6);
      s.restore(snap);
      expect(s.cellCount, 3);
      expect(s.nextSeq, 4);
      _writeCells(s, 1, start: 10);
      expect(snap.nextSeq, 4);
    });
  });

  group('InMemoryReplicaStore (T9 carry-over)', () {
    test('isRowAlive is cascade-aware and writeLocal accepts a cause on the existence cell', () {
      final s = InMemoryReplicaStore(nodeId: 'a', policy: HlcMergePolicy());
      const p = RowRef('task', 'p');
      s
        ..writeLocal(const CellKey('task', 'p', 'title'), 'parent', nowMs: 1)
        ..writeLocal(const CellKey('task', 'c', 'title'), 'child', nowMs: 1)
        ..writeLocal(const CellKey('task', 'p', CellKey.existenceCol), 2, nowMs: 2)
        ..writeLocal(const CellKey('task', 'c', CellKey.existenceCol), 2, nowMs: 2, cause: p);
      expect(s.isRowAlive('task', 'c'), isFalse);
      s.writeLocal(const CellKey('task', 'p', 'title'), 'later edit', nowMs: 3);
      expect(s.isRowAlive('task', 'p'), isTrue);
      expect(s.isRowAlive('task', 'c'), isTrue, reason: 'the cause is alive again');
      expect(s.read(const CellKey('task', 'c', CellKey.existenceCol))!.cause, p);
      expect(() => s.writeLocal(const CellKey('task', 'c', 'title'), 'x', nowMs: 4, cause: p), throwsArgumentError);
    });
  });

  group('sync ledger', () {
    test('sent-mark writes can be failed on demand and snapshots are independent', () async {
      final f = InMemorySyncLedger();
      await f.append(
          OriginEntry(origin: _origin(1), state: OriginEntryState.committed, reason: OriginSwitchReason.initial));
      f.failNextSentMarkWrites = 1;
      await expectLater(f.persistSentMark(_origin(1), 5, 50), throwsA(isA<SyncLedgerWriteException>()));
      await f.persistSentMark(_origin(1), 5, 50);
      expect(f.entryOf(_origin(1))!.maxSentSeq, 5);
      expect(f.entryOf(_origin(1))!.hlcHigh, 50);
      expect(f.hlcFloor, 50);
      final snap = f.snapshot();
      await f.persistSentMark(_origin(1), 9, 90);
      expect(snap.entryOf(_origin(1))!.maxSentSeq, 5);
      await f.deleteAll();
      expect(f.isReadable, isFalse);
      expect(f.entries, isEmpty);
    });
  });
}
