// T11 acc 1 + S4 carry-forwards: tampered, truncated, MAC-flipped,
// reflected, replayed, reordered, wrong-static, wrong-PSK and
// prologue-mismatch messages reject; 65535-byte limit; low-order points;
// teardown on any exception; key state cleared after split.
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/src/crypto/noise.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'crypto_test_support.dart';

final _token = Uint8List.fromList(List.generate(16, (i) => i * 3));

Uint8List _flip(Uint8List m, int index, [int mask = 0x01]) => Uint8List.fromList(m)..[index] ^= mask;

Matcher get _rejects => throwsA(isA<SyncCryptoException>());

/// Asserts that every entry point of a torn-down handshake throws.
Future<void> _expectTornDown(NoiseHandshake hs) async {
  expect(hs.hasFailed, isTrue);
  expect(hs.isComplete, isFalse);
  await expectLater(hs.writeMessage(), throwsA(isA<NoiseException>()));
  await expectLater(hs.readMessage(Uint8List(64)), throwsA(isA<NoiseException>()));
  expect(() => hs.split(), throwsA(isA<NoiseException>()));
  expect(() => hs.handshakeHash, throwsA(isA<NoiseException>()));
}

void main() {
  group('control', () {
    test('XX completes, transports both ways, same handshake hash', () async {
      final pair = await NoisePair.xx();
      final (a, b) = await pair.runAndSplit();
      expect(a.handshakeHash, b.handshakeHash);
      expect(b.decrypt(a.encrypt([1, 2, 3])), [1, 2, 3]);
      expect(a.decrypt(b.encrypt([4])), [4]);
      expect(a.remoteStatic, (await testStatic(2)).publicKey);
      expect(b.remoteStatic, (await testStatic(1)).publicKey);
    });

    test('XXpsk3 completes with matching token and fingerprint', () async {
      final pair = await NoisePair.xxPsk3(initToken: _token);
      await pair.run();
      expect(pair.responder.pskVerified, isTrue);
      expect(pair.initiator.isComplete, isTrue);
    });
  });

  for (final psk in [false, true]) {
    final name = psk ? 'XXpsk3' : 'XX';
    Future<NoisePair> make() => psk ? NoisePair.xxPsk3(initToken: _token) : NoisePair.xx();

    group('$name handshake tampering', () {
      test('every byte flip of every handshake message rejects', () async {
        final lengths = <int>[];
        final probe = await make();
        await probe.run(tamper: (i, m) {
          lengths.add(m.length);
          return m;
        });
        for (var msg = 0; msg < 3; msg++) {
          for (var byte = 0; byte < lengths[msg]; byte++) {
            final pair = await make();
            // Message 1 flips alter `e`; they surface at message 2 or 3.
            await expectLater(pair.run(tamper: (i, m) => i == msg ? _flip(m, byte) : m), _rejects,
                reason: 'message $msg byte $byte');
            expect(pair.initiator.isComplete && pair.responder.isComplete, isFalse);
          }
        }
      });

      test('truncation of each message rejects', () async {
        for (var msg = 0; msg < 3; msg++) {
          for (final cut in [1, 16, 17]) {
            final pair = await make();
            await expectLater(
                pair.run(tamper: (i, m) => i == msg ? Uint8List.sublistView(m, 0, m.length - cut) : m), _rejects,
                reason: 'message $msg cut $cut');
          }
          final pair = await make();
          await expectLater(pair.run(tamper: (i, m) => i == msg ? Uint8List(0) : m), _rejects);
        }
      });

      test('MAC tag flip (last byte) of messages 2 and 3 rejects at the receiver', () async {
        for (final msg in [1, 2]) {
          final pair = await make();
          await expectLater(pair.run(tamper: (i, m) => i == msg ? _flip(m, m.length - 1, 0x80) : m), _rejects);
          final receiver = msg == 1 ? pair.initiator : pair.responder;
          await _expectTornDown(receiver);
        }
      });

      test('reflection: a handshake message fed back to its sender rejects', () async {
        final pair = await make();
        final m1 = await pair.initiator.writeMessage();
        await expectLater(pair.initiator.readMessage(m1), _rejects);
        await _expectTornDown(pair.initiator);

        final pair2 = await make();
        await pair2.responder.readMessage(await pair2.initiator.writeMessage());
        final m2 = await pair2.responder.writeMessage();
        await expectLater(pair2.responder.readMessage(m2), _rejects);
        await _expectTornDown(pair2.responder);
      });

      test('replay: a handshake message fed twice into one session rejects', () async {
        final pair = await make();
        final m1 = await pair.initiator.writeMessage();
        await pair.responder.readMessage(m1);
        await expectLater(pair.responder.readMessage(m1), _rejects);
        await _expectTornDown(pair.responder);
      });

      test('replay: recorded messages 1 and 3 replayed to a fresh responder fail at message 3', () async {
        final recorded = <Uint8List>[];
        final original = await make();
        await original.run(tamper: (i, m) {
          recorded.add(m);
          return m;
        });
        final fresh = await make();
        await fresh.responder.readMessage(recorded[0]);
        await fresh.responder.writeMessage();
        await expectLater(fresh.responder.readMessage(recorded[2]), _rejects);
        expect(fresh.responder.pskVerified, isFalse);
      });

      test('reorder: message 3 before message 2 rejects', () async {
        final pair = await make();
        await pair.responder.readMessage(await pair.initiator.writeMessage());
        await expectLater(pair.initiator.writeMessage(), _rejects);
      });

      test('prologue mismatch rejects (XX at message 2, XXpsk3 already at message 1)', () async {
        final pair = psk
            ? NoisePair(
                await NoiseHandshake.xxPsk3(
                  initiator: true,
                  staticKey: await testStatic(1),
                  psk: derivePairingPsk(_token),
                  expectedResponderFingerprint: x25519Fingerprint((await testStatic(2)).publicKey),
                  prologue: [1],
                ),
                await NoiseHandshake.xxPsk3(
                    initiator: false, staticKey: await testStatic(2), psk: derivePairingPsk(_token), prologue: [2]),
              )
            : await NoisePair.xx(initPrologue: [1], respPrologue: [2]);
        final m1 = await pair.initiator.writeMessage();
        if (psk) {
          // psk mode keys the message-1 payload from `e`, so h already differs.
          await expectLater(pair.responder.readMessage(m1), _rejects);
          return;
        }
        await pair.responder.readMessage(m1);
        await expectLater(pair.initiator.readMessage(await pair.responder.writeMessage()), _rejects);
      });

      // In psk mode message 1 carries an encrypted (empty) payload, so a bare
      // 32-byte forged `e` already fails as truncated; XX shows the DH check.
      if (!psk)
        test('low-order ephemeral in message 1 aborts the responder (all-zero DH)', () async {
          final pair = await make();
          final lowOrder = hex('e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800');
          await pair.responder.readMessage(lowOrder);
          await expectLater(pair.responder.writeMessage(), throwsA(isA<LowOrderPointException>()));
          await _expectTornDown(pair.responder);
        });

      test('low-order ephemeral in message 2 aborts the initiator (all-zero DH)', () async {
        final pair = await make();
        await pair.responder.readMessage(await pair.initiator.writeMessage());
        final m2 = await pair.responder.writeMessage();
        final forged = Uint8List.fromList(m2)..setRange(0, 32, Uint8List(32));
        await expectLater(pair.initiator.readMessage(forged), throwsA(isA<LowOrderPointException>()));
        await _expectTornDown(pair.initiator);
      });
    });
  }

  group('static keys', () {
    test('XX initiator rejecting the responder key fails at message 2 and never writes message 3', () async {
      final pair = await NoisePair.xx(initAccepts: (_) => false);
      await pair.responder.readMessage(await pair.initiator.writeMessage());
      await expectLater(pair.initiator.readMessage(await pair.responder.writeMessage()), _rejects);
      await _expectTornDown(pair.initiator);
    });

    test('XX responder rejecting the initiator key fails at message 3', () async {
      final expected = (await testStatic(7)).publicKey;
      final pair = await NoisePair.xx(respAccepts: (rs) => rs.toString() == expected.toString());
      await expectLater(pair.run(), _rejects);
      await _expectTornDown(pair.responder);
    });

    test('XXpsk3 scanner with a wrong QR fingerprint fails before writing message 3', () async {
      final pair = await NoisePair.xxPsk3(initToken: _token, expectSeed: 9);
      await pair.responder.readMessage(await pair.initiator.writeMessage());
      await expectLater(pair.initiator.readMessage(await pair.responder.writeMessage()), _rejects);
      await _expectTornDown(pair.initiator);
    });

    test('XXpsk3 scanner must supply a fingerprint; responder must not', () async {
      await expectLater(
        NoiseHandshake.xxPsk3(initiator: true, staticKey: await testStatic(1), psk: testKey(1)),
        throwsA(isA<NoiseException>()),
      );
      await expectLater(
        NoiseHandshake.xxPsk3(
            initiator: false,
            staticKey: await testStatic(1),
            psk: testKey(1),
            expectedResponderFingerprint: testKey(2)),
        throwsA(isA<NoiseException>()),
      );
    });
  });

  group('wrong PSK', () {
    for (final (label, other) in [
      ('different token', Uint8List.fromList(List.generate(16, (i) => 200 - i))),
      ('single-bit different token', _flip(_token, 5)),
    ]) {
      test('$label rejects at message 3, not earlier', () async {
        final pair = await NoisePair.xxPsk3(initToken: _token, respToken: other);
        await pair.responder.readMessage(await pair.initiator.writeMessage());
        await pair.initiator.readMessage(await pair.responder.writeMessage());
        final m3 = await pair.initiator.writeMessage([1]);
        await expectLater(pair.responder.readMessage(m3), _rejects);
        expect(pair.responder.pskVerified, isFalse);
        await _expectTornDown(pair.responder);
      });
    }
  });

  group('early payloads (messages 1-2 carry nothing)', () {
    test('writing a payload in message 1 or 2 is refused', () async {
      final pair = await NoisePair.xx();
      await expectLater(pair.initiator.writeMessage([1]), throwsA(isA<NoiseException>()));
      final pair2 = await NoisePair.xxPsk3(initToken: _token);
      await pair2.responder.readMessage(await pair2.initiator.writeMessage());
      await expectLater(pair2.responder.writeMessage([1]), throwsA(isA<NoiseException>()));
    });

    test('reading a message 1 that carries a payload rejects', () async {
      final sender = await createNoiseHandshakeForTesting(
        protocolName: noiseProtocolXx,
        initiator: true,
        staticKey: await testStatic(1),
        prologue: const [],
      );
      final receiver = await NoiseHandshake.xx(
          initiator: false, staticKey: await testStatic(2), acceptRemoteStatic: acceptAll, prologue: const []);
      await expectLater(receiver.readMessage(await sender.writeMessage([9])), throwsA(isA<NoiseException>()));
    });
  });

  group('65535-byte message limit', () {
    test('handshake write refuses a message above 65535 bytes', () async {
      final pair = await NoisePair.xx();
      await pair.responder.readMessage(await pair.initiator.writeMessage());
      await pair.initiator.readMessage(await pair.responder.writeMessage());
      // Message 3 = 48 (s) + payload + 16.
      await expectLater(pair.initiator.writeMessage(Uint8List(65535 - 48 - 16 + 1)), throwsA(isA<NoiseException>()));
      await _expectTornDown(pair.initiator);
    });

    test('handshake write accepts exactly 65535 bytes', () async {
      final pair = await NoisePair.xx();
      await pair.responder.readMessage(await pair.initiator.writeMessage());
      await pair.initiator.readMessage(await pair.responder.writeMessage());
      final m3 = await pair.initiator.writeMessage(Uint8List(65535 - 48 - 16));
      expect(m3.length, 65535);
      await pair.responder.readMessage(m3);
    });

    test('handshake read rejects a message above 65535 bytes', () async {
      final pair = await NoisePair.xx();
      await expectLater(pair.responder.readMessage(Uint8List(65536)), throwsA(isA<NoiseException>()));
      await _expectTornDown(pair.responder);
    });

    test('transport enforces the limit on encrypt and decrypt and tears down', () async {
      final (a, b) = await (await NoisePair.xx()).runAndSplit();
      final max = a.encrypt(Uint8List(noiseMaxTransportPayload));
      expect(max.length, noiseMaxMessageLength);
      expect(b.decrypt(max).length, noiseMaxTransportPayload);
      expect(() => a.encrypt(Uint8List(noiseMaxTransportPayload + 1)), throwsA(isA<NoiseException>()));
      expect(a.isClosed, isTrue);
      expect(() => b.decrypt(Uint8List(noiseMaxMessageLength + 1)), throwsA(isA<NoiseException>()));
      expect(b.isClosed, isTrue);
    });
  });

  group('transport', () {
    test('tampered byte and flipped MAC tag reject and tear the session down', () async {
      for (final index in [0, 5, 20]) {
        final (a, b) = await (await NoisePair.xx()).runAndSplit();
        final good = a.encrypt(List.filled(5, 7));
        expect(() => b.decrypt(_flip(good, index)), throwsA(isA<NoiseException>()));
        expect(b.isClosed, isTrue);
        expect(() => b.decrypt(good), throwsA(isA<NoiseException>()), reason: 'torn down');
        expect(() => b.encrypt([1]), throwsA(isA<NoiseException>()), reason: 'torn down');
      }
    });

    test('truncated transport message rejects', () async {
      final (a, b) = await (await NoisePair.xx()).runAndSplit();
      final m = a.encrypt([1, 2, 3]);
      expect(() => b.decrypt(m.sublist(0, m.length - 1)), throwsA(isA<NoiseException>()));
      final (c, d) = await (await NoisePair.xx()).runAndSplit();
      c.encrypt([1]);
      expect(() => d.decrypt(Uint8List(15)), throwsA(isA<NoiseException>()));
    });

    test('replay and reorder reject', () async {
      final (a, b) = await (await NoisePair.xx()).runAndSplit();
      final m1 = a.encrypt([1]);
      b.decrypt(m1);
      expect(() => b.decrypt(m1), throwsA(isA<NoiseException>()));

      final (c, d) = await (await NoisePair.xx()).runAndSplit();
      c.encrypt([1]);
      final second = c.encrypt([2]);
      expect(() => d.decrypt(second), throwsA(isA<NoiseException>()));
    });

    test('reflection: own transport message fed back to the sender rejects', () async {
      final (a, _) = await (await NoisePair.xx()).runAndSplit();
      final m = a.encrypt([1, 2]);
      expect(() => a.decrypt(m), throwsA(isA<NoiseException>()));
      expect(a.isClosed, isTrue);
    });

    test('a recorded transport message rejects in another session', () async {
      final (a, _) = await (await NoisePair.xx()).runAndSplit();
      final recorded = a.encrypt([1]);
      final (_, d) = await (await NoisePair.xx()).runAndSplit();
      expect(() => d.decrypt(recorded), throwsA(isA<NoiseException>()));
    });
  });

  group('key hygiene', () {
    test('split clears handshake state; static key stays owned by the caller', () async {
      final static = await testStatic(1);
      final init = await NoiseHandshake.xx(initiator: true, staticKey: static, acceptRemoteStatic: acceptAll);
      final resp =
          await NoiseHandshake.xx(initiator: false, staticKey: await testStatic(2), acceptRemoteStatic: acceptAll);
      await resp.readMessage(await init.writeMessage());
      await init.readMessage(await resp.writeMessage());
      await resp.readMessage(await init.writeMessage());
      final session = init.split();
      expect(() => init.handshakeHash, throwsA(isA<NoiseException>()));
      expect(() => init.split(), throwsA(isA<NoiseException>()));
      expect(static.isDestroyed, isFalse);
      session.close();
      expect(() => session.encrypt([1]), throwsA(isA<NoiseException>()));
      expect(() => session.handshakeHash, throwsA(isA<NoiseException>()));
    });

    test('L6: reentrant writeMessage tears the handshake down (both calls fail)', () async {
      final hs =
          await NoiseHandshake.xx(initiator: true, staticKey: await testStatic(1), acceptRemoteStatic: acceptAll);
      final first = hs.writeMessage(); // suspended while generating the ephemeral
      await expectLater(hs.writeMessage(), throwsA(isA<NoiseException>()));
      await expectLater(first, throwsA(isA<NoiseException>()));
      expect(hs.hasFailed, isTrue);
      await expectLater(hs.writeMessage(), throwsA(isA<NoiseException>()));
    });

    test('L6: a read or close during a pending write tears the handshake down', () async {
      final hs =
          await NoiseHandshake.xx(initiator: true, staticKey: await testStatic(1), acceptRemoteStatic: acceptAll);
      final pending = hs.writeMessage();
      await expectLater(hs.readMessage(Uint8List(32)), throwsA(isA<NoiseException>()));
      await expectLater(pending, throwsA(isA<NoiseException>()));

      final hs2 =
          await NoiseHandshake.xx(initiator: true, staticKey: await testStatic(1), acceptRemoteStatic: acceptAll);
      final pending2 = hs2.writeMessage();
      hs2.close();
      await expectLater(pending2, throwsA(isA<NoiseException>()));
    });

    test('L6: sequential calls are unaffected by the busy flag', () async {
      final pair = await NoisePair.xx();
      await pair.run();
      expect(pair.initiator.isComplete && pair.responder.isComplete, isTrue);
    });

    test('close() abandons a handshake', () async {
      final pair = await NoisePair.xx();
      await pair.initiator.writeMessage();
      pair.initiator.close();
      await _expectTornDown(pair.initiator);
    });

    test('callers PSK copy is not retained (zeroing the handshake does not touch it)', () async {
      final psk = derivePairingPsk(_token);
      final copy = Uint8List.fromList(psk);
      final hs = await NoiseHandshake.xxPsk3(initiator: false, staticKey: await testStatic(2), psk: psk);
      hs.close();
      expect(psk, copy);
    });
  });

  group('source rules', () {
    test('production crypto code never imports spike code nor uses cryptography HMAC/HKDF', () {
      for (final f in Directory('lib/src/crypto').listSync().whereType<File>()) {
        // Code only; the doc comments explain why the library HMAC is avoided.
        final src = f.readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');
        expect(src, isNot(contains('spike')), reason: f.path);
        expect(src, isNot(contains('Hmac.blake2')), reason: f.path);
        expect(src, isNot(contains(RegExp(r'\bHkdf\('))), reason: f.path);
      }
    });

    test('L8: test-only hooks are hidden from the export and never referenced by production code', () {
      final export = File('lib/whph_sync_core.dart').readAsStringSync();
      expect(export, contains('hide createNoiseHandshakeForTesting'));
      expect(export, contains('hide createSasInitiatorForTesting, createSasResponderForTesting'));
      const hooks = {
        'createNoiseHandshakeForTesting': 'crypto/noise.dart',
        'createSasInitiatorForTesting': 'crypto/sas.dart',
        'createSasResponderForTesting': 'crypto/sas.dart',
      };
      // The package's lib/ and the app's lib/ (../../src/lib).
      final app = Directory('../../src/lib');
      expect(app.existsSync(), isTrue, reason: 'app source tree not found at ${app.path}');
      var scanned = 0;
      for (final root in [Directory('lib'), app]) {
        for (final f in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
          scanned++;
          final src = f.readAsStringSync();
          for (final MapEntry(key: hook, value: home) in hooks.entries) {
            if (f.path.endsWith(home) || f.path.endsWith('lib/whph_sync_core.dart')) continue;
            expect(src, isNot(contains(hook)), reason: '${f.path} references $hook');
          }
        }
      }
      expect(scanned, greaterThan(100));
    });
  });
}
