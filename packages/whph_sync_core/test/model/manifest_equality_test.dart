import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

OriginManifest _manifest({int fromSeq = 0, int sigByte = 7}) => OriginManifest(
      origin: OriginId(Uint8List(Id128.length)),
      fromSeq: fromSeq,
      toSeq: fromSeq + 2,
      hashes: [Uint8List(changeHashLength), Uint8List(changeHashLength)],
      sig: Uint8List(64)..[0] = sigByte,
    );

void main() {
  test('two copies of one authored manifest are equal, so a batch carries it once', () {
    expect(_manifest(), _manifest());
    expect({_manifest(), _manifest()}, hasLength(1));
  });

  test('a different range or signature is a different manifest', () {
    expect(_manifest(), isNot(_manifest(fromSeq: 2)));
    expect(_manifest(), isNot(_manifest(sigByte: 8)));
  });
}
