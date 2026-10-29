// S4 spike code — replaced by lib/src/crypto in T11; not for production use.
//
// Minimal Noise (rev 34) implementation of the `XX` pattern with optional
// `pskN` modifiers (so `XXpsk3`) for the `25519_ChaChaPoly_BLAKE2b` suite,
// built on the pure-Dart `cryptography` package.
//
// Notes recorded by the spike:
// * `Hmac.blake2b()` from `cryptography` uses a 64-byte block length, which is
//   not RFC 2104 HMAC-BLAKE2b (block = 128 bytes). HMAC and the Noise HKDF are
//   therefore implemented here directly over `DartBlake2b`.
// * `DartX25519` does not reject low-order points (all-zero shared secret).
//   Noise permits this; T11 may add an all-zero check.

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// Raised for every handshake or transport failure (bad MAC, wrong state,
/// unexpected static key, malformed message).
class NoiseSpikeException implements Exception {
  NoiseSpikeException(this.message);

  final String message;

  @override
  String toString() => 'NoiseSpikeException: $message';
}

const int _dhLen = 32;
const int _hashLen = 64;
const int _blockLen = 128;
const int _tagLen = 16;

const DartBlake2b _blake2b512 = DartBlake2b(hashLengthInBytes: _hashLen);
const DartChacha20 _chachaPoly = DartChacha20.poly1305Aead();
const DartX25519 _x25519 = DartX25519();

Uint8List _hash(List<int> data) => Uint8List.fromList(_blake2b512.hashSync(data).bytes);

Uint8List _concat(List<List<int>> parts) {
  final builder = BytesBuilder(copy: false);
  for (final p in parts) {
    builder.add(p);
  }
  return builder.takeBytes();
}

/// RFC 2104 HMAC over BLAKE2b-512 with the correct 128-byte block length.
Uint8List hmacBlake2b(List<int> key, List<int> data) {
  final k = key.length > _blockLen ? _hash(key) : key;
  final padded = Uint8List(_blockLen)..setRange(0, k.length, k);
  final ipad = Uint8List(_blockLen);
  final opad = Uint8List(_blockLen);
  for (var i = 0; i < _blockLen; i++) {
    ipad[i] = padded[i] ^ 0x36;
    opad[i] = padded[i] ^ 0x5c;
  }
  final inner = _hash(_concat([ipad, data]));
  return _hash(_concat([opad, inner]));
}

/// Noise HKDF (spec §4.3) returning [outputs] (2 or 3) values of HASHLEN bytes.
List<Uint8List> noiseHkdf(List<int> chainingKey, List<int> ikm, int outputs) {
  final temp = hmacBlake2b(chainingKey, ikm);
  final out1 = hmacBlake2b(temp, const [0x01]);
  final out2 = hmacBlake2b(
      temp,
      _concat([
        out1,
        const [0x02]
      ]));
  if (outputs == 2) return [out1, out2];
  final out3 = hmacBlake2b(
      temp,
      _concat([
        out2,
        const [0x03]
      ]));
  return [out1, out2, out3];
}

/// Noise CipherState for ChaChaPoly (nonce = 4 zero bytes + u64 LE counter).
class NoiseCipherState {
  Uint8List? _k;
  int _n = 0;

  bool get hasKey => _k != null;

  void initializeKey(Uint8List? key) {
    _k = key;
    _n = 0;
  }

  Uint8List _nonce() {
    final nonce = Uint8List(12);
    ByteData.sublistView(nonce).setUint64(4, _n, Endian.little);
    return nonce;
  }

  void _advance() {
    // 2^64-1 is reserved; Dart ints are signed 64-bit, so stop before wrap.
    if (_n == 0x7fffffffffffffff) throw NoiseSpikeException('nonce exhausted');
    _n++;
  }

  Uint8List encryptWithAd(List<int> ad, List<int> plaintext) {
    final k = _k;
    if (k == null) return Uint8List.fromList(plaintext);
    final box = _chachaPoly.encryptSync(plaintext, secretKey: SecretKeyData(k), nonce: _nonce(), aad: ad);
    _advance();
    return _concat([box.cipherText, box.mac.bytes]);
  }

  Uint8List decryptWithAd(List<int> ad, List<int> ciphertext) {
    final k = _k;
    if (k == null) return Uint8List.fromList(ciphertext);
    if (ciphertext.length < _tagLen) throw NoiseSpikeException('ciphertext too short');
    final split = ciphertext.length - _tagLen;
    final box = SecretBox(ciphertext.sublist(0, split), nonce: _nonce(), mac: Mac(ciphertext.sublist(split)));
    final List<int> plain;
    try {
      plain = _chachaPoly.decryptSync(box, secretKey: SecretKeyData(k), aad: ad);
    } on SecretBoxAuthenticationError {
      // The nonce is not advanced on failure; callers abort the session anyway.
      throw NoiseSpikeException('authentication failed');
    }
    _advance();
    return Uint8List.fromList(plain);
  }
}

class _SymmetricState {
  _SymmetricState(String protocolName) {
    final nameBytes = Uint8List.fromList(protocolName.codeUnits);
    if (nameBytes.length <= _hashLen) {
      h = Uint8List(_hashLen)..setRange(0, nameBytes.length, nameBytes);
    } else {
      h = _hash(nameBytes);
    }
    ck = Uint8List.fromList(h);
  }

  late Uint8List h;
  late Uint8List ck;
  final NoiseCipherState cs = NoiseCipherState();

  void mixKey(List<int> ikm) {
    final out = noiseHkdf(ck, ikm, 2);
    ck = out[0];
    cs.initializeKey(Uint8List.fromList(out[1].sublist(0, 32)));
  }

  void mixHash(List<int> data) {
    h = _hash(_concat([h, data]));
  }

  void mixKeyAndHash(List<int> ikm) {
    final out = noiseHkdf(ck, ikm, 3);
    ck = out[0];
    mixHash(out[1]);
    cs.initializeKey(Uint8List.fromList(out[2].sublist(0, 32)));
  }

  Uint8List encryptAndHash(List<int> plaintext) {
    final c = cs.encryptWithAd(h, plaintext);
    mixHash(c);
    return c;
  }

  Uint8List decryptAndHash(List<int> ciphertext) {
    final p = cs.decryptWithAd(h, ciphertext);
    mixHash(ciphertext);
    return p;
  }

  List<NoiseCipherState> split() {
    final out = noiseHkdf(ck, const [], 2);
    return [
      NoiseCipherState()..initializeKey(Uint8List.fromList(out[0].sublist(0, 32))),
      NoiseCipherState()..initializeKey(Uint8List.fromList(out[1].sublist(0, 32))),
    ];
  }
}

/// A completed handshake's transport: one CipherState per direction.
class NoiseTransport {
  NoiseTransport._(this._send, this._recv, this.handshakeHash, this.remoteStatic);

  final NoiseCipherState _send;
  final NoiseCipherState _recv;
  final Uint8List handshakeHash;
  final Uint8List remoteStatic;
  bool _failed = false;

  Uint8List encrypt(List<int> payload) {
    if (_failed) throw NoiseSpikeException('transport torn down');
    return _send.encryptWithAd(const [], payload);
  }

  /// Decrypts the next inbound message; the first failure tears the session
  /// down (replayed, reordered or altered messages all fail here).
  Uint8List decrypt(List<int> message) {
    if (_failed) throw NoiseSpikeException('transport torn down');
    try {
      return _recv.decryptWithAd(const [], message);
    } on NoiseSpikeException {
      _failed = true;
      rethrow;
    }
  }
}

class _X25519Pair {
  _X25519Pair(this.data, this.publicKey);

  final SimpleKeyPairData data;
  final Uint8List publicKey;

  static Future<_X25519Pair> fromPrivate(List<int> privateKey) async {
    final pair = await _x25519.newKeyPairFromSeed(privateKey);
    final data = await pair.extract();
    final pub = await pair.extractPublicKey();
    return _X25519Pair(data, Uint8List.fromList(pub.bytes));
  }
}

Uint8List _dh(_X25519Pair local, List<int> remotePublic) {
  final secret = _x25519.sharedSecretSync(
    keyPairData: local.data,
    remotePublicKey: SimplePublicKey(remotePublic, type: KeyPairType.x25519),
  );
  return Uint8List.fromList((secret as SecretKeyData).bytes);
}

const List<List<String>> _xxMessages = [
  ['e'],
  ['e', 'ee', 's', 'es'],
  ['s', 'se'],
];

/// Parses `Noise_XX[pskN[+pskM...]]_25519_ChaChaPoly_BLAKE2b` and returns the
/// psk positions, or throws for anything else.
List<int> parseXxProtocolName(String protocolName) {
  final match = RegExp(r'^Noise_XX((?:psk[0-3])(?:\+psk[0-3])*)?_25519_ChaChaPoly_BLAKE2b$').firstMatch(protocolName);
  if (match == null) throw NoiseSpikeException('unsupported protocol');
  final modifiers = match.group(1);
  if (modifiers == null) return const [];
  return modifiers.split('+').map((m) => int.parse(m.substring(3))).toList();
}

/// Noise handshake state for `XX` with optional psk modifiers.
class NoiseXxHandshake {
  NoiseXxHandshake._({
    required this.protocolName,
    required this.initiator,
    required _X25519Pair staticPair,
    required _X25519Pair? fixedEphemeral,
    required List<Uint8List> psks,
    required List<List<String>> pattern,
    required Uint8List? expectedRemoteStatic,
  })  : _s = staticPair,
        _fixedEphemeral = fixedEphemeral,
        _psks = psks,
        _pattern = pattern,
        _expectedRemoteStatic = expectedRemoteStatic,
        _ss = _SymmetricState(protocolName),
        _pskMode = pattern.any((m) => m.contains('psk'));

  /// Creates a handshake. [ephemeralPrivate] is for test vectors only; when
  /// absent a fresh ephemeral is generated. [expectedRemoteStatic] makes the
  /// handshake fail as soon as the peer reveals a different static key.
  static Future<NoiseXxHandshake> create({
    required String protocolName,
    required bool initiator,
    required List<int> staticPrivate,
    List<int>? ephemeralPrivate,
    List<int> prologue = const [],
    List<List<int>> psks = const [],
    List<int>? expectedRemoteStatic,
  }) async {
    final positions = parseXxProtocolName(protocolName);
    if (psks.length != positions.length) throw NoiseSpikeException('psk count mismatch');
    for (final psk in psks) {
      if (psk.length != 32) throw NoiseSpikeException('psk must be 32 bytes');
    }
    final pattern = _xxMessages.map((m) => List<String>.of(m)).toList();
    for (final pos in positions) {
      if (pos == 0) {
        pattern[0].insert(0, 'psk');
      } else {
        pattern[pos - 1].add('psk');
      }
    }
    final hs = NoiseXxHandshake._(
      protocolName: protocolName,
      initiator: initiator,
      staticPair: await _X25519Pair.fromPrivate(staticPrivate),
      fixedEphemeral: ephemeralPrivate == null ? null : await _X25519Pair.fromPrivate(ephemeralPrivate),
      psks: psks.map(Uint8List.fromList).toList(),
      pattern: pattern,
      expectedRemoteStatic: expectedRemoteStatic == null ? null : Uint8List.fromList(expectedRemoteStatic),
    );
    hs._ss.mixHash(prologue);
    return hs;
  }

  final String protocolName;
  final bool initiator;
  final _X25519Pair _s;
  final _X25519Pair? _fixedEphemeral;
  final List<Uint8List> _psks;
  final List<List<String>> _pattern;
  final Uint8List? _expectedRemoteStatic;
  final _SymmetricState _ss;
  final bool _pskMode;

  _X25519Pair? _e;
  Uint8List? _re;
  Uint8List? _rs;
  int _messageIndex = 0;
  int _pskIndex = 0;
  bool _failed = false;

  bool get isComplete => _messageIndex >= _pattern.length;

  Uint8List get handshakeHash => Uint8List.fromList(_ss.h);

  bool get _myTurn => (_messageIndex % 2 == 0) == initiator;

  void _checkCanProceed({required bool writing}) {
    if (_failed) throw NoiseSpikeException('handshake failed earlier');
    if (isComplete) throw NoiseSpikeException('handshake already complete');
    if (_myTurn != writing) throw NoiseSpikeException('unexpected message order');
  }

  Uint8List _dhFor(String token) {
    // es: initiator DH(e, rs), responder DH(s, re); se is the mirror image.
    switch (token) {
      case 'ee':
        return _dh(_e!, _re!);
      case 'es':
        return initiator ? _dh(_e!, _rs!) : _dh(_s, _re!);
      case 'se':
        return initiator ? _dh(_s, _re!) : _dh(_e!, _rs!);
    }
    throw StateError('unknown DH token $token');
  }

  Future<Uint8List> writeMessage(List<int> payload) async {
    _checkCanProceed(writing: true);
    try {
      final out = BytesBuilder(copy: false);
      for (final token in _pattern[_messageIndex]) {
        switch (token) {
          case 'e':
            _e = _fixedEphemeral ?? await _X25519Pair.fromPrivate(SecretKeyData.random(length: 32).bytes);
            out.add(_e!.publicKey);
            _ss.mixHash(_e!.publicKey);
            if (_pskMode) _ss.mixKey(_e!.publicKey);
          case 's':
            out.add(_ss.encryptAndHash(_s.publicKey));
          case 'psk':
            _ss.mixKeyAndHash(_psks[_pskIndex++]);
          default:
            _ss.mixKey(_dhFor(token));
        }
      }
      out.add(_ss.encryptAndHash(payload));
      _messageIndex++;
      return out.takeBytes();
    } catch (_) {
      _failed = true;
      rethrow;
    }
  }

  Future<Uint8List> readMessage(List<int> message) async {
    _checkCanProceed(writing: false);
    try {
      var offset = 0;
      Uint8List take(int n) {
        if (message.length - offset < n) throw NoiseSpikeException('message too short');
        final part = Uint8List.fromList(message.sublist(offset, offset + n));
        offset += n;
        return part;
      }

      for (final token in _pattern[_messageIndex]) {
        switch (token) {
          case 'e':
            _re = take(_dhLen);
            _ss.mixHash(_re!);
            if (_pskMode) _ss.mixKey(_re!);
          case 's':
            _rs = _ss.decryptAndHash(take(_ss.cs.hasKey ? _dhLen + _tagLen : _dhLen));
            final expected = _expectedRemoteStatic;
            if (expected != null && !_constantTimeEquals(expected, _rs!)) {
              throw NoiseSpikeException('unexpected remote static key');
            }
          case 'psk':
            _ss.mixKeyAndHash(_psks[_pskIndex++]);
          default:
            _ss.mixKey(_dhFor(token));
        }
      }
      final payload = _ss.decryptAndHash(message.sublist(offset));
      _messageIndex++;
      return payload;
    } catch (_) {
      _failed = true;
      rethrow;
    }
  }

  /// Splits into transport CipherStates once the handshake is complete.
  NoiseTransport split() {
    if (_failed || !isComplete) throw NoiseSpikeException('handshake not complete');
    final pair = _ss.split();
    final send = initiator ? pair[0] : pair[1];
    final recv = initiator ? pair[1] : pair[0];
    return NoiseTransport._(send, recv, handshakeHash, Uint8List.fromList(_rs!));
  }
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
