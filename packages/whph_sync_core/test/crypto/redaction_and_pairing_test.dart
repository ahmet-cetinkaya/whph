// T11: no toString prints key, token, nonce or SAS bytes; the pairing token
// is consumed only by a handshake that passed the psk3 check.
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'crypto_test_support.dart';

/// Every textual form a byte secret could leak in.
List<String> _forms(List<int> secret) => [
      toHex(secret),
      toHex(secret).toUpperCase(),
      base64.encode(secret),
      secret.take(6).join(', '),
    ];

void _expectRedacted(Object o, List<int> secret) {
  final s = o.toString();
  for (final f in _forms(secret)) {
    expect(s, isNot(contains(f)), reason: '${o.runtimeType}.toString leaks secret bytes');
  }
}

void main() {
  group('toString never prints secrets', () {
    test('key pairs', () async {
      final x = await X25519KeyPair.fromPrivateKey(testKey(1));
      _expectRedacted(x, testKey(1));
      final e = await Ed25519KeyPair.fromSeed(testKey(2));
      _expectRedacted(e, testKey(2));
      expect('$x $e', contains('redacted'));
    });

    test('keyring, handover grants and nonce source', () {
      final k = GroupKeyring()..add(EpochId(1, 'a'), testKey(3));
      _expectRedacted(k, testKey(3));
      final (grants, _) = k.handoverTo(peerPub: testKey(9), peerHas: const {}, peerIsRevoked: false);
      _expectRedacted(grants.single, testKey(3));
      _expectRedacted(KeyHandover(grants), testKey(3));
      final n = NonceSource();
      _expectRedacted(n, n.next().sublist(0, 16));
    });

    test('Noise handshake, session and failures', () async {
      final pair = await NoisePair.xxPsk3(initToken: Uint8List(16));
      await pair.run();
      _expectRedacted(pair.initiator, derivePairingPsk(Uint8List(16)));
      final s = pair.initiator.split();
      _expectRedacted(s, testKey(1));
      expect(s.toString(), isNot(contains(toHex(s.handshakeHash))));
      try {
        s.decrypt(Uint8List(40));
        fail('should reject');
      } on NoiseException catch (e) {
        _expectRedacted(e, testKey(1));
        expect(e.message, 'authentication failed');
      }
    });

    test('SAS objects never print the code or nonces', () {
      final h = testKey(40);
      final a = SasInitiator(h);
      final b = SasResponder(h);
      final commit = b.start().single as SasCommit;
      final nonce = a.receive(commit).single as SasNonce;
      final reveal = b.receive(nonce).single as SasReveal;
      a.receive(reveal);
      final code = a.code!;
      for (final o in [a, b, commit, nonce, reveal]) {
        expect(o.toString(), isNot(contains(code)));
        _expectRedacted(o, reveal.nb);
        _expectRedacted(o, nonce.na);
      }
    });

    test('pairing token', () {
      final t = PairingToken.generate(now: DateTime.utc(2026, 9, 27));
      _expectRedacted(t, t.exportForQr());
    });
  });

  group('PairingToken single use (FR-025)', () {
    final now = DateTime.utc(2026, 9, 27, 12);

    Future<(NoiseHandshake, NoiseHandshake)> attempt(
      PairingToken token,
      X25519KeyPair respStatic, {
      List<int>? scannerToken,
      DateTime? at,
    }) async {
      final resp = (await token.startResponderHandshake(staticKey: respStatic, now: at ?? now))!;
      final init = await NoiseHandshake.xxPsk3(
        initiator: true,
        staticKey: await testStatic(1),
        psk: derivePairingPsk(scannerToken ?? token.exportForQr()),
        expectedResponderFingerprint: x25519Fingerprint(respStatic.publicKey),
      );
      return (init, resp);
    }

    Future<void> complete(NoiseHandshake init, NoiseHandshake resp) async {
      await resp.readMessage(await init.writeMessage());
      await init.readMessage(await resp.writeMessage());
      await resp.readMessage(await init.writeMessage());
    }

    test('failed psk3 attempts do not burn the token; the first success consumes it', () async {
      final respStatic = await testStatic(2);
      final token = PairingToken.generate(now: now);

      final (badInit, badResp) = await attempt(token, respStatic, scannerToken: Uint8List(16));
      await expectLater(complete(badInit, badResp), throwsA(isA<NoiseException>()));
      expect(token.consume(badResp, now), PairingConsumeResult.notVerified);
      expect(token.isUsable(now), isTrue);

      // A handshake still in progress (psk3 not yet checked) cannot consume.
      final (midInit, midResp) = await attempt(token, respStatic);
      await midResp.readMessage(await midInit.writeMessage());
      expect(token.consume(midResp, now), PairingConsumeResult.notVerified);

      final (init, resp) = await attempt(token, respStatic);
      await complete(init, resp);
      expect(token.consume(init, now), PairingConsumeResult.notVerified, reason: 'initiator side cannot consume');
      expect(token.consume(resp, now), PairingConsumeResult.consumed);
      expect(token.isConsumed, isTrue);

      // A second passing handshake (started before consumption) loses.
      expect(await token.startResponderHandshake(staticKey: respStatic, now: now), isNull);
      expect(token.consume(resp, now), PairingConsumeResult.expiredOrUsed);
    });

    test('concurrent passing handshakes: only the first consume wins', () async {
      final respStatic = await testStatic(2);
      final token = PairingToken.generate(now: now);
      final (i1, r1) = await attempt(token, respStatic);
      final (i2, r2) = await attempt(token, respStatic);
      await complete(i1, r1);
      await complete(i2, r2);
      expect(token.consume(r2, now), PairingConsumeResult.consumed);
      expect(token.consume(r1, now), PairingConsumeResult.expiredOrUsed);
    });

    test('a handshake not started by this token cannot consume it', () async {
      final respStatic = await testStatic(2);
      final token = PairingToken.generate(now: now);
      final other = PairingToken.generate(now: now);
      final (init, resp) = await attempt(other, respStatic);
      await complete(init, resp);
      expect(token.consume(resp, now), PairingConsumeResult.notVerified);
      expect(token.isUsable(now), isTrue);
    });

    test('expires 5 minutes after it is shown', () async {
      final respStatic = await testStatic(2);
      final token = PairingToken.generate(now: now);
      final (init, resp) = await attempt(token, respStatic);
      await complete(init, resp);
      final late = now.add(pairingTokenTtl);
      expect(token.consume(resp, late), PairingConsumeResult.expiredOrUsed);
      expect(await token.startResponderHandshake(staticKey: respStatic, now: late), isNull);
      expect(token.isUsable(now.add(const Duration(minutes: 4, seconds: 59))), isTrue);
    });

    test('F3: no per-token cap: 100 failed/pending handshakes never block a legitimate one', () async {
      final respStatic = await testStatic(2);

      Future<List<NoiseHandshake>> flood(PairingToken token) async {
        final started = <NoiseHandshake>[];
        for (var i = 0; i < 100; i++) {
          final hs = (await token.startResponderHandshake(staticKey: respStatic, now: now))!;
          if (i.isEven) await expectLater(hs.readMessage(Uint8List(3)), throwsA(isA<NoiseException>()));
          started.add(hs);
        }
        return started;
      }

      // Legitimate handshake started before the flood.
      final token = PairingToken.generate(now: now);
      final (init, legit) = await attempt(token, respStatic);
      final flooded = await flood(token);
      expect(flooded.where((hs) => hs.hasFailed).length, 50, reason: 'pending handshakes are never evicted');
      expect(legit.hasFailed, isFalse);
      await complete(init, legit);
      for (final hs in flooded) {
        expect(token.consume(hs, now), PairingConsumeResult.notVerified);
      }
      expect(token.consume(legit, now), PairingConsumeResult.consumed);

      // Legitimate handshake started after the flood.
      final token2 = PairingToken.generate(now: now);
      await flood(token2);
      final (init2, legit2) = await attempt(token2, respStatic);
      await complete(init2, legit2);

      // A completed handshake started by another token cannot consume it.
      final other = PairingToken.generate(now: now);
      final (oInit, oResp) = await attempt(other, respStatic);
      await complete(oInit, oResp);
      expect(token2.consume(oResp, now), PairingConsumeResult.notVerified);
      expect(token2.consume(legit2, now), PairingConsumeResult.consumed);
      expect(other.consume(oResp, now), PairingConsumeResult.consumed);
    });

    test('destroy invalidates the token', () async {
      final token = PairingToken.generate(now: now);
      token.destroy();
      expect(token.isUsable(now), isFalse);
      expect(() => token.exportForQr(), throwsStateError);
    });
  });
}
