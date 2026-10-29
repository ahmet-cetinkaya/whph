/// Raw frame builders for negative protocol tests: they write bytes directly,
/// bypassing the validating constructors, to model a hostile or buggy peer.
library;

import 'dart:typed_data';

import 'package:whph_sync_core/src/model/wire_bytes.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../model/model_fixtures.dart';

/// Writes one envelope field by field.
void writeRawEnvelope(
  ByteWriter w, {
  String tbl = 'Task',
  String pk = 'task-1',
  String col = 'title',
  int? hlc,
  String node = 'member-a',
  OriginId? origin,
  int originSeq = 1,
  int epochCounter = 1,
  int protocolVersion = 2,
  List<int>? ciphertext,
  int? ciphertextLengthOverride,
}) {
  final body = ciphertext ?? StringValue('x').encode();
  w
    ..string(tbl)
    ..string(pk)
    ..string(col)
    ..i64(hlc ?? baseHlc)
    ..string(node)
    ..fixed((origin ?? originA).bytes)
    ..i64(originSeq)
    ..u8(0)
    ..i64(epochCounter)
    ..string('member-a')
    ..u32(protocolVersion)
    ..fixed(Uint8List(envelopeNonceLength))
    ..u32(ciphertextLengthOverride ?? body.length)
    ..fixed(body)
    ..u32(0);
}

/// A change-batch frame with one declared range for [origin] and the given
/// envelopes (each written by [writeEnvelope]).
Uint8List rawBatchFrame({
  OriginId? origin,
  int from = 0,
  int to = 10,
  int envelopeCount = 1,
  int? declaredEnvelopeCount,
  void Function(ByteWriter w, int index)? writeEnvelope,
}) {
  final w = ByteWriter()
    ..u8(syncWireFormatVersion)
    ..u8(SyncMessageType.changeBatch.tag)
    ..i64(1)
    ..u32(1)
    ..fixed((origin ?? originA).bytes)
    ..i64(from)
    ..i64(to)
    ..u32(0)
    ..u32(declaredEnvelopeCount ?? envelopeCount);
  for (var i = 0; i < envelopeCount; i++) {
    (writeEnvelope ?? (w, i) => writeRawEnvelope(w, originSeq: i + 1))(w, i);
  }
  return w.take();
}
