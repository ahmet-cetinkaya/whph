/// The QR pairing token and its single-use rule (D7, FR-025).
///
/// The token is 128 random bits, valid for 5 minutes after it is shown. It is
/// consumed **only** when an `XXpsk3` handshake on the showing side (the
/// responder) passes the psk3 check, i.e. the initiator's message 3 —
/// authenticated under the PSK derived from the token — was read
/// successfully. Failed attempts do not burn it (burning on any attempt would
/// let any LAN host deny pairing). Of several concurrent handshakes that pass,
/// only the first [PairingToken.consume] succeeds; the caller aborts the
/// others. The persistent single-use store is T20/T23.
///
/// There is no per-token (global) limit on concurrent handshakes (D7: a
/// global cap would let one LAN host deny pairing to everyone). The token
/// records which handshakes it started without holding them (an [Expando]),
/// so abandoned handshakes cost it nothing; memory and CPU per source are
/// bounded by the transport's connection limits and handshake timeouts (T22).
library;

import 'dart:typed_data';

import 'noise.dart';
import 'primitives.dart';

/// Validity of a shown QR code.
const pairingTokenTtl = Duration(minutes: 5);

/// Outcome of [PairingToken.consume].
enum PairingConsumeResult {
  /// The token was consumed by this handshake; pairing may proceed.
  consumed,

  /// Expired or already consumed (`pairing_code_expired_or_used`).
  expiredOrUsed,

  /// The handshake did not pass the psk3 check; the token stays usable.
  notVerified,
}

/// A shown QR pairing token (secret). [toString] never prints it.
final class PairingToken {
  PairingToken._(this._token, this.expiresAt);

  /// A fresh random token shown at [now].
  factory PairingToken.generate({required DateTime now}) =>
      PairingToken._(secureRandomBytes(pairingTokenLength), now.add(pairingTokenTtl));

  final Uint8List _token;

  /// End of validity.
  final DateTime expiresAt;
  bool _consumed = false;
  bool _destroyed = false;

  /// The token that started each responder handshake. Weak on the handshake
  /// (no strong reference, no cap, no eviction).
  static final Expando<PairingToken> _startedBy = Expando('PairingToken.startedBy');

  bool get isConsumed => _consumed;

  bool isUsable(DateTime now) => !_consumed && !_destroyed && now.isBefore(expiresAt);

  /// A copy of the token for the QR code; the caller zeroes it.
  Uint8List exportForQr() {
    if (_destroyed) throw StateError('token destroyed');
    return Uint8List.fromList(_token);
  }

  /// Starts a responder `XXpsk3` handshake keyed with this token's derived
  /// PSK, or returns `null` when the token is expired or used. Only
  /// handshakes started here can later [consume] the token. Any number of
  /// handshakes may be pending at once; none is ever evicted or closed here.
  Future<NoiseHandshake?> startResponderHandshake({
    required X25519KeyPair staticKey,
    required DateTime now,
    RemoteStaticCheck? acceptRemoteStatic,
    List<int>? prologue,
  }) async {
    if (!isUsable(now)) return null;
    final psk = derivePairingPsk(_token);
    try {
      final hs = await NoiseHandshake.xxPsk3(
        initiator: false,
        staticKey: staticKey,
        psk: psk,
        acceptRemoteStatic: acceptRemoteStatic,
        prologue: prologue,
      );
      _startedBy[hs] = this;
      return hs;
    } finally {
      zeroize(psk);
    }
  }

  /// Consumes the token for [handshake] when (and only when) it is a
  /// completed `XXpsk3` responder handshake that passed the psk3 check.
  PairingConsumeResult consume(NoiseHandshake handshake, DateTime now) {
    if (!isUsable(now)) return PairingConsumeResult.expiredOrUsed;
    if (!identical(_startedBy[handshake], this) ||
        handshake.initiator ||
        handshake.protocolName != noiseProtocolXxPsk3 ||
        handshake.hasFailed ||
        !handshake.pskVerified) {
      return PairingConsumeResult.notVerified;
    }
    _consumed = true;
    zeroize(_token);
    return PairingConsumeResult.consumed;
  }

  /// Zeroes the token (QR dismissed).
  void destroy() {
    _destroyed = true;
    zeroize(_token);
  }

  @override
  String toString() => 'PairingToken(<redacted>, ${_consumed ? 'consumed' : 'active'})';
}
