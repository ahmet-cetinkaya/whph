// T11 acc 2: commit-reveal SAS state machine.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/src/crypto/sas.dart' show createSasInitiatorForTesting, createSasResponderForTesting;
import 'package:whph_sync_core/whph_sync_core.dart';

import 'crypto_test_support.dart';

final _h = testKey(40);
final _rng = Random(7);

Uint8List _rand32() => Uint8List.fromList(List.generate(32, (_) => _rng.nextInt(256)));

enum _Ev { start, na, confirm, peerConfirm, strayCommit, strayReveal, peerAbort }

/// Pairs a responder and an initiator over an in-memory channel.
(SasInitiator, SasResponder) _connected({List<int>? hA, List<int>? hB}) =>
    (SasInitiator(hA ?? _h), SasResponder(hB ?? _h));

void main() {
  group('happy path', () {
    test('both sides show the same 6-digit code and complete after both confirm', () {
      final (a, b) = _connected();
      final commit = b.start().single as SasCommit;
      final nonce = a.receive(commit).single as SasNonce;
      expect(a.code, isNull);
      final reveal = b.receive(nonce).single as SasReveal;
      expect(a.receive(reveal), isEmpty);
      expect(a.code, isNotNull);
      expect(a.code, b.code);
      expect(a.code, matches(RegExp(r'^\d{6}$')));

      final ca = a.confirm();
      expect(a.isConfirmed, isFalse, reason: 'needs the peer too');
      b.receive(ca.single);
      a.receive(SasMessage.decode(b.confirm().single.encode()));
      expect(a.isConfirmed, isTrue);
      expect(b.isConfirmed, isTrue);
    });

    test('messages round-trip through encode/decode; malformed ones throw', () {
      for (final m in [
        SasCommit(_rand32()),
        SasNonce(_rand32()),
        SasReveal(_rand32()),
        const SasConfirm(),
        const SasAbort()
      ]) {
        final d = SasMessage.decode(m.encode());
        expect(d.runtimeType, m.runtimeType);
        expect(d.encode(), m.encode());
      }
      expect(() => SasMessage.decode([]), throwsA(isA<SasException>()));
      expect(() => SasMessage.decode([1, 2, 3]), throwsA(isA<SasException>()));
      expect(() => SasMessage.decode([4, 0]), throwsA(isA<SasException>()));
      expect(() => SasMessage.decode([9]), throwsA(isA<SasException>()));
    });

    test('code: zero-padded digits, deterministic, depends on h, Na and Nb', () {
      final na = _rand32();
      final nb = _rand32();
      final code = sasCode(_h, na, nb);
      expect(code.length, 6);
      expect(sasCode(_h, na, nb), code);
      expect(sasCode(_h, na, nb, digits: 2).length, 2);
      final variants = {sasCode(testKey(41), na, nb), sasCode(_h, _rand32(), nb), sasCode(_h, na, _rand32())};
      expect(variants.contains(code) && variants.length == 1, isFalse);
    });
  });

  group('responder never emits Nb before receiving Na', () {
    test('every event order up to length 5 over 7 event kinds', () {
      var sequences = 0;
      var reveals = 0;
      void explore(List<_Ev> prefix) {
        if (prefix.isNotEmpty) {
          sequences++;
          final b = SasResponder(_h);
          var commitSent = false;
          var naReceivedAfterCommit = false;
          var revealCount = 0;
          for (final ev in prefix) {
            final out = switch (ev) {
              _Ev.start => b.start(),
              _Ev.na => b.receive(SasNonce(_rand32())),
              _Ev.confirm => b.confirm(),
              _Ev.peerConfirm => b.receive(const SasConfirm()),
              _Ev.strayCommit => b.receive(SasCommit(_rand32())),
              _Ev.strayReveal => b.receive(SasReveal(_rand32())),
              _Ev.peerAbort => b.receive(const SasAbort()),
            };
            // Na counts as received once delivered after the commitment went out.
            if (ev == _Ev.na && commitSent) naReceivedAfterCommit = true;
            for (final m in out) {
              if (m is SasReveal) {
                revealCount++;
                expect(naReceivedAfterCommit, isTrue, reason: 'Nb emitted before Na in $prefix');
                expect(ev, _Ev.na, reason: 'Nb emitted in response to a non-Na event in $prefix');
              }
              if (m is SasCommit) commitSent = true;
            }
          }
          expect(revealCount, lessThanOrEqualTo(1), reason: 'Nb revealed twice in $prefix');
          reveals += revealCount;
          // A reveal can only happen for start → Na as the first two events.
          if (revealCount == 1) expect(prefix.take(2), [_Ev.start, _Ev.na]);
        }
        if (prefix.length == 5) return;
        for (final ev in _Ev.values) {
          explore([...prefix, ev]);
        }
      }

      explore(const []);
      expect(sequences, 7 + 49 + 343 + 2401 + 16807);
      expect(reveals, greaterThan(0));
    });

    test('Na before start aborts; a second Na aborts', () {
      final b = SasResponder(_h);
      expect(b.receive(SasNonce(_rand32())).single, isA<SasAbort>());
      expect(b.isAborted, isTrue);
      expect(b.start(), isEmpty);

      final b2 = SasResponder(_h);
      b2.start();
      expect(b2.receive(SasNonce(_rand32())).single, isA<SasReveal>());
      expect(b2.receive(SasNonce(_rand32())).single, isA<SasAbort>());
      expect(b2.code, isNull);
    });
  });

  group('initiator', () {
    test('a revealed Nb that does not match the commitment aborts', () {
      final (a, b) = _connected();
      final commit = b.start().single;
      final nonce = a.receive(commit).single;
      b.receive(nonce);
      final out = a.receive(SasReveal(_rand32()));
      expect(out.single, isA<SasAbort>());
      expect(a.isAborted, isTrue);
      expect(a.code, isNull);
    });

    test('a commitment made under another handshake hash aborts (MITM with two sessions)', () {
      final a = SasInitiator(_h);
      final b = SasResponder(testKey(41)); // other session's h
      final nonce = a.receive(b.start().single).single;
      expect(a.receive(b.receive(nonce).single).single, isA<SasAbort>());
    });

    test('reveal before commit, duplicate commit, early confirm abort', () {
      expect(SasInitiator(_h).receive(SasReveal(_rand32())).single, isA<SasAbort>());
      final a = SasInitiator(_h);
      a.receive(SasCommit(_rand32()));
      expect(a.receive(SasCommit(_rand32())).single, isA<SasAbort>());
      expect(SasInitiator(_h).receive(const SasConfirm()).single, isA<SasAbort>());
      expect(SasInitiator(_h).confirm().single, isA<SasAbort>());
    });
  });

  group('mismatch or cancel aborts both sides', () {
    for (final rejecting in ['initiator', 'responder']) {
      test('$rejecting rejects the code', () {
        final (a, b) = _connected();
        a.receive(b.receive(a.receive(b.start().single).single).single);
        final (rej, other) = rejecting == 'initiator' ? (a, b) : (b, a);
        other.confirm();
        final abort = rej.reject();
        expect(abort.single, isA<SasAbort>());
        other.receive(abort.single);
        expect(a.isAborted && b.isAborted, isTrue);
        expect(a.isConfirmed || b.isConfirmed, isFalse);
        expect(a.code, isNull);
        expect(b.code, isNull);
      });
    }

    test('L2: confirm is idempotent (repeated local or peer confirmation never aborts)', () {
      final (a, b) = _connected();
      a.receive(b.receive(a.receive(b.start().single).single).single);
      final code = a.code;
      expect(a.confirm().single, isA<SasConfirm>());
      expect(a.confirm(), isEmpty, reason: 'double tap before the peer confirmed');
      expect(a.state, SasState.comparing);
      expect(a.receive(const SasConfirm()), isEmpty);
      expect(a.receive(const SasConfirm()), isEmpty, reason: 'duplicate peer confirmation');
      expect(a.isConfirmed, isTrue);
      expect(a.confirm(), isEmpty, reason: 'confirm after completion');
      expect(a.isConfirmed, isTrue);
      expect(a.code, code);

      expect(b.receive(const SasConfirm()), isEmpty);
      expect(b.confirm().single, isA<SasConfirm>());
      expect(b.isConfirmed, isTrue);
      expect(b.confirm(), isEmpty);
      expect(b.isConfirmed, isTrue);
    });

    test('a confirm arriving after an abort does not revive the exchange', () {
      final (a, b) = _connected();
      a.receive(b.receive(a.receive(b.start().single).single).single);
      a.reject();
      expect(a.receive(const SasConfirm()), isEmpty);
      expect(a.isAborted, isTrue);
    });
  });

  group('L3: digit count', () {
    test('production constructors always use 6 digits; only the hidden test factories take digits', () {
      final (a, b) = _connected();
      a.receive(b.receive(a.receive(b.start().single).single).single);
      expect(a.code, matches(RegExp(r'^\d{6}$')));
      final a2 = createSasInitiatorForTesting(_h, digits: 2);
      final b2 = createSasResponderForTesting(_h, digits: 2);
      a2.receive(b2.receive(a2.receive(b2.start().single).single).single);
      expect(a2.code, matches(RegExp(r'^\d{2}$')));
      expect(() => createSasInitiatorForTesting(_h, digits: 0), throwsArgumentError);
      final export = File('lib/whph_sync_core.dart').readAsStringSync();
      expect(export, contains('hide createSasInitiatorForTesting, createSasResponderForTesting'));
    });
  });

  group('MITM with reduced 2-digit SAS', () {
    test('grinding ephemerals succeeds at 1/100 within a 5-sigma bound', () {
      const trials = 20000;
      const grind = 8;
      var successes = 0;
      for (var t = 0; t < trials; t++) {
        // Session M ↔ B (M is the initiator, B an honest responder): M
        // completes it first and learns code2.
        final h2 = _rand32();
        final bSide = createSasResponderForTesting(h2, digits: 2);
        final m2 = createSasInitiatorForTesting(h2, digits: 2);
        m2.receive(bSide.receive(m2.receive(bSide.start().single).single).single);
        final code2 = bSide.code!;
        expect(m2.code, code2);

        // Session A ↔ M (M is the responder). M grinds `grind` ephemerals
        // (handshake hashes) and Nb values, picking one that would match
        // code2 for a guessed Na — but it must commit before A's Na.
        Uint8List? h1;
        Uint8List? nb1;
        final guessNa = _rand32();
        for (var g = 0; g < grind; g++) {
          final hc = _rand32();
          final nbc = _rand32();
          h1 ??= hc;
          nb1 ??= nbc;
          if (sasCode(hc, guessNa, nbc, digits: 2) == code2) {
            h1 = hc;
            nb1 = nbc;
            break;
          }
        }
        final a = createSasInitiatorForTesting(h1!, digits: 2);
        final na = a.receive(SasCommit(sasCommitment(h1, nb1!))).single as SasNonce;
        expect(na.na, isNot(guessNa));
        a.receive(SasReveal(nb1));
        if (a.code == code2) successes++;
      }
      final rate = successes / trials;
      final sigma = sqrt(0.01 * 0.99 / trials);
      // ignore: avoid_print
      print(
          '[T11] SAS 2-digit MITM success rate = $rate over $trials trials (expected 0.01 ± ${(5 * sigma).toStringAsFixed(4)})');
      expect(rate, closeTo(0.01, 5 * sigma));
    });

    test('contrast: without the commitment (Nb chosen after Na) grinding always wins', () {
      var successes = 0;
      for (var t = 0; t < 200; t++) {
        final code2 = sasCode(_rand32(), _rand32(), _rand32(), digits: 2);
        final h1 = _rand32();
        final na = _rand32();
        for (var g = 0; g < 2000; g++) {
          if (sasCode(h1, na, _rand32(), digits: 2) == code2) {
            successes++;
            break;
          }
        }
      }
      expect(successes, greaterThan(195));
    });
  });
}
