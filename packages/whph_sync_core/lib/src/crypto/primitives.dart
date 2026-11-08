/// Primitives adapter over the pure-Dart `cryptography` package (U1, D7).
///
/// Every other file in `lib/src/crypto/` reaches the library only through
/// this file, so the known pitfalls of `cryptography` 2.9.0 are handled once:
///
/// * `Blake2b.blockLengthInBytes` reports 64 (BLAKE2b's block is 128 bytes),
///   so `Hmac.blake2b()` and `Hkdf(hmac: Hmac.blake2b())` are **not** RFC 2104
///   HMAC-BLAKE2b. They must never be used; [hmacBlake2b] implements HMAC with
///   the correct 128-byte block and [noiseHkdf] the Noise HKDF (§4.3) on top.
/// * `DartX25519` does not reject low-order points. [x25519] throws
///   [LowOrderPointException] for an all-zero shared secret.
/// * `encryptSync` without a nonce draws 24 bytes from `Random.secure()` per
///   call; envelopes use `NonceSource` (see `envelope.dart`) instead.
///
/// Secret bytes live in `Uint8List`s owned by the caller or by one of the key
/// classes here; [zeroize] overwrites them. Dart cannot guarantee that no
/// other copy exists (the library copies keys internally; the GC may move
/// objects), so zeroing is best effort. No class here prints key bytes.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import '../model/wire_bytes.dart';

/// Base type of every failure raised by the crypto layer. Messages carry
/// reason categories only, never key, token, nonce or plaintext bytes.
sealed class SyncCryptoException implements Exception {
  const SyncCryptoException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A handshake or transport message failed (bad MAC, wrong state, wrong peer
/// key, oversize, malformed). The Noise object is torn down afterwards.
final class NoiseException extends SyncCryptoException {
  const NoiseException(super.message);
}

/// An X25519 exchange produced the all-zero shared secret (low-order point).
final class LowOrderPointException extends SyncCryptoException {
  const LowOrderPointException() : super('X25519 shared secret is all zero (low-order point)');
}

/// A SAS exchange violated the commit-reveal protocol or was aborted.
final class SasException extends SyncCryptoException {
  const SasException(super.message);
}

/// A signature, key or signed record is malformed.
final class InvalidKeyMaterialException extends SyncCryptoException {
  const InvalidKeyMaterialException(super.message);
}

/// A group-key epoch counter is out of bounds: a rotation would exceed
/// `EpochId.maxCounter`, or a handed-over epoch jumps implausibly far ahead
/// of every held epoch (see `epoch.dart`).
final class EpochCounterException extends SyncCryptoException {
  const EpochCounterException(super.message);
}

/// Length of X25519 and Ed25519 public keys and of symmetric keys.
const keyLength = 32;

/// BLAKE2b block length (RFC 7693).
const blake2bBlockLength = 128;

/// BLAKE2b-512 output length (the Noise HASHLEN of `BLAKE2b`).
const blake2b512Length = 64;

const DartBlake2b _blake2b512 = DartBlake2b(hashLengthInBytes: blake2b512Length);
const DartBlake2b _blake2b256 = DartBlake2b(hashLengthInBytes: 32);
const DartX25519 _x25519 = DartX25519();
final DartEd25519 _ed25519 = DartEd25519(sha512: const DartSha512());
final Random _secureRandom = Random.secure();

/// BLAKE2b-512 of [data].
Uint8List blake2b512(List<int> data) => Uint8List.fromList(_blake2b512.hashSync(data).bytes);

/// BLAKE2b-256 of the domain-separated input `str domain ‖ parts...`, where
/// `str` is `u32 len ‖ UTF-8` and each part is appended as a `u32 len ‖ bytes`
/// byte string, so distinct inputs never collide by concatenation.
Uint8List domainHash256(String domain, List<List<int>> parts) {
  final w = ByteWriter()..string(domain);
  for (final p in parts) {
    w.bytes(p);
  }
  final input = w.take();
  final out = Uint8List.fromList(_blake2b256.hashSync(input).bytes);
  zeroize(input);
  return out;
}

/// RFC 2104 HMAC over BLAKE2b-512 with the correct 128-byte block length.
/// Keys longer than the block are hashed first.
Uint8List hmacBlake2b(List<int> key, List<int> data) {
  final hashedKey = key.length > blake2bBlockLength ? blake2b512(key) : null;
  final k = hashedKey ?? key;
  final ipad = Uint8List(blake2bBlockLength + data.length);
  final opad = Uint8List(blake2bBlockLength + blake2b512Length);
  for (var i = 0; i < blake2bBlockLength; i++) {
    final b = i < k.length ? k[i] : 0;
    ipad[i] = b ^ 0x36;
    opad[i] = b ^ 0x5c;
  }
  ipad.setRange(blake2bBlockLength, ipad.length, data);
  final inner = blake2b512(ipad);
  opad.setRange(blake2bBlockLength, opad.length, inner);
  final out = blake2b512(opad);
  zeroize(ipad);
  zeroize(opad);
  zeroize(inner);
  if (hashedKey != null) zeroize(hashedKey);
  return out;
}

/// Noise HKDF (spec §4.3) returning [outputs] (2 or 3) values of HASHLEN
/// (64) bytes.
List<Uint8List> noiseHkdf(List<int> chainingKey, List<int> ikm, int outputs) {
  if (outputs != 2 && outputs != 3) throw ArgumentError.value(outputs, 'outputs', 'must be 2 or 3');
  final temp = hmacBlake2b(chainingKey, ikm);
  final out1 = hmacBlake2b(temp, const [0x01]);
  final in2 = Uint8List(blake2b512Length + 1)
    ..setRange(0, blake2b512Length, out1)
    ..[blake2b512Length] = 0x02;
  final out2 = hmacBlake2b(temp, in2);
  zeroize(in2);
  if (outputs == 2) {
    zeroize(temp);
    return [out1, out2];
  }
  final in3 = Uint8List(blake2b512Length + 1)
    ..setRange(0, blake2b512Length, out2)
    ..[blake2b512Length] = 0x03;
  final out3 = hmacBlake2b(temp, in3);
  zeroize(in3);
  zeroize(temp);
  return [out1, out2, out3];
}

/// Overwrites [bytes] with zeros (best effort; see the library comment).
void zeroize(Uint8List? bytes) {
  if (bytes == null) return;
  bytes.fillRange(0, bytes.length, 0);
}

/// Constant-time equality for equal-length inputs (length is not secret).
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// [length] bytes from the platform CSPRNG (`Random.secure()`).
Uint8List secureRandomBytes(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = _secureRandom.nextInt(256);
  }
  return out;
}

bool _isAllZero(List<int> bytes) {
  var acc = 0;
  for (final b in bytes) {
    acc |= b;
  }
  return acc == 0;
}

/// An X25519 key pair (Noise static or ephemeral key). The private key stays
/// inside; [destroy] zeroes it.
final class X25519KeyPair {
  X25519KeyPair._(this._private, this._data, this.publicKey);

  final Uint8List _private;
  final SimpleKeyPairData _data;

  /// The 32-byte public key (not secret).
  final Uint8List publicKey;

  bool _destroyed = false;

  /// Derives the key pair of a 32-byte private key. The input is copied; the
  /// caller keeps ownership of (and should zero) its own copy.
  static Future<X25519KeyPair> fromPrivateKey(List<int> privateKey) async {
    if (privateKey.length != keyLength) throw const InvalidKeyMaterialException('X25519 private key must be 32 bytes');
    final private = Uint8List.fromList(privateKey);
    final pair = await _x25519.newKeyPairFromSeed(private);
    final data = await pair.extract();
    final pub = await pair.extractPublicKey();
    return X25519KeyPair._(private, data, Uint8List.fromList(pub.bytes).asUnmodifiableView());
  }

  /// A fresh random key pair.
  static Future<X25519KeyPair> generate() async {
    final seed = secureRandomBytes(keyLength);
    try {
      return await fromPrivateKey(seed);
    } finally {
      zeroize(seed);
    }
  }

  /// A copy of the private key for persistence in the key file (T20). The
  /// caller owns and zeroes the copy.
  Uint8List exportPrivateKey() {
    _checkAlive();
    return Uint8List.fromList(_private);
  }

  void _checkAlive() {
    if (_destroyed) throw StateError('X25519 key pair destroyed');
  }

  bool get isDestroyed => _destroyed;

  /// Zeroes the private key (this object and the library's copy).
  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    zeroize(_private);
    _data.destroy();
  }

  /// Never prints key bytes.
  @override
  String toString() => 'X25519KeyPair(<redacted>)';
}

/// X25519(local private, remote public). Throws [LowOrderPointException]
/// when the result is all zero (the remote key is a low-order point), and
/// [InvalidKeyMaterialException] for a malformed remote key.
Uint8List x25519(X25519KeyPair local, List<int> remotePublic) {
  local._checkAlive();
  if (remotePublic.length != keyLength) throw const InvalidKeyMaterialException('X25519 public key must be 32 bytes');
  final secret = _x25519.sharedSecretSync(
    keyPairData: local._data,
    remotePublicKey: SimplePublicKey(List<int>.of(remotePublic), type: KeyPairType.x25519),
  ) as SecretKeyData;
  final out = Uint8List.fromList(secret.bytes);
  secret.destroy();
  if (_isAllZero(out)) throw const LowOrderPointException();
  return out;
}

/// An Ed25519 signing key pair (member identity, D7). [destroy] zeroes the
/// seed.
final class Ed25519KeyPair {
  Ed25519KeyPair._(this._seed, this._data, this.publicKey);

  final Uint8List _seed;
  final SimpleKeyPairData _data;

  /// The 32-byte public key (`member_ed25519_pub`).
  final Uint8List publicKey;

  bool _destroyed = false;

  /// Derives the key pair of a 32-byte seed (copied).
  static Future<Ed25519KeyPair> fromSeed(List<int> seed) async {
    if (seed.length != keyLength) throw const InvalidKeyMaterialException('Ed25519 seed must be 32 bytes');
    final copy = Uint8List.fromList(seed);
    final pair = await _ed25519.newKeyPairFromSeed(copy);
    final data = await pair.extract();
    final pub = await pair.extractPublicKey();
    return Ed25519KeyPair._(copy, data, Uint8List.fromList(pub.bytes).asUnmodifiableView());
  }

  /// A fresh random key pair.
  static Future<Ed25519KeyPair> generate() async {
    final seed = secureRandomBytes(keyLength);
    try {
      return await fromSeed(seed);
    } finally {
      zeroize(seed);
    }
  }

  /// A copy of the seed for the key file (T20); the caller zeroes it.
  Uint8List exportSeed() {
    _checkAlive();
    return Uint8List.fromList(_seed);
  }

  void _checkAlive() {
    if (_destroyed) throw StateError('Ed25519 key pair destroyed');
  }

  bool get isDestroyed => _destroyed;

  /// Signs [message] (64-byte signature).
  Future<Uint8List> sign(List<int> message) async {
    _checkAlive();
    final sig = await _ed25519.sign(message, keyPair: _data);
    return Uint8List.fromList(sig.bytes);
  }

  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    zeroize(_seed);
    _data.destroy();
  }

  /// Never prints key bytes.
  @override
  String toString() => 'Ed25519KeyPair(<redacted>)';
}

/// The eight canonical encodings of the small-order (torsion) points of
/// edwards25519, plus the two non-canonical aliases with the sign bit set on
/// an `x = 0` point that libsodium also blocks (their `y < p`, so the
/// `y >= p` check below does not catch them). A "public key" among them lets
/// anyone forge signatures (e.g. `R = identity, S = 0` verifies for every
/// message under the identity key), so they are never accepted as member
/// keys.
const List<String> _smallOrderEd25519Hex = [
  '0100000000000000000000000000000000000000000000000000000000000000', // order 1
  'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f', // order 2
  '0000000000000000000000000000000000000000000000000000000000000000', // order 4
  '0000000000000000000000000000000000000000000000000000000000000080', // order 4
  'c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac037a', // order 8
  'c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac03fa', // order 8
  '26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc05', // order 8
  '26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc85', // order 8
  '0100000000000000000000000000000000000000000000000000000000000080', // order 1, sign bit set (non-canonical)
  'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', // order 2, sign bit set (non-canonical)
];

final List<Uint8List> _smallOrderEd25519 = [
  for (final h in _smallOrderEd25519Hex)
    Uint8List.fromList([for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)]),
];

/// Whether [publicKey] is not acceptable as an Ed25519 member key: wrong
/// length, one of the small-order point encodings (the eight canonical ones
/// and two sign-bit aliases), or a non-canonical
/// encoding (`y >= 2^255 - 19`, which includes non-canonical aliases of the
/// small-order points). Honest key generation never produces such keys.
bool isWeakEd25519PublicKey(List<int> publicKey) {
  if (publicKey.length != keyLength) return true;
  for (final weak in _smallOrderEd25519) {
    if (constantTimeEquals(weak, publicKey)) return true;
  }
  // y (little-endian, sign bit masked) >= p = 2^255 - 19 ⇔ top byte 0x7f,
  // bytes 30..1 all 0xff and byte 0 >= 0xed.
  if ((publicKey[31] & 0x7f) != 0x7f || publicKey[0] < 0xed) return false;
  for (var i = 1; i < 31; i++) {
    if (publicKey[i] != 0xff) return false;
  }
  return true;
}

/// Verifies an Ed25519 [signature] by [publicKey] over [message]. Malformed
/// keys or signatures and weak keys ([isWeakEd25519PublicKey]) verify as
/// `false` (never throw).
Future<bool> ed25519Verify(List<int> message, List<int> signature, List<int> publicKey) async {
  if (signature.length != 64 || isWeakEd25519PublicKey(publicKey)) return false;
  try {
    return await _ed25519.verify(
      message,
      signature: Signature(List<int>.of(signature),
          publicKey: SimplePublicKey(List<int>.of(publicKey), type: KeyPairType.ed25519)),
    );
  } on Object {
    return false;
  }
}

/// XChaCha20-Poly1305 seal: `ciphertext ‖ 16-byte tag`.
Uint8List xchachaSeal({
  required List<int> key,
  required List<int> nonce,
  required List<int> plaintext,
  required List<int> aad,
}) {
  final secretKey = SecretKeyData(Uint8List.fromList(key), overwriteWhenDestroyed: true);
  try {
    return _sealed(_xchacha.encryptSync(plaintext, secretKey: secretKey, nonce: nonce, aad: aad));
  } finally {
    secretKey.destroy();
  }
}

/// XChaCha20-Poly1305 open; returns `null` on authentication failure.
Uint8List? xchachaOpen({
  required List<int> key,
  required List<int> nonce,
  required List<int> sealed,
  required List<int> aad,
}) {
  if (sealed.length < aeadTagLength) return null;
  final split = sealed.length - aeadTagLength;
  final box = SecretBox(sealed.sublist(0, split), nonce: nonce, mac: Mac(sealed.sublist(split)));
  final secretKey = SecretKeyData(Uint8List.fromList(key), overwriteWhenDestroyed: true);
  try {
    return _ownedPlaintext(_xchacha.decryptSync(box, secretKey: secretKey, aad: aad));
  } on SecretBoxAuthenticationError {
    return null;
  } finally {
    secretKey.destroy();
  }
}

/// ChaCha20-Poly1305 (IETF, 12-byte nonce) seal for Noise: `ct ‖ tag`.
Uint8List chachaSeal({
  required List<int> key,
  required List<int> nonce,
  required List<int> plaintext,
  required List<int> aad,
}) {
  final secretKey = SecretKeyData(Uint8List.fromList(key), overwriteWhenDestroyed: true);
  try {
    return _sealed(_chacha.encryptSync(plaintext, secretKey: secretKey, nonce: nonce, aad: aad));
  } finally {
    secretKey.destroy();
  }
}

/// ChaCha20-Poly1305 open for Noise; `null` on authentication failure.
Uint8List? chachaOpen({
  required List<int> key,
  required List<int> nonce,
  required List<int> sealed,
  required List<int> aad,
}) {
  if (sealed.length < aeadTagLength) return null;
  final split = sealed.length - aeadTagLength;
  final box = SecretBox(sealed.sublist(0, split), nonce: nonce, mac: Mac(sealed.sublist(split)));
  final secretKey = SecretKeyData(Uint8List.fromList(key), overwriteWhenDestroyed: true);
  try {
    return _ownedPlaintext(_chacha.decryptSync(box, secretKey: secretKey, aad: aad));
  } on SecretBoxAuthenticationError {
    return null;
  } finally {
    secretKey.destroy();
  }
}

/// `ciphertext ‖ tag` of [box].
Uint8List _sealed(SecretBox box) => Uint8List(box.cipherText.length + aeadTagLength)
  ..setRange(0, box.cipherText.length, box.cipherText)
  ..setRange(box.cipherText.length, box.cipherText.length + aeadTagLength, box.mac.bytes);

/// A caller-owned copy of a decrypted [plaintext]; the library's buffer is
/// zeroed (best effort) so only the returned copy holds the plaintext.
Uint8List _ownedPlaintext(List<int> plaintext) {
  final out = Uint8List.fromList(plaintext);
  try {
    plaintext.fillRange(0, plaintext.length, 0);
  } on UnsupportedError {
    // Unmodifiable library buffer: nothing more can be done.
  }
  return out;
}

/// Poly1305 tag length.
const aeadTagLength = 16;

const DartXchacha20 _xchacha = DartXchacha20.poly1305Aead();
const DartChacha20 _chacha = DartChacha20.poly1305Aead();
