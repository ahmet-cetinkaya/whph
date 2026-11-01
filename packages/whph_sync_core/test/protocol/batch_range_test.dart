/// T10 acc. 6: a change batch whose declared range does not cover an
/// included change's seq is rejected as a whole (D15).
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/src/model/wire_bytes.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../model/model_fixtures.dart';
import 'protocol_fixtures.dart';

Change _change(OriginId origin, int seq) => Change(
      groupId: groupId,
      tbl: 'Task',
      pk: 'task-$seq',
      col: 'title',
      value: StringValue('t$seq'),
      hlc: baseHlc + seq,
      node: 'member-a',
      origin: origin,
      originSeq: seq,
    );

/// A batch frame with the given `(origin, range)` entries in this order and no
/// manifests or envelopes.
Uint8List _rangesFrame(List<(OriginId, SeqRange)> entries) {
  final w = ByteWriter()
    ..u8(syncWireFormatVersion)
    ..u8(SyncMessageType.changeBatch.tag)
    ..i64(1)
    ..u32(entries.length);
  for (final (origin, range) in entries) {
    w
      ..fixed(origin.bytes)
      ..i64(range.from)
      ..i64(range.to);
  }
  w
    ..u32(0)
    ..u32(0);
  return w.take();
}

List<SeqRange> _disjointNarrowRanges(int count) => [for (var i = 0; i < count; i++) SeqRange(2 * i, 2 * i + 1)];

void main() {
  test('the range bounds are exclusive below and inclusive above', () {
    final ok = ChangeBatchMessage(
      batchId: 1,
      ranges: {
        originA: [SeqRange(10, 20)]
      },
      envelopes: [sealForTest(_change(originA, 11)), sealForTest(_change(originA, 20))],
    );
    expect(ok.envelopes, hasLength(2));
    for (final seq in [10, 21, 5]) {
      expect(
        () => ChangeBatchMessage(
          batchId: 1,
          ranges: {
            originA: [SeqRange(10, 20)]
          },
          envelopes: [sealForTest(_change(originA, 15)), sealForTest(_change(originA, seq))],
        ),
        throwsA(isA<BatchRangeViolationException>()),
        reason: 'seq $seq',
      );
    }
  });

  test('a change of an origin without a declared range is rejected', () {
    expect(
      () => ChangeBatchMessage(
        batchId: 1,
        ranges: {
          originA: [SeqRange(0, 20)]
        },
        envelopes: [sealForTest(_change(originA, 1)), sealForTest(_change(originB, 1))],
      ),
      throwsA(isA<BatchRangeViolationException>()),
    );
  });

  test('a received frame with an uncovered seq is rejected and nothing is applied', () {
    final store = newStore('member-b');
    final before = storeChecksum(store);
    final frame = rawBatchFrame(
      from: 10,
      to: 20,
      envelopeCount: 2,
      writeEnvelope: (w, i) => writeRawEnvelope(w, pk: 'task-$i', originSeq: i == 0 ? 15 : 21),
    );
    expect(() => receiveFrame(frame, store), throwsA(isA<BatchRangeViolationException>()));
    expect(storeChecksum(store), before);

    final covered = rawBatchFrame(
      from: 0,
      to: 20,
      envelopeCount: 2,
      writeEnvelope: (w, i) => writeRawEnvelope(w, pk: 'task-$i', originSeq: i == 0 ? 15 : 20),
    );
    receiveFrame(covered, store);
    expect(store.cells, hasLength(2));
    expect(store.vector, {originA.hex: 20});
  });

  test('an empty or inverted declared range is malformed', () {
    expect(() => SeqRange(5, 5), throwsArgumentError);
    expect(() => SyncCodec.decode(rawBatchFrame(from: 7, to: 7, envelopeCount: 0)),
        throwsA(isA<MalformedMessageException>()));
    expect(() => SyncCodec.decode(rawBatchFrame(from: 9, to: 3, envelopeCount: 0)),
        throwsA(isA<MalformedMessageException>()));
  });

  test('a range-only batch (all seqs superseded) is valid', () {
    final batch = SyncCodec.decode(rawBatchFrame(from: 0, to: 50, envelopeCount: 0)) as ChangeBatchMessage;
    expect(batch.envelopes, isEmpty);
    expect(batch.ranges, {
      originA: [SeqRange(0, 50)]
    });
  });

  test('batch_ranges_over_cap_rejected', () {
    expect(SyncLimits.maxRangesPerBatch, 2 * SyncLimits.maxBatchChanges);
    final atCap = _disjointNarrowRanges(SyncLimits.maxRangesPerBatch);
    final accepted = ChangeBatchMessage(batchId: 1, ranges: {originA: atCap});
    expect(SyncCodec.decode(SyncCodec.encode(accepted)), isA<ChangeBatchMessage>());

    final overCap = _disjointNarrowRanges(SyncLimits.maxRangesPerBatch + 1);
    expect(() => ChangeBatchMessage(batchId: 1, ranges: {originA: overCap}), throwsA(isA<BatchTooLargeException>()));
    expect(
      () => SyncCodec.decode(_rangesFrame([for (final range in overCap) (originA, range)])),
      throwsA(isA<BatchTooLargeException>()),
    );
  });

  test('overlapping_or_duplicate_ranges_rejected', () {
    final cases = {
      'duplicate': [SeqRange(0, 5), SeqRange(0, 5)],
      'overlap': [SeqRange(0, 5), SeqRange(4, 8)],
      'contained': [SeqRange(0, 10), SeqRange(3, 4)],
    };
    for (final MapEntry(key: name, value: ranges) in cases.entries) {
      expect(
          () => ChangeBatchMessage(batchId: 1, ranges: {originA: ranges}), throwsA(isA<BatchRangeViolationException>()),
          reason: name);
      expect(() => SyncCodec.decode(_rangesFrame([for (final range in ranges) (originA, range)])),
          throwsA(isA<BatchRangeViolationException>()),
          reason: 'decoded $name');
    }
    final adjacent = ChangeBatchMessage(batchId: 1, ranges: {
      originA: [SeqRange(0, 5), SeqRange(5, 8)]
    });
    expect(adjacent.ranges[originA], hasLength(2), reason: 'touching ranges do not overlap');
  });

  test('an origin split into several groups on the wire is malformed', () {
    final frame = _rangesFrame([(originA, SeqRange(0, 1)), (originB, SeqRange(0, 1)), (originA, SeqRange(4, 5))]);
    expect(() => SyncCodec.decode(frame), throwsA(isA<MalformedMessageException>()));
  });

  test('ranges_out_of_order_advance_ascending', () {
    // Written (10,12] first, then (3,5] and (0,3]: only ascending advancing
    // reaches 5, and the narrow range past the gap leaves the cursor alone.
    final frame = _rangesFrame([
      (originA, SeqRange(10, 12)),
      (originA, SeqRange(3, 5)),
      (originA, SeqRange(0, 3)),
    ]);
    final batch = SyncCodec.decode(frame) as ChangeBatchMessage;
    expect(batch.ranges[originA], [SeqRange(0, 3), SeqRange(3, 5), SeqRange(10, 12)]);
    final store = newStore('member-b');
    receiveFrame(frame, store);
    expect(store.vector, {originA.hex: 5});
  });
}
