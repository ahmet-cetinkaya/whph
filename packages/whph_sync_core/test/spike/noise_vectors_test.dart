// S4 spike: Noise XX / XXpsk3 (25519_ChaChaPoly_BLAKE2b) against vendored
// cacophony and snow vectors (see test/vectors/README.md).
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/spike.dart';

import 'noise_test_support.dart';

const _xx = 'Noise_XX_25519_ChaChaPoly_BLAKE2b';
const _xxPsk3 = 'Noise_XXpsk3_25519_ChaChaPoly_BLAKE2b';

void main() {
  group('vendored vector files', () {
    test('cacophony contains XX and XXpsk3 for 25519_ChaChaPoly_BLAKE2b', () {
      final names = loadVectors('cacophony_xx.json').map((v) => v['protocol_name']).toList();
      expect(names, contains(_xx));
      expect(names, contains(_xxPsk3));
    });

    test('snow contains XX for 25519_ChaChaPoly_BLAKE2b', () {
      final names = loadVectors('snow_xx.json').map((v) => v['protocol_name']).toList();
      expect(names, contains(_xx));
    });
  });

  for (final file in ['cacophony_xx.json', 'snow_xx.json']) {
    group(file, () {
      for (final v in loadVectors(file)) {
        test(v['protocol_name'] as String, () => _runVector(v));
      }
    });
  }
}

Future<void> _runVector(Map<String, dynamic> v) async {
  final protocol = v['protocol_name'] as String;
  final init = await NoiseXxHandshake.create(
    protocolName: protocol,
    initiator: true,
    staticPrivate: hex(v['init_static'] as String),
    ephemeralPrivate: hex(v['init_ephemeral'] as String),
    prologue: hex(v['init_prologue'] as String),
    psks: psksOf(v, 'init'),
  );
  final resp = await NoiseXxHandshake.create(
    protocolName: protocol,
    initiator: false,
    staticPrivate: hex(v['resp_static'] as String),
    ephemeralPrivate: hex(v['resp_ephemeral'] as String),
    prologue: hex(v['resp_prologue'] as String),
    psks: psksOf(v, 'resp'),
  );

  NoiseTransport? initTransport;
  NoiseTransport? respTransport;
  var handshakeMessages = 0;
  var transportMessages = 0;
  final messages = (v['messages'] as List).cast<Map<String, dynamic>>();
  for (var i = 0; i < messages.length; i++) {
    final payload = hex(messages[i]['payload'] as String);
    final expected = hex(messages[i]['ciphertext'] as String);
    final initiatorSends = i.isEven;
    final Uint8List ciphertext;
    final Uint8List decrypted;
    if (!init.isComplete || !resp.isComplete) {
      final sender = initiatorSends ? init : resp;
      final receiver = initiatorSends ? resp : init;
      ciphertext = await sender.writeMessage(payload);
      expect(ciphertext, equals(expected), reason: '$protocol handshake message $i');
      decrypted = await receiver.readMessage(ciphertext);
      handshakeMessages++;
      if (init.isComplete && resp.isComplete) {
        expect(init.handshakeHash, equals(resp.handshakeHash));
        if (v['handshake_hash'] != null) {
          expect(init.handshakeHash, equals(hex(v['handshake_hash'] as String)), reason: '$protocol handshake_hash');
        }
        initTransport = init.split();
        respTransport = resp.split();
      }
    } else {
      final sender = initiatorSends ? initTransport! : respTransport!;
      final receiver = initiatorSends ? respTransport! : initTransport!;
      ciphertext = sender.encrypt(payload);
      expect(ciphertext, equals(expected), reason: '$protocol transport message $i');
      decrypted = receiver.decrypt(ciphertext);
      transportMessages++;
    }
    expect(decrypted, equals(payload));
  }
  expect(handshakeMessages, 3);
  expect(transportMessages, greaterThan(0));
}
