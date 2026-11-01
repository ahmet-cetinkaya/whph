// T11 acc 1: vendored cacophony and snow Noise vectors against the
// production lib/src/crypto/noise.dart (via the test-only fixed-ephemeral
// entry point). cacophony entries MUST carry and match handshake_hash.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/src/crypto/noise.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'crypto_test_support.dart';

void main() {
  test('vector files contain XX and XXpsk3 for 25519_ChaChaPoly_BLAKE2b', () {
    final cacophony = loadVectors('cacophony_xx.json').map((v) => v['protocol_name']).toList();
    expect(cacophony, containsAll([noiseProtocolXx, noiseProtocolXxPsk3]));
    expect(loadVectors('snow_xx.json').map((v) => v['protocol_name']), contains(noiseProtocolXx));
  });

  for (final file in ['cacophony_xx.json', 'snow_xx.json']) {
    group(file, () {
      for (final v in loadVectors(file)) {
        test(v['protocol_name'] as String, () => _runVector(v, requireHandshakeHash: file.startsWith('cacophony')));
      }
    });
  }
}

Future<void> _runVector(Map<String, dynamic> v, {required bool requireHandshakeHash}) async {
  final protocol = v['protocol_name'] as String;
  if (requireHandshakeHash) {
    expect(v['handshake_hash'], isA<String>(), reason: 'cacophony entries must carry handshake_hash');
  }
  final init = await createNoiseHandshakeForTesting(
    protocolName: protocol,
    initiator: true,
    staticKey: await X25519KeyPair.fromPrivateKey(hex(v['init_static'] as String)),
    ephemeralPrivate: hex(v['init_ephemeral'] as String),
    prologue: hex(v['init_prologue'] as String),
    psks: psksOf(v, 'init'),
  );
  final resp = await createNoiseHandshakeForTesting(
    protocolName: protocol,
    initiator: false,
    staticKey: await X25519KeyPair.fromPrivateKey(hex(v['resp_static'] as String)),
    ephemeralPrivate: hex(v['resp_ephemeral'] as String),
    prologue: hex(v['resp_prologue'] as String),
    psks: psksOf(v, 'resp'),
  );

  NoiseSession? initSession;
  NoiseSession? respSession;
  var handshakeMessages = 0;
  var transportMessages = 0;
  final messages = (v['messages'] as List).cast<Map<String, dynamic>>();
  for (var i = 0; i < messages.length; i++) {
    final payload = hex(messages[i]['payload'] as String);
    final expected = hex(messages[i]['ciphertext'] as String);
    final initiatorSends = i.isEven;
    final Uint8List ciphertext;
    final Uint8List decrypted;
    if (initSession == null) {
      final sender = initiatorSends ? init : resp;
      final receiver = initiatorSends ? resp : init;
      ciphertext = await sender.writeMessage(payload);
      expect(ciphertext, equals(expected), reason: '$protocol handshake message $i');
      decrypted = await receiver.readMessage(ciphertext);
      handshakeMessages++;
      if (init.isComplete && resp.isComplete) {
        expect(init.handshakeHash, equals(resp.handshakeHash));
        if (requireHandshakeHash) {
          expect(toHex(init.handshakeHash), v['handshake_hash'], reason: '$protocol handshake_hash');
        }
        if (psksOf(v, 'init').isNotEmpty) expect(resp.pskVerified, isTrue);
        initSession = init.split();
        respSession = resp.split();
        expect(initSession.handshakeHash, equals(respSession.handshakeHash));
      }
    } else {
      final sender = initiatorSends ? initSession : respSession!;
      final receiver = initiatorSends ? respSession! : initSession;
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
