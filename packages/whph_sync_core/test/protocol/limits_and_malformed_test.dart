/// T10 acc. 3 (FR-015): oversized frames, values and batches and malformed
/// messages are rejected with typed errors before anything reaches the store.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/src/model/wire_bytes.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../model/model_fixtures.dart';
import 'protocol_fixtures.dart';

void main() {
  late InMemoryReplicaStore store;
  late String before;

  setUp(() {
    // A store that already holds data, so "untouched" is meaningful.
    store = newStore('member-b');
    final changes = [goldenChangeWithoutCause(), goldenChangeWithCause()];
    receiveFrame(
      SyncCodec.encode(ChangeBatchMessage(
        batchId: 1,
        ranges: {
          originA: [SeqRange(41, 43)]
        },
        manifests: [manifestFor(changes, fromSeq: 41, toSeq: 43)],
        envelopes: [for (final c in changes) sealForTest(c)],
      )),
      store,
    );
    // Cursor starts at 0, so (41, 43] is not contiguous: cells stored, cursor unchanged.
    expect(store.cells, hasLength(2));
    before = storeChecksum(store);
  });

  void expectRejected<T extends SyncDecodeException>(Uint8List frame) {
    expect(() => receiveFrame(frame, store), throwsA(isA<T>()));
    expect(storeChecksum(store), before, reason: 'the store must be untouched');
  }

  Uint8List validBatch({List<ChangeEnvelope>? envelopes}) => SyncCodec.encode(ChangeBatchMessage(
        batchId: 2,
        ranges: {
          originA: [SeqRange(0, 10)]
        },
        envelopes: envelopes ??
            [
              for (var seq = 1; seq <= 3; seq++)
                sealForTest(Change(
                  groupId: groupId,
                  tbl: 'Task',
                  pk: 'task-$seq',
                  col: 'title',
                  value: StringValue('t$seq'),
                  hlc: baseHlc + 100 + seq,
                  node: 'member-a',
                  origin: originA,
                  originSeq: seq,
                )),
            ],
      ));

  test('control: a valid batch is applied', () {
    receiveFrame(validBatch(), store);
    expect(storeChecksum(store), isNot(before));
    expect(store.vector, {originA.hex: 10});
  });

  group('limits', () {
    test('a frame above 8 MiB is rejected before parsing', () {
      final frame = Uint8List(SyncLimits.maxFrameBytes + 1)
        ..[0] = syncWireFormatVersion
        ..[1] = SyncMessageType.changeBatch.tag;
      expectRejected<FrameTooLargeException>(frame);
    });

    test('encoding a message above 8 MiB fails with the same typed error', () {
      final big = List<int>.filled(SyncLimits.maxEnvelopeCiphertextBytes, 1);
      final message = ChangeBatchMessage(
        batchId: 3,
        ranges: {
          originA: [SeqRange(0, 4)]
        },
        envelopes: [
          for (var seq = 1; seq <= 4; seq++)
            ChangeEnvelope(
              tbl: 'Note',
              pk: 'n-$seq',
              col: 'content',
              hlc: baseHlc,
              node: 'member-a',
              origin: originA,
              originSeq: seq,
              epoch: epoch1,
              nonce: Uint8List(24),
              ciphertext: big,
            ),
        ],
      );
      expect(() => SyncCodec.encode(message), throwsA(isA<FrameTooLargeException>()));
    });

    test('an envelope ciphertext above the value limit is rejected', () {
      final frame = rawBatchFrame(
        writeEnvelope: (w, _) => writeRawEnvelope(w, ciphertext: Uint8List(SyncLimits.maxEnvelopeCiphertextBytes + 1)),
      );
      expectRejected<ValueTooLargeException>(frame);
    });

    test('a forged ciphertext length above the value limit is rejected before reading it', () {
      final frame = rawBatchFrame(
        writeEnvelope: (w, _) =>
            writeRawEnvelope(w, ciphertextLengthOverride: SyncLimits.maxEnvelopeCiphertextBytes + 1),
      );
      expectRejected<ValueTooLargeException>(frame);
    });

    test('a decrypted value above 2 MiB is rejected and nothing of the batch is applied', () {
      final huge = (ByteWriter()
            ..u8(ChangeValue.tagBytes)
            ..bytes(Uint8List(SyncLimits.maxValueBytes + 1)))
          .take();
      expect(huge.length, lessThanOrEqualTo(SyncLimits.maxEnvelopeCiphertextBytes));
      final frame = rawBatchFrame(
        envelopeCount: 2,
        writeEnvelope: (w, i) =>
            i == 0 ? writeRawEnvelope(w, originSeq: 1) : writeRawEnvelope(w, originSeq: 2, ciphertext: huge),
      );
      expectRejected<ValueTooLargeException>(frame);
    });

    test('a batch of 1,001 changes is rejected; 1,000 is accepted', () {
      expectRejected<BatchTooLargeException>(rawBatchFrame(to: 2000, envelopeCount: 1001));
      expect(SyncCodec.decode(rawBatchFrame(to: 2000, envelopeCount: 1000)), isA<ChangeBatchMessage>());
      expect(
        () => ChangeBatchMessage(
          batchId: 0,
          ranges: {
            originA: [SeqRange(0, 2000)]
          },
          envelopes: [
            for (var seq = 1; seq <= 1001; seq++)
              sealForTest(Change(
                groupId: groupId,
                tbl: 'T',
                pk: 'p$seq',
                col: 'c',
                value: const NullValue(),
                hlc: baseHlc,
                node: 'n',
                origin: originA,
                originSeq: seq,
              )),
          ],
        ),
        throwsA(isA<BatchTooLargeException>()),
      );
    });

    test('a forged huge element count is rejected without allocating', () {
      expectRejected<BatchTooLargeException>(rawBatchFrame(envelopeCount: 0, declaredEnvelopeCount: 0xFFFFFFFF));
      final w = ByteWriter()
        ..u8(syncWireFormatVersion)
        ..u8(SyncMessageType.vectorExchange.tag)
        ..u32(0xFFFFFFFF);
      expectRejected<TruncatedMessageException>(w.take());
    });
  });

  group('malformed', () {
    test('truncated frames at every length are rejected', () {
      final frame = validBatch();
      for (var n = 0; n < frame.length; n++) {
        expectRejected<SyncDecodeException>(Uint8List.sublistView(frame, 0, n));
      }
    });

    test('trailing bytes are rejected', () {
      expectRejected<MalformedMessageException>(Uint8List.fromList([...validBatch(), 0]));
    });

    test('an unknown wire format or message type is rejected', () {
      final frame = validBatch();
      expectRejected<UnsupportedWireFormatException>(Uint8List.fromList(frame)..[0] = 2);
      expectRejected<UnknownMessageTypeException>(Uint8List.fromList(frame)..[1] = 200);
    });

    test('the retired full-resync tags 11 and 12 are unknown (U10)', () {
      final frame = validBatch();
      expectRejected<UnknownMessageTypeException>(Uint8List.fromList(frame)..[1] = 11);
      expectRejected<UnknownMessageTypeException>(Uint8List.fromList(frame)..[1] = 12);
    });

    test('a VectorExchange in the old layout with a gc_floor map is rejected (U10)', () {
      final valid = SyncCodec.encode(VectorExchange(vector: {originA: 3}));
      expect(SyncCodec.decode(valid), isA<VectorExchange>());
      // Old body: vector, gc_floor (empty map count), refetch count.
      expectRejected<MalformedMessageException>(Uint8List.fromList([...valid, 0, 0, 0, 0]));
      expectRejected<SyncDecodeException>(Uint8List.fromList([...valid, 0, 0, 0, 0, 0, 0, 0, 0]));
    });

    test('a VectorExchange carries its held epoch ids, strictly ascending', () {
      Uint8List frame(List<EpochId> epochs) {
        final w = ByteWriter()
          ..u8(syncWireFormatVersion)
          ..u8(SyncMessageType.vectorExchange.tag)
          ..u32(0) // vector
          ..u32(0) // refetch
          ..u32(epochs.length);
        for (final e in epochs) {
          w
            ..i64(e.counter)
            ..string(e.creator);
        }
        return w.take();
      }

      final low = EpochId(1, 'a');
      final high = EpochId(2, 'a');
      expect((SyncCodec.decode(frame([low, high])) as VectorExchange).heldEpochs, [low, high]);
      expectRejected<MalformedMessageException>(frame([high, low]));
      expectRejected<MalformedMessageException>(frame([low, low]));
      expectRejected<SyncDecodeException>(Uint8List.fromList([
        ...frame([low]),
        0
      ]));
    });

    test('an unrepresentable HLC is rejected', () {
      expectRejected<MalformedMessageException>(
        rawBatchFrame(writeEnvelope: (w, _) => writeRawEnvelope(w, hlc: Hlc.wallLimitMs << Hlc.counterBits)),
      );
      expectRejected<MalformedMessageException>(rawBatchFrame(writeEnvelope: (w, _) => writeRawEnvelope(w, hlc: -1)));
    });

    test('invalid UTF-8, empty names, seq 0 and epoch 0 are rejected', () {
      final badUtf8 = rawBatchFrame(writeEnvelope: (w, _) {
        final tmp = ByteWriter();
        writeRawEnvelope(tmp, tbl: 'Tasé');
        final bytes = tmp.take();
        final i = bytes.indexOf(0xC3);
        bytes[i] = 0xC0; // overlong lead byte
        w.fixed(bytes);
      });
      expectRejected<MalformedMessageException>(badUtf8);
      expectRejected<MalformedMessageException>(rawBatchFrame(writeEnvelope: (w, _) => writeRawEnvelope(w, col: '')));
      expectRejected<MalformedMessageException>(
          rawBatchFrame(writeEnvelope: (w, _) => writeRawEnvelope(w, originSeq: 0)));
      expectRejected<MalformedMessageException>(
          rawBatchFrame(writeEnvelope: (w, _) => writeRawEnvelope(w, epochCounter: 0)));
    });

    test('M1: epoch counters above 2^53 and protocol_version 0 are rejected', () {
      const max = EpochId.maxCounter;
      expect(EpochId(max, 'm').counter, max);
      expect(() => EpochId(max + 1, 'm'), throwsArgumentError);
      // Envelope inside a batch, and a standalone (held) envelope.
      for (final c in [max + 1, 0x7fffffffffffffff]) {
        expectRejected<MalformedMessageException>(
            rawBatchFrame(writeEnvelope: (w, _) => writeRawEnvelope(w, epochCounter: c)));
        final w = ByteWriter();
        writeRawEnvelope(w, epochCounter: c);
        expect(() => ChangeEnvelope.decode(w.take()), throwsA(isA<MalformedMessageException>()));
      }
      final ok = ByteWriter();
      writeRawEnvelope(ok, epochCounter: max);
      expect(ChangeEnvelope.decode(ok.take()).epoch.counter, max);
      expectRejected<MalformedMessageException>(
          rawBatchFrame(writeEnvelope: (w, _) => writeRawEnvelope(w, protocolVersion: 0)));
      // Key handover.
      Uint8List handover(int counter) => (ByteWriter()
            ..u8(syncWireFormatVersion)
            ..u8(SyncMessageType.keyHandover.tag)
            ..u32(1)
            ..i64(counter)
            ..string('member-x')
            ..fixed(Uint8List(32)))
          .take();
      expect((SyncCodec.decode(handover(max)) as KeyHandover).grants.single.epoch.counter, max);
      expectRejected<MalformedMessageException>(handover(max + 1));
      expectRejected<MalformedMessageException>(handover(0x7fffffffffffffff));
    });

    test('a malformed decrypted value rejects the whole batch', () {
      final frame = rawBatchFrame(
        envelopeCount: 2,
        writeEnvelope: (w, i) =>
            writeRawEnvelope(w, originSeq: i + 1, ciphertext: i == 0 ? null : [ChangeValue.tagInt, 0, 0, 0, 1, 7]),
      );
      expectRejected<MalformedMessageException>(frame);
    });

    test('unsorted or duplicate map keys are rejected', () {
      Uint8List vectorFrame(List<OriginId> origins) {
        final w = ByteWriter()
          ..u8(syncWireFormatVersion)
          ..u8(SyncMessageType.vectorExchange.tag)
          ..u32(origins.length);
        for (final o in origins) {
          w
            ..fixed(o.bytes)
            ..i64(1);
        }
        w
          ..u32(0) // refetch
          ..u32(0); // held epochs
        return w.take();
      }

      expect(SyncCodec.decode(vectorFrame([originA, originB])), isA<VectorExchange>());
      expect(() => SyncCodec.decode(vectorFrame([originB, originA])), throwsA(isA<MalformedMessageException>()));
      expect(() => SyncCodec.decode(vectorFrame([originA, originA])), throwsA(isA<MalformedMessageException>()));
    });

    test('duplicate (origin, seq) in one batch is rejected', () {
      expectRejected<MalformedMessageException>(
        rawBatchFrame(envelopeCount: 2, writeEnvelope: (w, i) => writeRawEnvelope(w, originSeq: 5, pk: 'p$i')),
      );
    });

    test('a Hello with min_compatible above its version is rejected', () {
      final w = ByteWriter()
        ..u8(syncWireFormatVersion)
        ..u8(SyncMessageType.hello.tag)
        ..u32(2)
        ..u32(3)
        ..string('1.0')
        ..string('m')
        ..string('d')
        ..i64(0);
      expect(() => SyncCodec.decode(w.take()), throwsA(isA<MalformedMessageException>()));
    });

    test('random corruption only ever yields typed errors and leaves the store untouched', () {
      final rng = Random(20260927);
      final frame = validBatch();
      var rejected = 0;
      for (var i = 0; i < 3000; i++) {
        final mutated = Uint8List.fromList(frame);
        final flips = 1 + rng.nextInt(3);
        for (var f = 0; f < flips; f++) {
          mutated[rng.nextInt(mutated.length)] = rng.nextInt(256);
        }
        final probe = newStore('probe');
        final probeBefore = storeChecksum(probe);
        try {
          receiveFrame(mutated, probe);
        } on SyncDecodeException {
          rejected++;
          expect(storeChecksum(probe), probeBefore);
        }
      }
      expect(rejected, greaterThan(0));
    });
  });
}
