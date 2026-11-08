// S4 spike: negative tests — flipped byte, wrong static key, replayed
// message, wrong PSK. Every case must reject with NoiseSpikeException.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/spike.dart';

import 'noise_test_support.dart';

const _xx = 'Noise_XX_25519_ChaChaPoly_BLAKE2b';
const _xxPsk3 = 'Noise_XXpsk3_25519_ChaChaPoly_BLAKE2b';

final Matcher _rejects = throwsA(isA<NoiseSpikeException>());

Future<(NoiseTransport, NoiseTransport)> _connected(String protocol, {List<List<int>> psks = const []}) async {
  final pair = await HandshakePair.create(protocol, initPsks: psks);
  await pair.run();
  return (pair.initiator.split(), pair.responder.split());
}

void main() {
  final psk = testKey(9);

  group('flipped byte', () {
    for (final (protocol, psks) in [
      (_xx, const <List<int>>[]),
      (_xxPsk3, [psk]),
    ]) {
      for (var index = 0; index < 3; index++) {
        test('$protocol handshake message $index: every byte position rejects', () async {
          final probe = await HandshakePair.create(protocol, initPsks: psks);
          var length = 0;
          await probe.run(tamper: (i, m) {
            if (i == index) length = m.length;
            return m;
          });
          expect(length, greaterThanOrEqualTo(32 + 2), reason: 'message $index carries at least e or a tagged payload');
          for (var pos = 0; pos < length; pos++) {
            final pair = await HandshakePair.create(protocol, initPsks: psks);
            await expectLater(
              pair.run(tamper: (i, m) => i == index ? (Uint8List.fromList(m)..[pos] ^= 0x01) : m),
              _rejects,
              reason: 'byte $pos',
            );
            expect(pair.initiator.isComplete && pair.responder.isComplete, isFalse);
          }
        });
      }

      test('$protocol transport message: flipped byte rejects and tears the session down', () async {
        final (init, resp) = await _connected(protocol, psks: psks);
        final good = init.encrypt(const [1, 2, 3, 4]);
        final bad = Uint8List.fromList(good)..[0] ^= 0x80;
        expect(() => resp.decrypt(bad), _rejects);
        expect(() => resp.decrypt(good), _rejects, reason: 'session is torn down after first failure');
      });
    }
  });

  group('wrong static key', () {
    test('initiator rejects a responder whose static key is not the expected member key', () async {
      final expected = await x25519Public(testKey(2));
      final pair = await HandshakePair.create(_xx, respStatic: testKey(3), initExpectsRemote: expected);
      await expectLater(pair.run(), _rejects);
      expect(pair.initiator.isComplete, isFalse);
    });

    test('responder rejects an initiator whose static key is not the expected member key', () async {
      final expected = await x25519Public(testKey(1));
      final pair = await HandshakePair.create(_xx, initStatic: testKey(4), respExpectsRemote: expected);
      await expectLater(pair.run(), _rejects);
      expect(pair.responder.isComplete, isFalse);
    });

    test('XXpsk3 initiator rejects an unexpected responder static key even with the right PSK', () async {
      final expected = await x25519Public(testKey(2));
      final pair =
          await HandshakePair.create(_xxPsk3, initPsks: [psk], respStatic: testKey(5), initExpectsRemote: expected);
      await expectLater(pair.run(), _rejects);
    });

    test('matching expected keys succeed (control)', () async {
      final pair = await HandshakePair.create(
        _xx,
        initExpectsRemote: await x25519Public(testKey(2)),
        respExpectsRemote: await x25519Public(testKey(1)),
      );
      await pair.run();
      expect(pair.initiator.isComplete && pair.responder.isComplete, isTrue);
    });
  });

  group('replayed message', () {
    for (final (protocol, psks) in [
      (_xx, const <List<int>>[]),
      (_xxPsk3, [psk]),
    ]) {
      test('$protocol transport replay rejects', () async {
        final (init, resp) = await _connected(protocol, psks: psks);
        final m1 = init.encrypt(const [1]);
        expect(resp.decrypt(m1), equals([1]));
        expect(() => resp.decrypt(m1), _rejects);
      });

      test('$protocol transport reorder rejects', () async {
        final (init, resp) = await _connected(protocol, psks: psks);
        init.encrypt(const [1]);
        final m2 = init.encrypt(const [2]);
        expect(() => resp.decrypt(m2), _rejects);
      });

      test('$protocol handshake message replayed into the same session rejects', () async {
        final pair = await HandshakePair.create(protocol, initPsks: psks);
        final m1 = await pair.initiator.writeMessage(const []);
        await pair.responder.readMessage(m1);
        await expectLater(pair.responder.readMessage(m1), _rejects);
      });

      test('$protocol recorded handshake replayed to a fresh responder rejects', () async {
        // Record a complete, successful session.
        final recorded = <Uint8List>[];
        final original = await HandshakePair.create(protocol, initPsks: psks);
        await original.run(tamper: (i, m) {
          recorded.add(m);
          return m;
        });
        // Replay the initiator's messages 1 and 3 against a new responder.
        final fresh = await HandshakePair.create(protocol, initPsks: psks);
        await fresh.responder.readMessage(recorded[0]);
        await fresh.responder.writeMessage(const []);
        await expectLater(fresh.responder.readMessage(recorded[2]), _rejects);
        expect(fresh.responder.isComplete, isFalse);
      });

      test('$protocol recorded transport message replayed into a new session rejects', () async {
        final (init1, _) = await _connected(protocol, psks: psks);
        final old = init1.encrypt(const [7]);
        final (_, resp2) = await _connected(protocol, psks: psks);
        expect(() => resp2.decrypt(old), _rejects);
      });
    }
  });

  group('wrong PSK', () {
    test('XXpsk3 responder rejects an initiator with a different PSK', () async {
      final pair = await HandshakePair.create(_xxPsk3, initPsks: [testKey(10)], respPsks: [psk]);
      await expectLater(pair.run(), _rejects);
      expect(pair.responder.isComplete, isFalse);
    });

    test('XXpsk3 rejects a PSK differing in a single bit', () async {
      final other = Uint8List.fromList(psk)..[31] ^= 0x01;
      final pair = await HandshakePair.create(_xxPsk3, initPsks: [other], respPsks: [psk]);
      await expectLater(pair.run(), _rejects);
    });

    test('XXpsk3 fails at message 3 (the psk3 token), not earlier', () async {
      final pair = await HandshakePair.create(_xxPsk3, initPsks: [testKey(10)], respPsks: [psk]);
      Object? failedAt;
      try {
        await pair.run(tamper: (i, m) {
          failedAt = i;
          return m;
        });
      } on NoiseSpikeException {
        // expected
      }
      expect(failedAt, 2);
      expect(pair.initiator.isComplete, isTrue, reason: 'initiator cannot tell before the responder answers');
      expect(pair.responder.isComplete, isFalse);
    });

    test('control: matching PSK succeeds', () async {
      final pair = await HandshakePair.create(_xxPsk3, initPsks: [psk]);
      await pair.run();
      expect(pair.initiator.split().handshakeHash, equals(pair.responder.split().handshakeHash));
    });
  });

  group('protocol parsing', () {
    test('rejects unsupported names and psk count mismatch', () async {
      expect(() => parseXxProtocolName('Noise_IK_25519_ChaChaPoly_BLAKE2b'), _rejects);
      expect(() => parseXxProtocolName('Noise_XX_25519_AESGCM_SHA256'), _rejects);
      await expectLater(
        NoiseXxHandshake.create(protocolName: _xxPsk3, initiator: true, staticPrivate: testKey(1)),
        _rejects,
      );
    });
  });
}
