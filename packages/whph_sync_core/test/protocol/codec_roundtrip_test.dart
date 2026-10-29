/// T10 acc. 1: every message type round-trips through the binary codec.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../model/model_fixtures.dart';

Hello _hello({int version = 2, int min = 2, String member = 'member-a', String name = 'Laptop'}) => Hello(
      protocolVersion: version,
      minCompatible: min,
      appVersion: '0.21.0+93',
      memberId: member,
      deviceName: name,
      wallMs: 1790000000000,
    );

/// One populated instance of every message type.
Map<SyncMessageType, SyncMessage> sampleMessages() {
  final changes = [goldenChangeWithoutCause(), goldenChangeWithCause()];
  return {
    SyncMessageType.hello: _hello(),
    SyncMessageType.helloAck: HelloAck(hello: _hello(version: 3, min: 2, member: 'member-b'), agreedVersion: 2),
    SyncMessageType.updateRequired: const UpdateRequired(memberId: 'member-b', deviceName: 'Old phone'),
    SyncMessageType.busy: const Busy(),
    SyncMessageType.error: ErrorMessage(SyncErrorCategory.storageError),
    SyncMessageType.originRegistry: OriginRegistry([
      OriginRegistration(
        origin: originA,
        memberPub: List.filled(32, 0xA1),
        createdHlc: baseHlc,
        sig: List.filled(64, 0x51),
      ),
      OriginRegistration(
        origin: originB,
        memberPub: List.filled(32, 0xB2),
        createdHlc: baseHlc + 5,
        sig: List.filled(64, 0x52),
      ),
    ]),
    SyncMessageType.keyHandover: KeyHandover([
      EpochKeyGrant(epoch: epoch1, key: List.filled(32, 0x11)),
      EpochKeyGrant(epoch: EpochId(2, 'member-b'), key: List.filled(32, 0x22)),
    ]),
    SyncMessageType.vectorExchange: VectorExchange(
      vector: {originB: 7, originA: 43},
      refetch: const [CellKey('Task', 'task-9', 'title'), CellKey('Note', 'n-1', '~')],
      heldEpochs: [EpochId(2, 'member-b'), epoch1],
    ),
    SyncMessageType.changeBatch: ChangeBatchMessage(
      batchId: 12,
      ranges: {
        originA: [SeqRange(41, 43)],
        originB: [SeqRange(0, 5)]
      },
      manifests: [manifestFor(changes, fromSeq: 41, toSeq: 43)],
      envelopes: [
        for (final c in changes) sealForTest(c),
        ChangeEnvelope.forChange(
          Change(
            groupId: groupId,
            tbl: 'Tag',
            pk: 'tag-1',
            col: 'name',
            value: StringValue('home'),
            hlc: baseHlc,
            node: 'member-b',
            origin: originB,
            originSeq: 5,
          ),
          epoch: EpochId(2, 'member-b'),
          nonce: List.filled(24, 9),
          ciphertext: [1, 2, 3],
          keyWrap: [0xEE],
        ),
      ],
    ),
    SyncMessageType.batchAck: BatchAck(12),
  };
}

void main() {
  final samples = sampleMessages();

  test('the samples cover every message type', () {
    expect(samples.keys.toSet(), SyncMessageType.values.toSet());
  });

  for (final entry in samples.entries) {
    test('${entry.key.name} round-trips byte-identically', () {
      final frame = SyncCodec.encode(entry.value);
      expect(frame[0], syncWireFormatVersion);
      expect(frame[1], entry.key.tag);
      final decoded = SyncCodec.decode(frame);
      expect(decoded.type, entry.key);
      expect(decoded.runtimeType, entry.value.runtimeType);
      expect(SyncCodec.encode(decoded), orderedEquals(frame));
    });
  }

  test('decoded fields equal the originals', () {
    final hello = SyncCodec.decode(SyncCodec.encode(samples[SyncMessageType.hello]!)) as Hello;
    expect(
        [hello.protocolVersion, hello.minCompatible, hello.appVersion, hello.memberId, hello.deviceName, hello.wallMs],
        [2, 2, '0.21.0+93', 'member-a', 'Laptop', 1790000000000]);

    final ack = SyncCodec.decode(SyncCodec.encode(samples[SyncMessageType.helloAck]!)) as HelloAck;
    expect([ack.hello.protocolVersion, ack.hello.memberId, ack.agreedVersion], [3, 'member-b', 2]);

    final error = SyncCodec.decode(SyncCodec.encode(samples[SyncMessageType.error]!)) as ErrorMessage;
    expect(error.category, SyncErrorCategory.storageError);
    final unknownError = SyncCodec.decode(SyncCodec.encode(ErrorMessage.fromCode(999))) as ErrorMessage;
    expect([unknownError.code, unknownError.category], [999, null]);

    final vector = SyncCodec.decode(SyncCodec.encode(samples[SyncMessageType.vectorExchange]!)) as VectorExchange;
    expect(vector.vector, {originA: 43, originB: 7});
    expect(vector.vector.keys.first, originA, reason: 'maps are encoded in ascending origin order');
    expect(vector.refetch, const [CellKey('Task', 'task-9', 'title'), CellKey('Note', 'n-1', '~')]);
    expect(vector.heldEpochs, [epoch1, EpochId(2, 'member-b')], reason: 'epoch ids are encoded ascending');

    final batch = SyncCodec.decode(SyncCodec.encode(samples[SyncMessageType.changeBatch]!)) as ChangeBatchMessage;
    expect(batch.batchId, 12);
    expect(batch.ranges, {
      originA: [SeqRange(41, 43)],
      originB: [SeqRange(0, 5)]
    });
    expect(
      [for (final e in batch.envelopes.take(2)) e.toChange(groupId, ChangeValue.decode(e.ciphertext))],
      [goldenChangeWithoutCause(), goldenChangeWithCause()],
    );
    expect(batch.envelopes[1].cause, const RowRef('Task', 'task-1'));
    expect(batch.envelopes[2].keyWrap, [0xEE]);
    expect(batch.manifests.single.containsHash(goldenChangeWithCause().canonicalHash()), isTrue);

    final handover = SyncCodec.decode(SyncCodec.encode(samples[SyncMessageType.keyHandover]!)) as KeyHandover;
    expect(handover.grants.map((g) => g.epoch), [epoch1, EpochId(2, 'member-b')]);
    expect(handover.grants.last.key, List.filled(32, 0x22));
    expect('$handover ${handover.grants.first}', isNot(contains('17')), reason: 'no key bytes in toString');

    expect((SyncCodec.decode(SyncCodec.encode(BatchAck(77))) as BatchAck).batchId, 77);
  });

  test('a standalone envelope round-trips (held-envelope storage)', () {
    final envelope = sealForTest(goldenChangeWithCause());
    final bytes = envelope.encode();
    expect(ChangeEnvelope.decode(bytes).encode(), orderedEquals(bytes));
    expect(ChangeEnvelope.decode(Uint8List.fromList(bytes)).toString(), isNot(contains('1790000000123')));
  });
}
