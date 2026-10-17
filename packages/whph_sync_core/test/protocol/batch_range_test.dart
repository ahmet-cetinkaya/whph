/// T10 acc. 6: a change batch whose declared range does not cover an
/// included change's seq is rejected as a whole (D15).
library;

import 'package:test/test.dart';
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

void main() {
  test('the range bounds are exclusive below and inclusive above', () {
    final ok = ChangeBatchMessage(
      batchId: 1,
      ranges: {originA: SeqRange(10, 20)},
      envelopes: [sealForTest(_change(originA, 11)), sealForTest(_change(originA, 20))],
    );
    expect(ok.envelopes, hasLength(2));
    for (final seq in [10, 21, 5]) {
      expect(
        () => ChangeBatchMessage(
          batchId: 1,
          ranges: {originA: SeqRange(10, 20)},
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
        ranges: {originA: SeqRange(0, 20)},
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
    expect(batch.ranges, {originA: SeqRange(0, 50)});
  });
}
