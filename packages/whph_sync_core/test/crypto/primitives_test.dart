// T11: primitives adapter — HMAC-BLAKE2b KATs, low-order X25519 rejection,
// PSK derivation, Ed25519 wrapper.
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';
import 'package:whph_sync_core/src/crypto/primitives.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'crypto_test_support.dart';

/// Known-answer values from an independent implementation: CPython
/// `hmac.new(key, msg, hashlib.blake2b)` (BLAKE2b-512, block_size 128).
const _hmacKats = [
  (
    key: '0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b',
    msg: '4869205468657265',
    mac: '358a6a184924894fc34bee5680eedf57d84a37bb38832f288e3b27dc63a98cc8'
        'c91e76da476b508bc6b2d408a248857452906e4a20b48c6b4b55d2df0fe1dd24',
  ),
  (
    key: '4a656665',
    msg: '7768617420646f2079612077616e7420666f72206e6f7468696e673f',
    mac: '6ff884f8ddc2a6586b3c98a4cd6ebdf14ec10204b6710073eb5865ade37a2643'
        'b8807c1335d107ecdb9ffeaeb6828c4625ba172c66379efcd222c2de11727ab4',
  ),
  (
    key: '',
    msg: '',
    mac: '198cd2006f66ff83fbbd913f78aca2251caf4f19fe9475aade8cf2091b99a684'
        '66775177424f58286886cbae8229644cec747237d4b721735485e17372fdf59c',
  ),
];

// Low-order Curve25519 points (u-coordinates), from the libsodium / "May
// the Fourth" blacklist: 0, 1, the order-8 points and non-canonical p, p+1.
const _lowOrderPoints = [
  '0000000000000000000000000000000000000000000000000000000000000000',
  '0100000000000000000000000000000000000000000000000000000000000000',
  'e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800',
  '5f9c95bca3508c24b1d0b1559c83ef5b04445cc4581c8e86d8224eddd09f1157',
  'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f',
  'edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f',
];

void main() {
  group('HMAC-BLAKE2b (128-byte block)', () {
    for (final kat in _hmacKats) {
      test('KAT key ${kat.key.length ~/ 2} bytes', () {
        expect(toHex(hmacBlake2b(hex(kat.key), hex(kat.msg))), kat.mac);
      });
    }

    test('KAT: key longer than the block (131 bytes) is hashed first (RFC 2104)', () {
      final key = Uint8List(131)..fillRange(0, 131, 0xaa);
      final msg = hex(
          '54657374205573696e67204c6172676572205468616e20426c6f636b2d53697a65204b6579202d2048617368204b6579204669727374');
      expect(
        toHex(hmacBlake2b(key, msg)),
        'a54b2943b2a20227d41ca46c0945af09bc1faefb2f49894c23aebc557fb79c48'
        '89dca74408dc865086667aedee4a3185c53a49c80b814c4c5813ea0c8b38a8f8',
      );
      // Equivalent to HMAC with the pre-hashed key.
      expect(hmacBlake2b(key, msg), hmacBlake2b(blake2b512(key), msg));
    });

    test('KAT: key exactly the block size is used as is', () {
      final key = Uint8List(128)..fillRange(0, 128, 0xaa);
      expect(
        toHex(hmacBlake2b(key, hex('65786163746c7920626c6f636b'))),
        '860dbb81be2d91506b0746126116a6dc03af6e57947a5a38c83fd6698c98abfc'
        'fa201ee4d0de533471a29ea8e6b0184e60782155f348c7738e0e1fe9faf39447',
      );
    });

    test('documents why cryptography Hmac.blake2b() is not used (block length 64)', () async {
      final key = hex('4a656665');
      final msg = hex('7768617420646f2079612077616e7420666f72206e6f7468696e673f');
      final lib = await Hmac.blake2b().calculateMac(msg, secretKey: SecretKey(key));
      expect(toHex(lib.bytes), isNot(_hmacKats[1].mac));
    });

    test('noiseHkdf returns 2 or 3 outputs of 64 bytes, chained per Noise §4.3', () {
      final ck = testKey(9);
      final ikm = testKey(10);
      final out3 = noiseHkdf(ck, ikm, 3);
      final out2 = noiseHkdf(ck, ikm, 2);
      expect(out3.map((o) => o.length), [64, 64, 64]);
      expect(out2[0], out3[0]);
      expect(out2[1], out3[1]);
      final temp = hmacBlake2b(ck, ikm);
      expect(out3[0], hmacBlake2b(temp, [1]));
      expect(out3[2], hmacBlake2b(temp, [...out3[1], 3]));
      expect(() => noiseHkdf(ck, ikm, 4), throwsArgumentError);
    });
  });

  group('X25519', () {
    for (final p in _lowOrderPoints) {
      test('rejects all-zero shared secret with low-order point ${p.substring(0, 8)}…', () async {
        final kp = await testStatic(3);
        expect(() => x25519(kp, hex(p)), throwsA(isA<LowOrderPointException>()));
      });
    }

    test('normal exchange agrees on both sides', () async {
      final a = await testStatic(3);
      final b = await testStatic(4);
      expect(x25519(a, b.publicKey), x25519(b, a.publicKey));
    });

    test('destroyed key pair refuses use', () async {
      final a = await testStatic(3);
      a.destroy();
      expect(a.isDestroyed, isTrue);
      expect(() => a.exportPrivateKey(), throwsStateError);
      expect(() => x25519(a, testKey(4)), throwsStateError);
    });
  });

  group('pairing PSK derivation', () {
    test('domain-separated, 32 bytes, differs from plain BLAKE2b of the token', () {
      final token = Uint8List.fromList(List.generate(16, (i) => i));
      final psk = derivePairingPsk(token);
      expect(psk.length, 32);
      expect(psk, isNot(blake2b256(token)));
      expect(psk, domainHash256(pairingPskDomain, [token]));
      expect(derivePairingPsk(Uint8List.fromList(List.generate(16, (i) => i + 1))), isNot(psk));
    });

    test('rejects tokens that are not 128 bits', () {
      expect(() => derivePairingPsk(Uint8List(15)), throwsA(isA<InvalidKeyMaterialException>()));
      expect(() => derivePairingPsk(Uint8List(32)), throwsA(isA<InvalidKeyMaterialException>()));
    });

    test('domainHash256 length-prefixes parts (no concatenation ambiguity)', () {
      expect(
          domainHash256('d', [
            [1, 2],
            [3]
          ]),
          isNot(domainHash256('d', [
            [1],
            [2, 3]
          ])));
      expect(domainHash256('a', const []), isNot(domainHash256('b', const [])));
    });
  });

  group('Ed25519', () {
    test('sign/verify; wrong key, message or malformed input verify false', () async {
      final a = await Ed25519KeyPair.fromSeed(testKey(5));
      final b = await Ed25519KeyPair.fromSeed(testKey(6));
      final sig = await a.sign([1, 2, 3]);
      expect(await ed25519Verify([1, 2, 3], sig, a.publicKey), isTrue);
      expect(await ed25519Verify([1, 2, 4], sig, a.publicKey), isFalse);
      expect(await ed25519Verify([1, 2, 3], sig, b.publicKey), isFalse);
      expect(await ed25519Verify([1, 2, 3], sig.sublist(0, 63), a.publicKey), isFalse);
      expect(await ed25519Verify([1, 2, 3], Uint8List(64), a.publicKey), isFalse);
      a.destroy();
      expect(() => a.sign([1]), throwsStateError);
    });

    group('L4: small-order and non-canonical public keys are refused', () {
      const smallOrder = [
        '0100000000000000000000000000000000000000000000000000000000000000',
        'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f',
        '0000000000000000000000000000000000000000000000000000000000000000',
        '0000000000000000000000000000000000000000000000000000000000000080',
        'c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac037a',
        'c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac03fa',
        '26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc05',
        '26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc85',
        // Non-canonical sign-bit aliases (x = 0 with the sign bit set) that
        // libsodium blocks; y < p, so only the explicit list catches them.
        '0100000000000000000000000000000000000000000000000000000000000080',
        'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      ];
      // y >= p aliases (y = p, p + 1 = alias of the identity, 2^255 - 1).
      const nonCanonical = [
        'edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f',
        'eeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f',
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      ];
      final identity = hex(smallOrder.first);
      // R = identity point, S = 0: "valid" for every message under a
      // small-order key in implementations without the check.
      final forged = Uint8List(64)..setRange(0, 32, identity);

      for (final k in [...smallOrder, ...nonCanonical]) {
        test('refuses ${k.substring(0, 8)}…${k.substring(56)}', () async {
          final pub = hex(k);
          expect(isWeakEd25519PublicKey(pub), isTrue);
          expect(await ed25519Verify(const [1, 2, 3], forged, pub), isFalse);
          expect(() => MemberKeySet([pub]), throwsA(isA<InvalidKeyMaterialException>()));
          expect(() => MemberKeySet(const []).add(pub), throwsA(isA<InvalidKeyMaterialException>()));
          expect(_AllMembers().isMember(pub), isTrue, reason: 'control: a permissive directory');

          final row = OriginRegistration(origin: originOf(1), memberPub: pub, createdHlc: testHlc, sig: forged);
          expect(await verifyOriginRegistration(testGroup, row), isFalse);
          final registry = OriginRegistrySet(testGroup, members: _AllMembers());
          expect((await registry.merge([row])).rejected, 1);
          expect(registry.ownerOf(originOf(1)), isA<OriginUnregistered>());

          final record = RevocationRecord(revokedPub: testKey(9), revokerPub: pub, cutoffs: const {}, sig: forged);
          expect((await RevocationSet(testGroup).merge([record], _AllMembers())).rejected, 1);
        });
      }

      test('honest keys are not weak', () async {
        for (var i = 0; i < 50; i++) {
          final k = await Ed25519KeyPair.fromSeed(testKey(100 + i));
          expect(isWeakEd25519PublicKey(k.publicKey), isFalse);
        }
        expect(isWeakEd25519PublicKey(Uint8List(31)), isTrue);
      });
    });
  });
}

final class _AllMembers implements MemberDirectory {
  @override
  bool isMember(List<int> ed25519Pub) => true;
}
