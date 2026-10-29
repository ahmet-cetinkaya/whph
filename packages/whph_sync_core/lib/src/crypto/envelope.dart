/// XChaCha20-Poly1305 change envelopes (D7, FR-021, FR-023, SC-014).
///
/// * Plaintext = `ChangeValue.encode()` of the change (T10).
/// * Key = the group key of the envelope's epoch (the highest held epoch when
///   sealing).
/// * AD = exactly `ChangeEnvelope.associatedData(groupId, protocolVersion)`
///   (T10): `(group_id, epoch, tbl, pk, col, hlc, origin, origin_seq, cause,
///   protocol_version)` with its own domain prefix. `protocol_version` is the
///   version the envelope was **sealed** under; it travels in the envelope
///   (`ChangeEnvelope.protocolVersion`) so relayed or held envelopes still
///   open after a protocol upgrade, and changing it fails authentication.
///   Relabelling an envelope
///   onto another cell, epoch, group, seq or cause therefore fails
///   authentication. `node` is not in the AD; it is bound by the signed
///   canonical-change hash in the manifest (T10 decision).
///
/// ## Nonces ([NonceSource])
///
/// Drawing 24 bytes from `Random.secure()` per change cost ~65 % of the
/// sender's CPU (S4). A [NonceSource] draws **one** 16-byte random prefix
/// from `Random.secure()` when created and emits
/// `nonce_i = prefix ‖ u64_be(i)` for `i = 0, 1, 2, …`.
///
/// Why nonces never repeat under one key:
/// * within one source, `i` strictly increases and the source refuses to
///   wrap (it throws at 2^63), so two nonces of one source always differ in
///   the counter half;
/// * two different sources differ in the prefix except with probability
///   `2^-128` per pair; even with 2^32 sources per epoch key the collision
///   probability stays below `2^-65` (birthday bound `n^2 / 2^129`), and a
///   prefix collision would additionally need equal counters.
/// XChaCha20 derives a subkey from the first 16 nonce bytes (HChaCha20) and
/// uses the remaining 8 as the ChaCha20 nonce, so this is equivalent to
/// using a random 128-bit-labelled subkey per source with a unique 64-bit
/// counter nonce — the standard safe use of XChaCha20. Sources must not be
/// shared across isolates or persisted and resumed (create one per session
/// or batch).
library;

import 'dart:typed_data';

import '../model/change.dart';
import '../model/envelope.dart';
import '../model/ids.dart';
import '../protocol/errors.dart';
import '../protocol/version.dart';
import 'epoch.dart';
import 'primitives.dart';

/// Unique 24-byte XChaCha20 nonces from one secure random prefix (see the
/// library documentation).
final class NonceSource {
  NonceSource() : _prefix = secureRandomBytes(_prefixLength);

  static const _prefixLength = 16;
  static const _maxCounter = 0x7fffffffffffffff;

  final Uint8List _prefix;
  int _counter = 0;

  /// Nonces emitted so far.
  int get issued => _counter;

  /// The next unique nonce.
  Uint8List next() {
    if (_counter >= _maxCounter) throw StateError('nonce source exhausted; create a new one');
    final nonce = Uint8List(envelopeNonceLength)..setRange(0, _prefixLength, _prefix);
    ByteData.sublistView(nonce).setUint64(_prefixLength, _counter++, Endian.big);
    return nonce;
  }

  /// Never prints the prefix.
  @override
  String toString() => 'NonceSource($_counter issued)';
}

/// Result of opening an envelope.
sealed class EnvelopeOpenResult {
  const EnvelopeOpenResult();
}

/// The envelope authenticated; [change] is the decrypted change.
final class EnvelopeOpened extends EnvelopeOpenResult {
  const EnvelopeOpened(this.change);

  final Change change;

  @override
  String toString() => 'EnvelopeOpened(${change.origin}#${change.originSeq})';
}

/// No key is held for [epoch]; the envelope is held unapplied
/// (`sync_held_envelope`, reason `missing_key`, D13) until a handover.
final class MissingEpochKey extends EnvelopeOpenResult {
  const MissingEpochKey(this.epoch);

  final EpochId epoch;

  @override
  String toString() => 'MissingEpochKey($epoch)';
}

/// Authentication failed or the plaintext is malformed; nothing is applied.
final class EnvelopeRejected extends EnvelopeOpenResult {
  const EnvelopeRejected(this.reason);

  /// Reason category; never contains key or plaintext bytes.
  final String reason;

  @override
  String toString() => 'EnvelopeRejected($reason)';
}

/// Seals and opens change envelopes for one group.
final class EnvelopeCipher {
  EnvelopeCipher({
    required this.groupId,
    required GroupKeyring keyring,
    this.protocolVersion = syncProtocolVersion,
  }) : _keyring = keyring;

  final GroupId groupId;
  final GroupKeyring _keyring;

  /// Protocol version this cipher seals under (written into the envelope and
  /// bound into its AD). Opening binds the envelope's own sealing version.
  final int protocolVersion;

  /// Encrypts [change] under [epoch] (default: the highest held epoch) with
  /// a nonce from [nonces]. Throws [StateError] when no key is held for the
  /// epoch (a sender never seals without a key), [ArgumentError] when the
  /// change belongs to another group.
  ChangeEnvelope seal(Change change, NonceSource nonces, {EpochId? epoch}) {
    if (change.groupId != groupId) throw ArgumentError.value(change.groupId, 'change.groupId', 'other group');
    final e = epoch ?? _keyring.highest;
    final key = e == null ? null : _keyring.keyFor(e);
    if (e == null || key == null) throw StateError('no key held for the sealing epoch');
    final nonce = nonces.next();
    final ad = envelopeAssociatedData(
      groupId: groupId,
      epoch: e,
      tbl: change.tbl,
      pk: change.pk,
      col: change.col,
      hlc: change.hlc,
      origin: change.origin,
      originSeq: change.originSeq,
      cause: change.cause,
      protocolVersion: protocolVersion,
    );
    final plaintext = change.value.encode();
    final ciphertext = xchachaSeal(key: key, nonce: nonce, plaintext: plaintext, aad: ad);
    zeroize(plaintext);
    return ChangeEnvelope.forChange(
      change,
      epoch: e,
      nonce: nonce,
      ciphertext: ciphertext,
      protocolVersion: protocolVersion,
    );
  }

  /// Decrypts [envelope]. Returns [MissingEpochKey] when its epoch key is not
  /// held, [EnvelopeRejected] when authentication fails (any relabelling,
  /// wrong key, altered bytes) or the plaintext is not a valid value.
  EnvelopeOpenResult open(ChangeEnvelope envelope) {
    final key = _keyring.keyFor(envelope.epoch);
    if (key == null) return MissingEpochKey(envelope.epoch);
    final ad = envelope.associatedData(groupId: groupId, protocolVersion: envelope.protocolVersion);
    final plaintext = xchachaOpen(key: key, nonce: envelope.nonce, sealed: envelope.ciphertext, aad: ad);
    if (plaintext == null) return const EnvelopeRejected('authentication failed');
    try {
      return EnvelopeOpened(envelope.toChange(groupId, ChangeValue.decode(plaintext)));
    } on SyncDecodeException {
      return const EnvelopeRejected('malformed plaintext');
    } on ArgumentError {
      return const EnvelopeRejected('malformed plaintext');
    } finally {
      zeroize(plaintext);
    }
  }

  @override
  String toString() => 'EnvelopeCipher($groupId)';
}
