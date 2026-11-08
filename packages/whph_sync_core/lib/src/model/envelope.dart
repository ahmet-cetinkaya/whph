/// Encrypted change envelopes and their AEAD associated data (D7).
///
/// The value travels only inside [ChangeEnvelope.ciphertext]
/// (XChaCha20-Poly1305, T11); every other field is metadata the receiver needs
/// before decrypting (routing, merge, manifest lookup).
///
/// Envelope wire form v1 (big-endian; `str` = `u32 len ‖ UTF-8`,
/// `bytes` = `u32 len ‖ bytes`):
///
/// ```text
/// str   tbl                table name
/// str   pk
/// str   col                column name
/// i64   hlc
/// str   node               author member id
/// 16B   origin
/// i64   origin_seq         >= 1
/// u8    cause marker       0 absent | 1 present ‖ str cause tbl ‖ str cause pk
/// i64   epoch counter      1 ..= 2^53
/// str   epoch creator      member id
/// u32   protocol_version   sealing protocol version (>= 1), bound in the AD
/// 24B   nonce              XChaCha20 nonce
/// bytes ciphertext         <= SyncLimits.maxEnvelopeCiphertextBytes
/// bytes key_wrap           reserved (D7); empty until the server change
/// ```
///
/// AEAD associated data v1:
///
/// ```text
/// str   "whph-sync/envelope-ad/v1"
/// 16B   group_id
/// i64   epoch counter
/// str   epoch creator
/// str   tbl
/// str   pk
/// str   col
/// i64   hlc
/// 16B   origin
/// i64   origin_seq
/// u8    cause marker (as above)
/// u32   protocol_version   the sealing version carried in the envelope
/// ```
///
/// The AD binds the protocol version the envelope was **sealed** under, which
/// travels in the envelope, so envelopes relayed or held across a protocol
/// upgrade still open; relabelling the version fails authentication.
library;

import 'dart:typed_data';

import '../protocol/errors.dart';
import '../protocol/version.dart';
import '../store/replica_store.dart';
import 'change.dart';
import 'ids.dart';
import 'wire_bytes.dart';

/// Domain-separation prefix of envelope associated data.
const envelopeAdDomain = 'whph-sync/envelope-ad/v1';

/// Length of an XChaCha20 nonce.
const envelopeNonceLength = 24;

/// Builds the D7 AEAD associated data
/// `(group_id, epoch, tbl name, pk, col name, hlc, origin id, origin_seq,
/// cause, protocol_version)`.
Uint8List envelopeAssociatedData({
  required GroupId groupId,
  required EpochId epoch,
  required String tbl,
  required String pk,
  required String col,
  required int hlc,
  required OriginId origin,
  required int originSeq,
  required RowRef? cause,
  required int protocolVersion,
}) {
  final w = ByteWriter()
    ..string(envelopeAdDomain)
    ..fixed(groupId.bytes)
    ..i64(epoch.counter)
    ..string(epoch.creator)
    ..string(tbl)
    ..string(pk)
    ..string(col)
    ..i64(hlc)
    ..fixed(origin.bytes)
    ..i64(originSeq);
  writeCause(w, cause);
  w.u32(protocolVersion);
  return w.take();
}

/// One encrypted change as carried in a change batch or held for relay.
final class ChangeEnvelope {
  ChangeEnvelope({
    required this.tbl,
    required this.pk,
    required this.col,
    required this.hlc,
    required this.node,
    required this.origin,
    required this.originSeq,
    this.cause,
    required this.epoch,
    required List<int> nonce,
    required List<int> ciphertext,
    List<int> keyWrap = const [],
    this.protocolVersion = syncProtocolVersion,
  })  : nonce = Uint8List.fromList(nonce).asUnmodifiableView(),
        ciphertext = Uint8List.fromList(ciphertext).asUnmodifiableView(),
        keyWrap = Uint8List.fromList(keyWrap).asUnmodifiableView() {
    // Reuse the Change field checks (names, HLC, seq, cause).
    toChange(GroupId(Uint8List(Id128.length)), const NullValue());
    if (this.nonce.length != envelopeNonceLength) {
      throw ArgumentError.value(this.nonce.length, 'nonce', 'must be $envelopeNonceLength bytes');
    }
    if (this.ciphertext.length > SyncLimits.maxEnvelopeCiphertextBytes) {
      throw ValueTooLargeException(this.ciphertext.length, SyncLimits.maxEnvelopeCiphertextBytes);
    }
    RangeError.checkValueInInterval(protocolVersion, 1, 0xFFFFFFFF, 'protocolVersion');
  }

  /// The envelope metadata of [change]; [ciphertext] must encrypt
  /// `change.value.encode()` (T11).
  factory ChangeEnvelope.forChange(
    Change change, {
    required EpochId epoch,
    required List<int> nonce,
    required List<int> ciphertext,
    List<int> keyWrap = const [],
    int protocolVersion = syncProtocolVersion,
  }) =>
      ChangeEnvelope(
        tbl: change.tbl,
        pk: change.pk,
        col: change.col,
        hlc: change.hlc,
        node: change.node,
        origin: change.origin,
        originSeq: change.originSeq,
        cause: change.cause,
        epoch: epoch,
        nonce: nonce,
        ciphertext: ciphertext,
        keyWrap: keyWrap,
        protocolVersion: protocolVersion,
      );

  final String tbl;
  final String pk;
  final String col;
  final int hlc;
  final String node;
  final OriginId origin;
  final int originSeq;
  final RowRef? cause;
  final EpochId epoch;
  final Uint8List nonce;
  final Uint8List ciphertext;

  /// Reserved key-wrap field (D7); relayed verbatim.
  final Uint8List keyWrap;

  /// Protocol version the envelope was sealed under (on the wire, bound in
  /// the AD).
  final int protocolVersion;

  /// The D7 associated data of this envelope. [protocolVersion] defaults to
  /// the envelope's own sealing version (what `EnvelopeCipher.open` binds).
  Uint8List associatedData({required GroupId groupId, int? protocolVersion}) => envelopeAssociatedData(
        groupId: groupId,
        epoch: epoch,
        tbl: tbl,
        pk: pk,
        col: col,
        hlc: hlc,
        origin: origin,
        originSeq: originSeq,
        cause: cause,
        protocolVersion: protocolVersion ?? this.protocolVersion,
      );

  /// The change this envelope carries, given its decrypted [value].
  Change toChange(GroupId groupId, ChangeValue value) => Change(
        groupId: groupId,
        tbl: tbl,
        pk: pk,
        col: col,
        value: value,
        hlc: hlc,
        node: node,
        origin: origin,
        originSeq: originSeq,
        cause: cause,
      );

  /// Wire bytes of this envelope alone (e.g. for `sync_held_envelope`).
  Uint8List encode() {
    final w = ByteWriter();
    writeTo(w);
    return w.take();
  }

  /// Decodes [encode] output. Throws a [SyncDecodeException] subtype.
  static ChangeEnvelope decode(Uint8List bytes) {
    final r = ByteReader(bytes);
    final envelope = readFrom(r);
    r.expectEnd('envelope');
    return envelope;
  }

  void writeTo(ByteWriter w) {
    w
      ..string(tbl)
      ..string(pk)
      ..string(col)
      ..i64(hlc)
      ..string(node)
      ..fixed(origin.bytes)
      ..i64(originSeq);
    writeCause(w, cause);
    w
      ..i64(epoch.counter)
      ..string(epoch.creator)
      ..u32(protocolVersion)
      ..fixed(nonce)
      ..bytes(ciphertext)
      ..bytes(keyWrap);
  }

  static ChangeEnvelope readFrom(ByteReader r) {
    final tbl = r.name('tbl');
    final pk = r.name('pk');
    final col = r.name('col');
    final hlc = readHlc(r);
    final node = r.name('node');
    final origin = OriginId(r.fixed(Id128.length, 'origin'));
    final originSeq = readOriginSeq(r);
    final cause = readCause(r);
    final epochCounter = r.seq('epoch counter');
    if (epochCounter < 1) throw const MalformedMessageException('epoch counter: must be >= 1');
    if (epochCounter > EpochId.maxCounter) throw const MalformedMessageException('epoch counter: above 2^53');
    final epochCreator = r.name('epoch creator');
    final protocolVersion = r.u32('protocol_version');
    if (protocolVersion < 1) throw const MalformedMessageException('protocol_version: must be >= 1');
    final nonce = r.fixed(envelopeNonceLength, 'nonce');
    final ciphertext = r.bytes(
      'ciphertext',
      maxLength: SyncLimits.maxEnvelopeCiphertextBytes,
      onTooLarge: (n) => ValueTooLargeException(n, SyncLimits.maxEnvelopeCiphertextBytes),
    );
    final keyWrap = r.bytes('key_wrap');
    return ChangeEnvelope(
      tbl: tbl,
      pk: pk,
      col: col,
      hlc: hlc,
      node: node,
      origin: origin,
      originSeq: originSeq,
      cause: cause,
      epoch: EpochId(epochCounter, epochCreator),
      nonce: nonce,
      ciphertext: ciphertext,
      keyWrap: keyWrap,
      protocolVersion: protocolVersion,
    );
  }

  /// Metadata only; never ciphertext or key bytes.
  @override
  String toString() => 'ChangeEnvelope($tbl/$pk/$col $origin#$originSeq $epoch v$protocolVersion)';
}
