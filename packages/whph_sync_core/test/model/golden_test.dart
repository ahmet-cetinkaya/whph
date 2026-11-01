/// T10 acc. 2: canonical change, manifest and envelope-AD encodings match the
/// golden files in `test/golden/` byte for byte.
///
/// Regenerate (only for an intentional, versioned format change):
/// `WHPH_UPDATE_GOLDEN=1 fvm dart test test/model/golden_test.dart`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'model_fixtures.dart';

final _update = Platform.environment['WHPH_UPDATE_GOLDEN'] == '1';

void _expectGolden(String name, Uint8List actual) {
  final file = File('test/golden/$name');
  if (_update) {
    file.writeAsBytesSync(actual, flush: true);
    return;
  }
  expect(file.existsSync(), isTrue, reason: 'missing golden $name');
  expect(actual, orderedEquals(file.readAsBytesSync()), reason: 'golden $name differs');
}

void _expectGoldenText(String name, String actual) => _expectGolden(name, Uint8List.fromList(actual.codeUnits));

void main() {
  test('BLAKE2b-256 matches the RFC 7693 reference for the empty input', () {
    expect(hex(blake2b256(const [])), '0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8');
  });

  test('canonical change without a cause matches its golden file', () {
    _expectGolden('change_without_cause.bin', goldenChangeWithoutCause().canonicalBytes());
  });

  test('canonical change with a cause matches its golden file', () {
    _expectGolden('change_with_cause.bin', goldenChangeWithCause().canonicalBytes());
  });

  test('change hashes match the golden list', () {
    _expectGoldenText(
      'change_hashes.txt',
      'change_without_cause.bin ${hex(goldenChangeWithoutCause().canonicalHash())}\n'
          'change_with_cause.bin ${hex(goldenChangeWithCause().canonicalHash())}\n',
    );
  });

  test('manifest signing input matches its golden file', () {
    final manifest = manifestFor([goldenChangeWithoutCause(), goldenChangeWithCause()], fromSeq: 41, toSeq: 43);
    _expectGolden('manifest_signing_input.bin', manifest.signingInput(groupId));
  });

  test('envelope associated data (with a cause) matches its golden file', () {
    final envelope = sealForTest(goldenChangeWithCause());
    _expectGolden('envelope_ad_with_cause.bin', envelope.associatedData(groupId: groupId, protocolVersion: 2));
  });

  test('golden files decode back to the fixtures', () {
    if (_update) return;
    for (final (name, change) in [
      ('change_without_cause.bin', goldenChangeWithoutCause()),
      ('change_with_cause.bin', goldenChangeWithCause()),
    ]) {
      expect(Change.fromCanonicalBytes(File('test/golden/$name').readAsBytesSync()), change);
    }
  });
}
