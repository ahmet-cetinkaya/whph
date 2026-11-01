/// Origin manifests: signing input, wire round trip, validation.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/src/model/wire_bytes.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'model_fixtures.dart';

void main() {
  final changes = [goldenChangeWithoutCause(), goldenChangeWithCause()];

  test('lists the hashes of its changes and covers its range', () {
    final m = manifestFor(changes, fromSeq: 41, toSeq: 43);
    expect(m.containsHash(changes[1].canonicalHash()), isTrue);
    expect(m.containsHash(Uint8List(32)), isFalse);
    expect([m.coversSeq(41), m.coversSeq(42), m.coversSeq(43), m.coversSeq(44)], [false, true, true, false]);
  });

  test('signing input binds the group, origin, range and hashes', () {
    final m = manifestFor(changes, fromSeq: 41, toSeq: 43);
    final base = hex(m.signingInput(groupId));
    expect(hex(m.signingInput(GroupId.fromHex('ffeeddccbbaa99887766554433221100'))), isNot(base));
    expect(hex(manifestFor(changes, fromSeq: 40, toSeq: 43).signingInput(groupId)), isNot(base));
    expect(hex(manifestFor(changes.reversed.toList(), fromSeq: 41, toSeq: 43).signingInput(groupId)), isNot(base));
  });

  test('wire form round-trips byte-identically', () {
    final m = manifestFor(changes, fromSeq: 41, toSeq: 43);
    final w = ByteWriter();
    m.writeTo(w);
    final bytes = w.take();
    final r = ByteReader(bytes);
    final back = OriginManifest.readFrom(r);
    r.expectEnd('manifest');
    final w2 = ByteWriter();
    back.writeTo(w2);
    expect(w2.take(), orderedEquals(bytes));
    expect(back.signingInput(groupId), orderedEquals(m.signingInput(groupId)));
  });

  test('rejects invalid ranges, hash counts and signature lengths', () {
    final hashes = [for (final c in changes) c.canonicalHash()];
    final sig = Uint8List(signatureLength);
    expect(
        () => OriginManifest(origin: originA, fromSeq: 5, toSeq: 5, hashes: const [], sig: sig), throwsArgumentError);
    expect(() => OriginManifest(origin: originA, fromSeq: 42, toSeq: 43, hashes: hashes, sig: sig), throwsArgumentError,
        reason: 'two hashes for one seq');
    expect(
        () => OriginManifest(origin: originA, fromSeq: 0, toSeq: 1001, hashes: hashes, sig: sig), throwsArgumentError,
        reason: 'more than 1,000 seqs');
    expect(() => OriginManifest(origin: originA, fromSeq: 0, toSeq: 2, hashes: hashes, sig: Uint8List(63)),
        throwsArgumentError);
    expect(() => OriginManifest(origin: originA, fromSeq: 0, toSeq: 2, hashes: [Uint8List(31)], sig: sig),
        throwsArgumentError);
    expect(OriginManifest(origin: originA, fromSeq: 0, toSeq: 1000, hashes: hashes, sig: sig).toSeq, 1000);
  });

  test('decoding rejects a forged range with typed errors', () {
    final w = ByteWriter()
      ..fixed(originA.bytes)
      ..i64(10)
      ..i64(10)
      ..u32(0)
      ..fixed(Uint8List(signatureLength));
    expect(() => OriginManifest.readFrom(ByteReader(w.take())), throwsA(isA<MalformedMessageException>()));
    final tooMany = ByteWriter()
      ..fixed(originA.bytes)
      ..i64(0)
      ..i64(1000)
      ..u32(1001);
    expect(() => OriginManifest.readFrom(ByteReader(tooMany.take())), throwsA(isA<BatchTooLargeException>()));
  });
}
