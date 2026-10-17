/// T10 acc. 5 (FR-042): changes for an unknown table, column or value type
/// survive decode → store → encode byte-identically.
library;

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../model/model_fixtures.dart';

/// The older receiver's schema: it knows `Task.title` only.
final _olderSchema = MapSyncSchema({
  'Task': {'title'},
});

List<Change> _newerPeerChanges() {
  Change c(String tbl, String pk, String col, ChangeValue value, int seq) => Change(
        groupId: groupId,
        tbl: tbl,
        pk: pk,
        col: col,
        value: value,
        hlc: baseHlc + seq,
        node: 'member-new',
        origin: originB,
        originSeq: seq,
      );
  return [
    c('Task', 'task-1', 'title', StringValue('known'), 1),
    c('Task', 'task-1', 'future_col', StringValue('from a newer schema'), 2),
    c('FutureTable', 'f-1', CellKey.rowCol, BytesValue([1, 2, 3, 0xFF]), 3),
    c('Task', 'task-2', 'title', UnknownValue(9, [0xCA, 0xFE]), 4),
    c('FutureTable', 'f-1', CellKey.existenceCol, const NullValue(), 5),
  ];
}

void main() {
  test('unknown table, column and value type are classified as passthrough', () {
    final reasons = [
      for (final c in _newerPeerChanges())
        switch (classifyChange(c, _olderSchema)) {
          KnownChange() => null,
          PassthroughChange(:final reason) => reason,
        },
    ];
    expect(reasons, [
      null,
      PassthroughReason.unknownColumn,
      PassthroughReason.unknownTable,
      PassthroughReason.unknownValueType,
      PassthroughReason.unknownTable,
    ]);
    expect(passthroughReasonFor(_olderSchema, 'Task', CellKey.existenceCol), isNull);
  });

  test('decode -> store -> encode reproduces the frame and every canonical byte', () {
    final sent = _newerPeerChanges();
    final manifest = manifestFor(sent, fromSeq: 0, toSeq: 5);
    final frame = SyncCodec.encode(ChangeBatchMessage(
      batchId: 5,
      ranges: {originB: SeqRange(0, 5)},
      manifests: [manifest],
      envelopes: [for (final c in sent) sealForTest(c)],
    ));

    // Receive on the older device: decode, open, store.
    final received = SyncCodec.decode(frame) as ChangeBatchMessage;
    final store = newStore('member-old');
    receiveFrame(frame, store);
    expect(store.cells, hasLength(sent.length));

    // Relay from the store: rebuild the changes and re-encode.
    final held = store.changesSince(const {});
    expect(held, hasLength(1));
    final relayedChanges = [for (final r in held.single.cells) Change.fromCellRecord(r, groupId: groupId)];
    for (var i = 0; i < sent.length; i++) {
      expect(relayedChanges[i].canonicalBytes(), orderedEquals(sent[i].canonicalBytes()), reason: '${sent[i]}');
      expect(received.manifests.single.containsHash(relayedChanges[i].canonicalHash()), isTrue,
          reason: 'the relayed change still verifies against the author manifest');
    }
    final relayed = SyncCodec.encode(ChangeBatchMessage(
      batchId: 5,
      ranges: {
        OriginId.fromHex(held.single.origin): SeqRange(held.single.fromSeq, held.single.toSeq),
      },
      manifests: received.manifests,
      envelopes: [for (final c in relayedChanges) sealForTest(c)],
    ));
    expect(relayed, orderedEquals(frame));
  });
}
