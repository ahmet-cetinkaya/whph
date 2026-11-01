/// Noise (revision 34) `XX` and `XXpsk3` for `25519_ChaChaPoly_BLAKE2b` (D7).
///
/// * Sessions use `Noise_XX_25519_ChaChaPoly_BLAKE2b`; QR pairing uses
///   `Noise_XXpsk3_25519_ChaChaPoly_BLAKE2b` with the PSK derived from the
///   128-bit QR token by [derivePairingPsk].
/// * Every handshake and transport message is at most [noiseMaxMessageLength]
///   (65535) bytes; larger messages are rejected on write and on read.
/// * An all-zero DH output (low-order peer key) aborts the handshake.
/// * Payloads of handshake messages 1 and 2 must be empty: message 1 is sent
///   in clear, message 2 goes to a not yet authenticated initiator, and in
///   `XXpsk3` neither is covered by the PSK. Only message 3 (and transport
///   messages) may carry data.
/// * The remote static key is checked as soon as it is decrypted, before this
///   side writes anything else: the `XXpsk3` initiator (QR scanner) compares
///   it with the QR fingerprint before writing message 3; `XX` callers pass
///   [RemoteStaticCheck] (membership, D7).
/// * Any exception tears the object down: key state is zeroed and every later
///   call throws [NoiseException].
/// * A handshake is not reentrant: calling [NoiseHandshake.writeMessage] or
///   [NoiseHandshake.readMessage] while a `writeMessage` is still pending
///   tears the handshake down (both calls fail).
/// * After [NoiseHandshake.split] the handshake's key state is zeroed.
///
/// The fixed-ephemeral and arbitrary-`pskN` entry point used by the test
/// vectors is [createNoiseHandshakeForTesting]; it is hidden from the package
/// export and must not be used by production code.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'primitives.dart';

/// Session protocol name (D7).
const noiseProtocolXx = 'Noise_XX_25519_ChaChaPoly_BLAKE2b';

/// QR pairing protocol name (D7).
const noiseProtocolXxPsk3 = 'Noise_XXpsk3_25519_ChaChaPoly_BLAKE2b';

/// Noise maximum message length (spec §3).
const noiseMaxMessageLength = 65535;

/// Largest transport payload: [noiseMaxMessageLength] minus the AEAD tag.
/// Larger application frames must be split by the caller (T12).
const noiseMaxTransportPayload = noiseMaxMessageLength - aeadTagLength;

/// Default Noise prologue (domain separation of WHPH sessions).
const noisePrologueDomain = 'whph-sync/noise/v1';

/// Domain of [derivePairingPsk].
const pairingPskDomain = 'whph-sync/pairing-psk/v1';

/// Domain of [x25519Fingerprint].
const x25519FingerprintDomain = 'whph-sync/x25519-fingerprint/v1';

/// Length of a QR pairing token (128 bits).
const pairingTokenLength = 16;

/// Length of a Noise PSK.
const noisePskLength = 32;

/// Decides whether the peer's static key is acceptable (e.g. belongs to a
/// non-revoked member). Called once, right after the key is decrypted and
/// **before** the peer has proven possession of it (that happens when the
/// rest of the message authenticates). Use it only to reject; any side effect
/// (address-list correction, "needs re-pairing" marking) must wait for a
/// completed handshake and use [NoiseSession.remoteStatic].
typedef RemoteStaticCheck = bool Function(Uint8List remoteStatic);

/// Derives the 32-byte `XXpsk3` PSK from a 128-bit QR token:
/// `BLAKE2b-256(str "whph-sync/pairing-psk/v1" ‖ bytes token)`.
Uint8List derivePairingPsk(List<int> token) {
  if (token.length != pairingTokenLength) {
    throw const InvalidKeyMaterialException('pairing token must be 16 bytes');
  }
  return domainHash256(pairingPskDomain, [token]);
}

/// Fingerprint of an X25519 static public key as shown in the QR code:
/// `BLAKE2b-256(str "whph-sync/x25519-fingerprint/v1" ‖ bytes pub)`.
Uint8List x25519Fingerprint(List<int> publicKey) {
  if (publicKey.length != keyLength) throw const InvalidKeyMaterialException('X25519 public key must be 32 bytes');
  return domainHash256(x25519FingerprintDomain, [publicKey]);
}

const int _dhLen = 32;
const int _hashLen = blake2b512Length;
const int _maxNonce = 0x7fffffffffffffff; // Dart ints are signed; 2^64-1 is reserved anyway.

/// Noise CipherState (ChaChaPoly: nonce = 4 zero bytes ‖ u64 LE counter).
final class _CipherState {
  Uint8List? _k;
  int _n = 0;

  bool get hasKey => _k != null;

  /// Takes ownership of [key].
  void initializeKey(Uint8List? key) {
    zeroize(_k);
    _k = key;
    _n = 0;
  }

  Uint8List _nonce() {
    final nonce = Uint8List(12);
    ByteData.sublistView(nonce).setUint64(4, _n, Endian.little);
    return nonce;
  }

  Uint8List encryptWithAd(List<int> ad, List<int> plaintext) {
    final k = _k;
    if (k == null) return Uint8List.fromList(plaintext);
    if (_n >= _maxNonce) throw const NoiseException('nonce exhausted');
    final out = chachaSeal(key: k, nonce: _nonce(), plaintext: plaintext, aad: ad);
    _n++;
    return out;
  }

  Uint8List decryptWithAd(List<int> ad, List<int> ciphertext) {
    final k = _k;
    if (k == null) return Uint8List.fromList(ciphertext);
    if (_n >= _maxNonce) throw const NoiseException('nonce exhausted');
    if (ciphertext.length < aeadTagLength) throw const NoiseException('ciphertext too short');
    final plain = chachaOpen(key: k, nonce: _nonce(), sealed: ciphertext, aad: ad);
    if (plain == null) throw const NoiseException('authentication failed');
    _n++;
    return plain;
  }

  void clear() {
    zeroize(_k);
    _k = null;
    _n = 0;
  }
}

final class _SymmetricState {
  _SymmetricState(String protocolName) {
    final nameBytes = ascii.encode(protocolName);
    if (nameBytes.length <= _hashLen) {
      h = Uint8List(_hashLen)..setRange(0, nameBytes.length, nameBytes);
    } else {
      h = blake2b512(nameBytes);
    }
    ck = Uint8List.fromList(h);
  }

  late Uint8List h;
  late Uint8List ck;
  final _CipherState cs = _CipherState();

  void mixKey(List<int> ikm) {
    final out = noiseHkdf(ck, ikm, 2);
    zeroize(ck);
    ck = out[0];
    // `sublist` is the only copy; ownership passes to the cipher state.
    cs.initializeKey(out[1].sublist(0, 32));
    zeroize(out[1]);
  }

  void mixHash(List<int> data) {
    final input = Uint8List(h.length + data.length)
      ..setRange(0, h.length, h)
      ..setRange(h.length, h.length + data.length, data);
    h = blake2b512(input);
  }

  void mixKeyAndHash(List<int> ikm) {
    final out = noiseHkdf(ck, ikm, 3);
    zeroize(ck);
    ck = out[0];
    mixHash(out[1]);
    zeroize(out[1]);
    cs.initializeKey(out[2].sublist(0, 32));
    zeroize(out[2]);
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

  (Uint8List, Uint8List) split() {
    final out = noiseHkdf(ck, const [], 2);
    final k1 = out[0].sublist(0, 32);
    final k2 = out[1].sublist(0, 32);
    zeroize(out[0]);
    zeroize(out[1]);
    return (k1, k2);
  }

  void clear() {
    zeroize(ck);
    zeroize(h);
    cs.clear();
  }
}

const List<List<String>> _xxMessages = [
  ['e'],
  ['e', 'ee', 's', 'es'],
  ['s', 'se'],
];

List<int> _parseXxProtocolName(String protocolName) {
  final match = RegExp(r'^Noise_XX((?:psk[0-3])(?:\+psk[0-3])*)?_25519_ChaChaPoly_BLAKE2b$').firstMatch(protocolName);
  if (match == null) throw const NoiseException('unsupported protocol');
  final modifiers = match.group(1);
  if (modifiers == null) return const [];
  return modifiers.split('+').map((m) => int.parse(m.substring(3))).toList();
}

/// A Noise `XX` / `XXpsk3` handshake in progress.
final class NoiseHandshake {
  NoiseHandshake._({
    required this.protocolName,
    required this.initiator,
    required X25519KeyPair staticKey,
    required X25519KeyPair? fixedEphemeral,
    required List<Uint8List> psks,
    required List<List<String>> pattern,
    required RemoteStaticCheck? remoteStaticCheck,
    required bool allowEarlyPayloads,
  })  : _s = staticKey,
        _e = fixedEphemeral,
        _fixedEphemeral = fixedEphemeral != null,
        _psks = psks,
        _pattern = pattern,
        _remoteStaticCheck = remoteStaticCheck,
        _allowEarlyPayloads = allowEarlyPayloads,
        _ss = _SymmetricState(protocolName),
        _pskMode = pattern.any((m) => m.contains('psk'));

  /// A `Noise_XX` session handshake. [staticKey] stays owned by the caller
  /// (not destroyed here). [acceptRemoteStatic] must return `true` for the
  /// peer's static key or the handshake fails before this side sends
  /// anything else (D7 membership check).
  static Future<NoiseHandshake> xx({
    required bool initiator,
    required X25519KeyPair staticKey,
    required RemoteStaticCheck acceptRemoteStatic,
    List<int>? prologue,
  }) =>
      _create(
        protocolName: noiseProtocolXx,
        initiator: initiator,
        staticKey: staticKey,
        prologue: prologue,
        psks: const [],
        remoteStaticCheck: acceptRemoteStatic,
        allowEarlyPayloads: false,
      );

  /// A `Noise_XXpsk3` QR pairing handshake with [psk] from
  /// [derivePairingPsk] (copied; zeroed at teardown/split).
  ///
  /// The initiator (scanner) must pass [expectedResponderFingerprint] from
  /// the QR code; the responder's static key is compared with it as soon as
  /// message 2 is decrypted, so message 3 is never written to a wrong
  /// responder. The responder may pass [acceptRemoteStatic].
  static Future<NoiseHandshake> xxPsk3({
    required bool initiator,
    required X25519KeyPair staticKey,
    required List<int> psk,
    List<int>? expectedResponderFingerprint,
    RemoteStaticCheck? acceptRemoteStatic,
    List<int>? prologue,
  }) async {
    if (psk.length != noisePskLength) throw const NoiseException('psk must be 32 bytes');
    RemoteStaticCheck? check = acceptRemoteStatic;
    if (initiator) {
      final fp = expectedResponderFingerprint;
      if (fp == null || fp.length != 32) throw const NoiseException('scanner needs the 32-byte QR fingerprint');
      final expected = Uint8List.fromList(fp);
      check = (rs) {
        if (!constantTimeEquals(x25519Fingerprint(rs), expected)) return false;
        return acceptRemoteStatic?.call(rs) ?? true;
      };
    } else if (expectedResponderFingerprint != null) {
      throw const NoiseException('only the initiator checks a responder fingerprint');
    }
    return _create(
      protocolName: noiseProtocolXxPsk3,
      initiator: initiator,
      staticKey: staticKey,
      prologue: prologue,
      psks: [psk],
      remoteStaticCheck: check,
      allowEarlyPayloads: false,
    );
  }

  static Future<NoiseHandshake> _create({
    required String protocolName,
    required bool initiator,
    required X25519KeyPair staticKey,
    required List<int>? prologue,
    required List<List<int>> psks,
    required RemoteStaticCheck? remoteStaticCheck,
    required bool allowEarlyPayloads,
    List<int>? ephemeralPrivate,
  }) async {
    final positions = _parseXxProtocolName(protocolName);
    if (psks.length != positions.length) throw const NoiseException('psk count mismatch');
    for (final psk in psks) {
      if (psk.length != noisePskLength) throw const NoiseException('psk must be 32 bytes');
    }
    if (staticKey.isDestroyed) throw const NoiseException('static key destroyed');
    final pattern = _xxMessages.map((m) => List<String>.of(m)).toList();
    for (final pos in positions) {
      if (pos == 0) {
        pattern[0].insert(0, 'psk');
      } else {
        pattern[pos - 1].add('psk');
      }
    }
    final hs = NoiseHandshake._(
      protocolName: protocolName,
      initiator: initiator,
      staticKey: staticKey,
      fixedEphemeral: ephemeralPrivate == null ? null : await X25519KeyPair.fromPrivateKey(ephemeralPrivate),
      psks: psks.map(Uint8List.fromList).toList(),
      pattern: pattern,
      remoteStaticCheck: remoteStaticCheck,
      allowEarlyPayloads: allowEarlyPayloads,
    );
    hs._ss.mixHash(prologue ?? utf8.encode(noisePrologueDomain));
    return hs;
  }

  final String protocolName;
  final bool initiator;
  final X25519KeyPair _s;
  final bool _fixedEphemeral;
  final List<Uint8List> _psks;
  final List<List<String>> _pattern;
  final RemoteStaticCheck? _remoteStaticCheck;
  final bool _allowEarlyPayloads;
  final _SymmetricState _ss;
  final bool _pskMode;

  X25519KeyPair? _e;
  Uint8List? _re;
  Uint8List? _rs;
  int _messageIndex = 0;
  int _pskIndex = 0;
  bool _failed = false;
  bool _split = false;
  bool _busy = false;

  /// All three messages were processed successfully.
  bool get isComplete => !_failed && _messageIndex >= _pattern.length;

  /// Whether the handshake failed (and was torn down).
  bool get hasFailed => _failed;

  /// `true` once a psk-mode handshake completed. Its meaning differs by
  /// role:
  /// * **responder** (QR shower): message 3, encrypted under the PSK, was
  ///   read and authenticated — the peer proved knowledge of the token. This
  ///   is what `PairingToken.consume` relies on.
  /// * **initiator** (scanner): only "message 3 was written". Nothing the
  ///   initiator has received so far depends on the PSK; its assurance comes
  ///   from the QR fingerprint check on the responder's static key and from
  ///   the first transport message it successfully decrypts.
  ///
  /// Always `false` for plain `XX`.
  bool get pskVerified => _pskMode && isComplete;

  /// The peer's static key, once received.
  Uint8List? get remoteStatic => _rs == null ? null : Uint8List.fromList(_rs!);

  /// Current handshake hash `h` (copy).
  Uint8List get handshakeHash {
    if (_failed || _split) throw const NoiseException('handshake state cleared');
    return Uint8List.fromList(_ss.h);
  }

  bool get _myTurn => (_messageIndex % 2 == 0) == initiator;

  void _checkCanProceed({required bool writing}) {
    if (_failed) throw const NoiseException('handshake torn down');
    if (_busy) {
      _teardown();
      throw const NoiseException('concurrent handshake call');
    }
    if (_split || _messageIndex >= _pattern.length) throw const NoiseException('handshake already complete');
    if (_myTurn != writing) {
      _teardown();
      throw const NoiseException('unexpected message order');
    }
  }

  Uint8List _dhFor(String token) {
    // es: initiator DH(e, rs), responder DH(s, re); se is the mirror image.
    final e = _e;
    if (e == null) throw const NoiseException('missing ephemeral');
    Uint8List need(Uint8List? k) => k ?? (throw const NoiseException('missing remote key'));
    switch (token) {
      case 'ee':
        return x25519(e, need(_re));
      case 'es':
        return initiator ? x25519(e, need(_rs)) : x25519(_s, need(_re));
      case 'se':
        return initiator ? x25519(_s, need(_re)) : x25519(e, need(_rs));
    }
    throw const NoiseException('unknown token');
  }

  void _mixDh(String token) {
    final dh = _dhFor(token);
    _ss.mixKey(dh);
    zeroize(dh);
  }

  void _checkRemoteStatic() {
    final check = _remoteStaticCheck;
    if (check != null && !check(Uint8List.fromList(_rs!))) {
      throw const NoiseException('remote static key not accepted');
    }
  }

  bool get _earlyMessage => _messageIndex < 2;

  /// Writes the next handshake message carrying [payload] (must be empty for
  /// messages 1 and 2).
  Future<Uint8List> writeMessage([List<int> payload = const []]) async {
    _checkCanProceed(writing: true);
    _busy = true;
    try {
      if (_earlyMessage && payload.isNotEmpty && !_allowEarlyPayloads) {
        throw const NoiseException('handshake messages 1 and 2 must not carry a payload');
      }
      final out = BytesBuilder(copy: false);
      for (final token in _pattern[_messageIndex]) {
        switch (token) {
          case 'e':
            if (!_fixedEphemeral) {
              _e?.destroy();
              final e = await X25519KeyPair.generate();
              // Torn down while suspended (reentry, close): never continue.
              if (_failed) {
                e.destroy();
                throw const NoiseException('handshake torn down');
              }
              _e = e;
            }
            final pub = _e!.publicKey;
            out.add(pub);
            _ss.mixHash(pub);
            if (_pskMode) _ss.mixKey(pub);
          case 's':
            out.add(_ss.encryptAndHash(_s.publicKey));
          case 'psk':
            _ss.mixKeyAndHash(_psks[_pskIndex++]);
          default:
            _mixDh(token);
        }
      }
      out.add(_ss.encryptAndHash(payload));
      final message = out.takeBytes();
      if (message.length > noiseMaxMessageLength) throw const NoiseException('message exceeds 65535 bytes');
      _messageIndex++;
      return message;
    } catch (e) {
      _teardown();
      throw _wrap(e);
    } finally {
      _busy = false;
    }
  }

  /// Reads the next handshake message and returns its payload.
  Future<Uint8List> readMessage(List<int> message) async {
    _checkCanProceed(writing: false);
    try {
      if (message.length > noiseMaxMessageLength) throw const NoiseException('message exceeds 65535 bytes');
      var offset = 0;
      Uint8List take(int n) {
        if (message.length - offset < n) throw const NoiseException('message too short');
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
            _rs = _ss.decryptAndHash(take(_ss.cs.hasKey ? _dhLen + aeadTagLength : _dhLen));
            _checkRemoteStatic();
          case 'psk':
            _ss.mixKeyAndHash(_psks[_pskIndex++]);
          default:
            _mixDh(token);
        }
      }
      final payload = _ss.decryptAndHash(message.sublist(offset));
      if (_earlyMessage && payload.isNotEmpty && !_allowEarlyPayloads) {
        throw const NoiseException('handshake messages 1 and 2 must not carry a payload');
      }
      _messageIndex++;
      return payload;
    } catch (e) {
      _teardown();
      throw _wrap(e);
    }
  }

  /// Splits into a transport session once the handshake is complete, then
  /// zeroes the handshake's key state (the handshake hash is kept by the
  /// session for SAS).
  NoiseSession split() {
    if (_failed) throw const NoiseException('handshake torn down');
    if (_split || !isComplete) throw const NoiseException('handshake not complete');
    final (k1, k2) = _ss.split();
    final session = NoiseSession._(
      send: _CipherState()..initializeKey(initiator ? k1 : k2),
      recv: _CipherState()..initializeKey(initiator ? k2 : k1),
      handshakeHash: Uint8List.fromList(_ss.h),
      remoteStatic: Uint8List.fromList(_rs!),
    );
    _split = true;
    _clearKeys();
    return session;
  }

  /// Abandons the handshake and zeroes its key state.
  void close() => _teardown();

  void _teardown() {
    _failed = true;
    _clearKeys();
  }

  void _clearKeys() {
    _ss.clear();
    _e?.destroy();
    for (final p in _psks) {
      zeroize(p);
    }
  }

  static Object _wrap(Object e) => e is SyncCryptoException ? e : const NoiseException('handshake failed');

  /// Never prints key bytes.
  @override
  String toString() => 'NoiseHandshake($protocolName, ${initiator ? 'initiator' : 'responder'}, '
      'message $_messageIndex${_failed ? ', failed' : ''})';
}

/// A split Noise transport: one CipherState per direction. Replayed,
/// reordered, reflected or altered messages fail authentication; the first
/// failure (or any other error) tears the session down.
final class NoiseSession {
  NoiseSession._({
    required _CipherState send,
    required _CipherState recv,
    required Uint8List handshakeHash,
    required this.remoteStatic,
  })  : _send = send,
        _recv = recv,
        _handshakeHash = handshakeHash;

  final _CipherState _send;
  final _CipherState _recv;
  final Uint8List _handshakeHash;

  /// The peer's authenticated X25519 static key.
  final Uint8List remoteStatic;
  bool _closed = false;

  bool get isClosed => _closed;

  /// The Noise handshake hash `h` (input of the SAS, D7). Not secret, but
  /// unique per session.
  Uint8List get handshakeHash {
    if (_closed) throw const NoiseException('session torn down');
    return Uint8List.fromList(_handshakeHash);
  }

  /// Encrypts one transport message (payload ≤ [noiseMaxTransportPayload]).
  Uint8List encrypt(List<int> payload) {
    if (_closed) throw const NoiseException('session torn down');
    try {
      if (payload.length > noiseMaxTransportPayload) throw const NoiseException('message exceeds 65535 bytes');
      return _send.encryptWithAd(const [], payload);
    } catch (e) {
      close();
      throw e is SyncCryptoException ? e : const NoiseException('encrypt failed');
    }
  }

  /// Decrypts the next inbound transport message.
  Uint8List decrypt(List<int> message) {
    if (_closed) throw const NoiseException('session torn down');
    try {
      if (message.length > noiseMaxMessageLength) throw const NoiseException('message exceeds 65535 bytes');
      return _recv.decryptWithAd(const [], message);
    } catch (e) {
      close();
      throw e is SyncCryptoException ? e : const NoiseException('decrypt failed');
    }
  }

  /// Zeroes both transport keys; later calls throw.
  void close() {
    _closed = true;
    _send.clear();
    _recv.clear();
  }

  /// Never prints key bytes.
  @override
  String toString() => 'NoiseSession(${_closed ? 'closed' : 'open'})';
}

/// TEST ONLY — hidden from `package:whph_sync_core/whph_sync_core.dart`.
/// Referencing it anywhere under `lib/` (other than this file and the
/// export's `hide`) or in the app fails the source-rule test in
/// `test/crypto/noise_negative_test.dart`.
///
/// Creates a handshake for any `Noise_XX[pskN...]_25519_ChaChaPoly_BLAKE2b`
/// name with a fixed ephemeral key and payloads allowed in every message, as
/// the published test vectors require. Production code must use
/// [NoiseHandshake.xx] or [NoiseHandshake.xxPsk3].
Future<NoiseHandshake> createNoiseHandshakeForTesting({
  required String protocolName,
  required bool initiator,
  required X25519KeyPair staticKey,
  List<int>? ephemeralPrivate,
  List<int> prologue = const [],
  List<List<int>> psks = const [],
  RemoteStaticCheck? acceptRemoteStatic,
}) =>
    NoiseHandshake._create(
      protocolName: protocolName,
      initiator: initiator,
      staticKey: staticKey,
      prologue: prologue,
      psks: psks,
      remoteStaticCheck: acceptRemoteStatic,
      allowEarlyPayloads: true,
      ephemeralPrivate: ephemeralPrivate,
    );
