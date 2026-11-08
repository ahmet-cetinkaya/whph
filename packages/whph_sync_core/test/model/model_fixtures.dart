/// Shared fixtures for the T10 model and protocol tests.
library;

import 'dart:typed_data';

import 'package:whph_sync_core/whph_sync_core.dart';

final groupId = GroupId.fromHex('00112233445566778899aabbccddeeff');
final originA = OriginId.fromHex('0102030405060708090a0b0c0d0e0f10');
final originB = OriginId.fromHex('f0e0d0c0b0a090807060504030201000');
final epoch1 = EpochId(1, 'member-a');

/// 2026-09-20T...Z; any fixed wall works.
final baseHlc = Hlc.pack(1790000000000, 7);

/// The golden change without a cause: a Task title edit.
Change goldenChangeWithoutCause() => Change(
      groupId: groupId,
      tbl: 'Task',
      pk: 'task-1',
      col: 'title',
      value: StringValue('Buy milk'),
      hlc: baseHlc,
      node: 'member-a',
      origin: originA,
      originSeq: 42,
    );

/// The golden change with a cause: a cascaded TaskTag tombstone whose value
/// is the `deleted_date`.
Change goldenChangeWithCause() => Change(
      groupId: groupId,
      tbl: 'TaskTag',
      pk: 'task-tag-1',
      col: CellKey.existenceCol,
      value: const IntValue(1790000000123),
      hlc: baseHlc + 1,
      node: 'member-a',
      origin: originA,
      originSeq: 43,
      cause: const RowRef('Task', 'task-1'),
    );

/// A deterministic manifest over [changes] of one origin (dummy signature).
OriginManifest manifestFor(List<Change> changes, {required int fromSeq, required int toSeq}) => OriginManifest(
      origin: changes.first.origin,
      fromSeq: fromSeq,
      toSeq: toSeq,
      hashes: [for (final c in changes) c.canonicalHash()],
      sig: List<int>.generate(signatureLength, (i) => (i * 7 + 3) & 0xFF),
    );

// --- Test "cipher": identity encryption, deterministic nonce ------------------
//
// Real envelopes are XChaCha20-Poly1305 (T11). These tests only need a
// reversible, deterministic stand-in: ciphertext = value encoding, nonce =
// first 24 bytes of the change hash.

ChangeEnvelope sealForTest(Change change, {EpochId? epoch}) => ChangeEnvelope.forChange(
      change,
      epoch: epoch ?? epoch1,
      nonce: change.canonicalHash().sublist(0, envelopeNonceLength),
      ciphertext: change.value.encode(),
    );

/// Opens every envelope of [batch] before anything is applied; throws a
/// [SyncDecodeException] when any value is malformed or oversized.
List<Change> openForTest(ChangeBatchMessage batch, GroupId group) => [
      for (final e in batch.envelopes) e.toChange(group, ChangeValue.decode(Uint8List.fromList(e.ciphertext))),
    ];

/// The receive pipeline used by the tests: decode the frame, open every
/// envelope, then apply to [store] per declared range. Every decode or open
/// error is thrown before the store is touched (FR-015).
void receiveFrame(Uint8List frame, ReplicaStore store, {GroupId? group}) {
  final message = SyncCodec.decode(frame);
  if (message is! ChangeBatchMessage) throw StateError('expected a change batch, got ${message.type}');
  final changes = openForTest(message, group ?? groupId);
  for (final entry in message.ranges.entries) {
    for (final range in entry.value) {
      store.applyBatch(ChangeBatch(
        origin: entry.key.hex,
        fromSeq: range.from,
        toSeq: range.to,
        cells: [
          for (final c in changes)
            if (c.origin == entry.key && range.contains(c.originSeq)) c.toCellRecord(),
        ],
      ));
    }
  }
}

/// A stable fingerprint of a store's cells and vector.
String storeChecksum(ReplicaStore store) {
  final cells = [for (final c in store.cells) '$c'.replaceAll('\n', r'\n')]..sort();
  final vector = (store.vector.entries.map((e) => '${e.key}=${e.value}').toList()..sort()).join(',');
  return '${cells.join('\n')}\n#$vector';
}

InMemoryReplicaStore newStore(String node) => InMemoryReplicaStore(nodeId: node, policy: HlcMergePolicy());

String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
