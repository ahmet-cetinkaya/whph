/// Commit-reveal short authentication string for LAN-scan / manual pairing
/// over `Noise_XX` (D7, FR-024).
///
/// Protocol (`h` = Noise handshake hash, `Na`/`Nb` = 32 random bytes):
///
/// ```text
/// responder → initiator   Commit  C = H_commit(h, Nb)
/// initiator → responder   Nonce   Na
/// responder → initiator   Reveal  Nb         (never before Na is received)
/// initiator               abort unless H_commit(h, Nb) == C
/// both                    code = digits(H_code(h, Na, Nb))
/// both → peer             Confirm (after the user confirms) or Abort
/// ```
///
/// `H_commit(h, Nb) = BLAKE2b-256(str "whph-sync/sas-commit/v1" ‖ bytes h ‖
/// bytes Nb)` and `H_code(h, Na, Nb) = BLAKE2b-256(str "whph-sync/sas-code/v1"
/// ‖ bytes h ‖ bytes Na ‖ bytes Nb)`. Because the responder commits to `Nb`
/// before it sees `Na`, and the initiator picks `Na` before it sees `Nb`, a
/// man in the middle running two sessions (two different `h`) cannot choose
/// values that make both codes equal except by chance: `10^-6` per attempt.
///
/// The code is the first 8 bytes of `H_code` as an unsigned big-endian
/// integer, reduced modulo `10^digits`. The modulo bias is below
/// `10^6 / 2^64 < 6 * 10^-14` (negligible, documented instead of rejection
/// sampling).
///
/// Pairing completes only when both users confirm; a mismatch, cancel or any
/// protocol violation aborts, and the aborting side sends [SasAbort] so the
/// other side aborts too.
library;

import 'dart:typed_data';

import 'primitives.dart';

/// Domain of the commitment hash.
const sasCommitDomain = 'whph-sync/sas-commit/v1';

/// Domain of the code hash.
const sasCodeDomain = 'whph-sync/sas-code/v1';

/// Length of `Na`, `Nb` and `C`.
const sasNonceLength = 32;

/// Number of SAS digits shown on screen.
const sasDigits = 6;

/// `H_commit(h, Nb)`.
Uint8List sasCommitment(List<int> handshakeHash, List<int> nb) => domainHash256(sasCommitDomain, [handshakeHash, nb]);

/// The decimal code of `(h, Na, Nb)` with [digits] digits (zero-padded).
/// Production uses [sasDigits]; fewer digits exist only for statistical tests.
String sasCode(List<int> handshakeHash, List<int> na, List<int> nb, {int digits = sasDigits}) {
  if (digits < 1 || digits > 18) throw ArgumentError.value(digits, 'digits');
  final hash = domainHash256(sasCodeDomain, [handshakeHash, na, nb]);
  var value = BigInt.zero;
  for (var i = 0; i < 8; i++) {
    value = (value << 8) | BigInt.from(hash[i]);
  }
  final mod = BigInt.from(10).pow(digits);
  return (value % mod).toString().padLeft(digits, '0');
}

// --- Messages -----------------------------------------------------------------

/// A SAS protocol message. Wire form: `u8 kind ‖ payload` (32 bytes for
/// commit/nonce/reveal, empty for confirm/abort).
sealed class SasMessage {
  const SasMessage();

  int get _kind;

  List<int> get _payload => const [];

  Uint8List encode() => Uint8List.fromList([_kind, ..._payload]);

  /// Decodes [bytes]; throws [SasException] when malformed.
  static SasMessage decode(List<int> bytes) {
    if (bytes.isEmpty) throw const SasException('empty SAS message');
    final body = bytes.sublist(1);
    Uint8List nonce() {
      if (body.length != sasNonceLength) throw const SasException('SAS value must be 32 bytes');
      return Uint8List.fromList(body);
    }

    void empty() {
      if (body.isNotEmpty) throw const SasException('unexpected SAS payload');
    }

    switch (bytes[0]) {
      case 1:
        return SasCommit(nonce());
      case 2:
        return SasNonce(nonce());
      case 3:
        return SasReveal(nonce());
      case 4:
        empty();
        return const SasConfirm();
      case 5:
        empty();
        return const SasAbort();
    }
    throw const SasException('unknown SAS message');
  }
}

/// Responder's commitment `C`.
final class SasCommit extends SasMessage {
  SasCommit(List<int> c) : c = Uint8List.fromList(c);
  final Uint8List c;
  @override
  int get _kind => 1;
  @override
  List<int> get _payload => c;
  @override
  String toString() => 'SasCommit';
}

/// Initiator's nonce `Na`.
final class SasNonce extends SasMessage {
  SasNonce(List<int> na) : na = Uint8List.fromList(na);
  final Uint8List na;
  @override
  int get _kind => 2;
  @override
  List<int> get _payload => na;
  @override
  String toString() => 'SasNonce';
}

/// Responder's revealed nonce `Nb`.
final class SasReveal extends SasMessage {
  SasReveal(List<int> nb) : nb = Uint8List.fromList(nb);
  final Uint8List nb;
  @override
  int get _kind => 3;
  @override
  List<int> get _payload => nb;
  @override
  String toString() => 'SasReveal';
}

/// The local user confirmed that the codes match.
final class SasConfirm extends SasMessage {
  const SasConfirm();
  @override
  int get _kind => 4;
  @override
  String toString() => 'SasConfirm';
}

/// The sender aborted (mismatch, cancel or protocol violation).
final class SasAbort extends SasMessage {
  const SasAbort();
  @override
  int get _kind => 5;
  @override
  String toString() => 'SasAbort';
}

// --- State machines -------------------------------------------------------------

/// Progress of a SAS exchange.
enum SasState {
  /// Responder: not started. Initiator: waiting for the commitment.
  awaitingCommit,

  /// Responder: commitment sent, waiting for `Na`.
  awaitingNonce,

  /// Initiator: `Na` sent, waiting for `Nb`.
  awaitingReveal,

  /// Code available; waiting for both confirmations.
  comparing,

  /// Both sides confirmed.
  confirmed,

  /// Aborted on this side (terminal).
  aborted,
}

/// Shared confirmation logic of both roles.
abstract base class _SasBase {
  _SasBase(List<int> handshakeHash, this._digits) : _h = Uint8List.fromList(handshakeHash) {
    if (_h.isEmpty) throw ArgumentError.value(_h.length, 'handshakeHash');
    if (_digits < 1 || _digits > 18) throw ArgumentError.value(_digits, 'digits');
  }

  final Uint8List _h;
  final int _digits;
  SasState _state = SasState.awaitingCommit;
  String? _code;
  bool _localConfirmed = false;
  bool _peerConfirmed = false;

  SasState get state => _state;

  /// The code to display, once both nonces are known (and never after an
  /// abort).
  String? get code => _state == SasState.comparing || _state == SasState.confirmed ? _code : null;

  bool get isConfirmed => _state == SasState.confirmed;
  bool get isAborted => _state == SasState.aborted;

  /// Aborts locally and returns the [SasAbort] to send (or nothing when
  /// already terminal-aborted).
  List<SasMessage> abort() {
    if (_state == SasState.aborted) return const [];
    _setAborted();
    return const [SasAbort()];
  }

  /// The user confirmed that both screens show the same code. Idempotent:
  /// a repeated confirmation (already confirmed locally, or completed) sends
  /// nothing and changes nothing.
  List<SasMessage> confirm() {
    if (_state == SasState.confirmed || (_state == SasState.comparing && _localConfirmed)) return const [];
    if (_state != SasState.comparing) return abort();
    _localConfirmed = true;
    _maybeComplete();
    return const [SasConfirm()];
  }

  /// The user said the codes differ, or cancelled.
  List<SasMessage> reject() => abort();

  /// Handles a received message and returns the messages to send.
  List<SasMessage> receive(SasMessage message) {
    if (_state == SasState.aborted) return const [];
    if (message is SasAbort) {
      _setAborted();
      return const [];
    }
    if (message is SasConfirm) {
      // A repeated peer confirmation carries no new information.
      if (_state == SasState.confirmed || (_state == SasState.comparing && _peerConfirmed)) return const [];
      if (_state != SasState.comparing) return abort();
      _peerConfirmed = true;
      _maybeComplete();
      return const [];
    }
    return _receiveProtocol(message);
  }

  List<SasMessage> _receiveProtocol(SasMessage message);

  void _maybeComplete() {
    if (_localConfirmed && _peerConfirmed) _state = SasState.confirmed;
  }

  void _setAborted() {
    _state = SasState.aborted;
    _code = null;
    _clear();
  }

  void _clear();

  /// Never prints the code or nonces.
  @override
  String toString() => '$runtimeType($_state)';
}

/// The Noise responder's side: commits to `Nb`, reveals it only after `Na`.
/// Always shows [sasDigits] digits.
final class SasResponder extends _SasBase {
  SasResponder(List<int> handshakeHash) : super(handshakeHash, sasDigits);

  SasResponder._withDigits(super.handshakeHash, super.digits);

  Uint8List? _nb;

  /// Starts the exchange: draws `Nb` and returns the [SasCommit].
  List<SasMessage> start() {
    if (_state != SasState.awaitingCommit || _nb != null) return abort();
    _nb = secureRandomBytes(sasNonceLength);
    _state = SasState.awaitingNonce;
    return [SasCommit(sasCommitment(_h, _nb!))];
  }

  @override
  List<SasMessage> _receiveProtocol(SasMessage message) {
    // Only `Na`, only once, only after the commitment went out.
    if (message is! SasNonce || _state != SasState.awaitingNonce) return abort();
    final nb = _nb!;
    _code = sasCode(_h, message.na, nb, digits: _digits);
    _state = SasState.comparing;
    return [SasReveal(nb)];
  }

  @override
  void _clear() => zeroize(_nb);
}

/// The Noise initiator's side: sends `Na` after the commitment, verifies the
/// revealed `Nb` against it. Always shows [sasDigits] digits.
final class SasInitiator extends _SasBase {
  SasInitiator(List<int> handshakeHash) : super(handshakeHash, sasDigits);

  SasInitiator._withDigits(super.handshakeHash, super.digits);

  Uint8List? _commitment;
  Uint8List? _na;

  @override
  List<SasMessage> _receiveProtocol(SasMessage message) {
    switch (message) {
      case SasCommit(:final c) when _state == SasState.awaitingCommit:
        _commitment = Uint8List.fromList(c);
        _na = secureRandomBytes(sasNonceLength);
        _state = SasState.awaitingReveal;
        return [SasNonce(_na!)];
      case SasReveal(:final nb) when _state == SasState.awaitingReveal:
        if (!constantTimeEquals(sasCommitment(_h, nb), _commitment!)) return abort();
        _code = sasCode(_h, _na!, nb, digits: _digits);
        _state = SasState.comparing;
        return const [];
      default:
        return abort();
    }
  }

  @override
  void _clear() => zeroize(_na);
}

/// TEST ONLY — hidden from `package:whph_sync_core/whph_sync_core.dart`.
///
/// A [SasInitiator] showing [digits] digits (fewer than [sasDigits] only for
/// the statistical MITM test). Production code must use [SasInitiator.new].
SasInitiator createSasInitiatorForTesting(List<int> handshakeHash, {required int digits}) =>
    SasInitiator._withDigits(handshakeHash, digits);

/// TEST ONLY — hidden from `package:whph_sync_core/whph_sync_core.dart`.
///
/// A [SasResponder] showing [digits] digits (see
/// [createSasInitiatorForTesting]). Production code must use
/// [SasResponder.new].
SasResponder createSasResponderForTesting(List<int> handshakeHash, {required int digits}) =>
    SasResponder._withDigits(handshakeHash, digits);
