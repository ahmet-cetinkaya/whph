/// Sync protocol messages and their binary codec (D8, wire format v1).
///
/// Frame: `u8 wire_format (= 1) ‖ u8 message type ‖ body`, at most
/// [SyncLimits.maxFrameBytes]. Integers are big-endian; `str` is
/// `u32 len ‖ UTF-8`; maps are encoded with strictly ascending keys (the
/// decoder rejects duplicates and any other order), so every message has
/// exactly one encoding. Bodies (see each class) are consumed exactly; trailing
/// bytes are malformed.
///
/// The layouts of [Hello], [HelloAck] and [UpdateRequired] are frozen across
/// protocol versions so that any two versions can complete the version check
/// (FR-040, FR-041). Everything else follows the agreed version.
///
/// The decoder is strict and all-or-nothing: it returns a fully validated
/// message or throws a [SyncDecodeException] subtype, and never hands out
/// partial state (FR-015).
library;

import 'dart:typed_data';

import '../clock/hlc.dart';
import '../model/change.dart';
import '../model/envelope.dart';
import '../model/ids.dart';
import '../model/manifest.dart';
import '../model/wire_bytes.dart';
import '../store/replica_store.dart';
import 'errors.dart';
import 'version.dart';

/// Version of the frame layout defined in this file.
const syncWireFormatVersion = 1;

/// Message type tags. Tags are never reused (11 and 12 are retired).
enum SyncMessageType {
  hello(1),
  helloAck(2),
  updateRequired(3),
  busy(4),
  error(5),
  originRegistry(6),
  keyHandover(7),
  vectorExchange(8),
  changeBatch(9),
  batchAck(10);

  const SyncMessageType(this.tag);

  final int tag;

  static SyncMessageType? fromTag(int tag) {
    for (final t in values) {
      if (t.tag == tag) return t;
    }
    return null;
  }
}

/// Base of every protocol message.
sealed class SyncMessage {
  const SyncMessage();

  SyncMessageType get type;

  void _writeBody(ByteWriter w);
}

/// Encoding and strict decoding of [SyncMessage] frames.
abstract final class SyncCodec {
  /// Encodes [message] as one frame. Throws [FrameTooLargeException] when the
  /// frame would exceed [SyncLimits.maxFrameBytes].
  static Uint8List encode(SyncMessage message) {
    final w = ByteWriter()
      ..u8(syncWireFormatVersion)
      ..u8(message.type.tag);
    message._writeBody(w);
    final frame = w.take();
    if (frame.length > SyncLimits.maxFrameBytes) throw FrameTooLargeException(frame.length, SyncLimits.maxFrameBytes);
    return frame;
  }

  /// Decodes one frame. Throws a [SyncDecodeException] subtype for any
  /// oversized, truncated, malformed or unknown input.
  static SyncMessage decode(Uint8List frame) {
    if (frame.length > SyncLimits.maxFrameBytes) throw FrameTooLargeException(frame.length, SyncLimits.maxFrameBytes);
    final r = ByteReader(frame);
    final format = r.u8('wire format');
    if (format != syncWireFormatVersion) throw UnsupportedWireFormatException(format);
    final tag = r.u8('message type');
    final type = SyncMessageType.fromTag(tag) ?? (throw UnknownMessageTypeException(tag));
    try {
      final message = switch (type) {
        SyncMessageType.hello => Hello._read(r),
        SyncMessageType.helloAck => HelloAck._read(r),
        SyncMessageType.updateRequired => UpdateRequired._read(r),
        SyncMessageType.busy => const Busy(),
        SyncMessageType.error => ErrorMessage._read(r),
        SyncMessageType.originRegistry => OriginRegistry._read(r),
        SyncMessageType.keyHandover => KeyHandover._read(r),
        SyncMessageType.vectorExchange => VectorExchange._read(r),
        SyncMessageType.changeBatch => ChangeBatchMessage._read(r),
        SyncMessageType.batchAck => BatchAck._read(r),
      };
      r.expectEnd(type.name);
      return message;
    } on ArgumentError catch (e) {
      // Safety net: constructor validation that the readers did not pre-check.
      throw MalformedMessageException('${type.name}: ${e.message}');
    }
  }
}

// --- Version check ------------------------------------------------------------

/// First message of a session, sent by the initiator before any user data.
///
/// Body (frozen): `u32 protocol_version ‖ u32 min_compatible ‖ str app_version
/// ‖ str member_id ‖ str device_name ‖ i64 wall_ms`.
final class Hello extends SyncMessage {
  Hello({
    required this.protocolVersion,
    required this.minCompatible,
    required this.appVersion,
    required this.memberId,
    required this.deviceName,
    required this.wallMs,
  }) {
    if (minCompatible < 1 || minCompatible > protocolVersion) {
      throw ArgumentError('min_compatible $minCompatible must be in [1, protocol_version $protocolVersion]');
    }
    if (memberId.isEmpty) throw ArgumentError.value(memberId, 'memberId', 'must not be empty');
  }

  /// A Hello for this build's protocol constants.
  factory Hello.current({
    required String appVersion,
    required String memberId,
    required String deviceName,
    required int wallMs,
  }) =>
      Hello(
        protocolVersion: syncProtocolVersion,
        minCompatible: minCompatibleProtocolVersion,
        appVersion: appVersion,
        memberId: memberId,
        deviceName: deviceName,
        wallMs: wallMs,
      );

  final int protocolVersion;
  final int minCompatible;

  /// Informational only; never used for compatibility (FR-043).
  final String appVersion;
  final String memberId;
  final String deviceName;

  /// Sender's wall clock (ms since epoch) for the peer-state record.
  final int wallMs;

  @override
  SyncMessageType get type => SyncMessageType.hello;

  @override
  void _writeBody(ByteWriter w) => w
    ..u32(protocolVersion)
    ..u32(minCompatible)
    ..string(appVersion)
    ..string(memberId)
    ..string(deviceName)
    ..i64(wallMs);

  static Hello _read(ByteReader r) {
    final protocolVersion = r.u32('protocol_version');
    final minCompatible = r.u32('min_compatible');
    if (minCompatible < 1 || minCompatible > protocolVersion) {
      throw MalformedMessageException('min_compatible $minCompatible outside [1, $protocolVersion]');
    }
    return Hello(
      protocolVersion: protocolVersion,
      minCompatible: minCompatible,
      appVersion: r.string('app_version'),
      memberId: r.name('member_id'),
      deviceName: r.string('device_name'),
      wallMs: r.i64('wall_ms'),
    );
  }

  @override
  String toString() => 'Hello(v$protocolVersion min $minCompatible, $memberId)';
}

/// Responder's acceptance: its own Hello fields plus the agreed version.
///
/// Body (frozen): `Hello body ‖ u32 agreed_version`.
final class HelloAck extends SyncMessage {
  HelloAck({required this.hello, required this.agreedVersion}) {
    if (agreedVersion < hello.minCompatible || agreedVersion > hello.protocolVersion) {
      throw ArgumentError.value(agreedVersion, 'agreedVersion', 'outside the responder range');
    }
  }

  /// The responder's version, identity and clock.
  final Hello hello;
  final int agreedVersion;

  @override
  SyncMessageType get type => SyncMessageType.helloAck;

  @override
  void _writeBody(ByteWriter w) {
    hello._writeBody(w);
    w.u32(agreedVersion);
  }

  static HelloAck _read(ByteReader r) {
    final hello = Hello._read(r);
    final agreed = r.u32('agreed_version');
    if (agreed < hello.minCompatible || agreed > hello.protocolVersion) {
      throw MalformedMessageException('agreed_version $agreed outside the responder range');
    }
    return HelloAck(hello: hello, agreedVersion: agreed);
  }
}

/// The devices are not protocol-compatible; names the device that must be
/// updated (FR-041). Ends the session; no data is exchanged.
///
/// Body (frozen): `str member_id ‖ str device_name`.
final class UpdateRequired extends SyncMessage {
  const UpdateRequired({required this.memberId, required this.deviceName});

  final String memberId;
  final String deviceName;

  @override
  SyncMessageType get type => SyncMessageType.updateRequired;

  @override
  void _writeBody(ByteWriter w) => w
    ..string(memberId)
    ..string(deviceName);

  static UpdateRequired _read(ByteReader r) =>
      UpdateRequired(memberId: r.name('member_id'), deviceName: r.string('device_name'));
}

/// A session with this peer is already running (D15); retry next cycle.
///
/// Body: empty.
final class Busy extends SyncMessage {
  const Busy();

  @override
  SyncMessageType get type => SyncMessageType.busy;

  @override
  void _writeBody(ByteWriter w) {}
}

/// Known error categories. Codes are never reused; codes unknown to this
/// build are preserved in [ErrorMessage.code].
enum SyncErrorCategory {
  malformed(1),
  limitExceeded(2),
  protocolViolation(3),
  notAuthorized(4),
  preparing(5),
  storageError(6),
  internal(7);

  const SyncErrorCategory(this.code);

  final int code;
}

/// The peer aborts the session for a reason category (never details that
/// could carry values or key material).
///
/// Body: `u16 category code`.
final class ErrorMessage extends SyncMessage {
  ErrorMessage(SyncErrorCategory category) : code = category.code;

  ErrorMessage.fromCode(this.code) {
    RangeError.checkValueInInterval(code, 0, 0xFFFF, 'code');
  }

  final int code;

  /// The category, or `null` for a code unknown to this build.
  SyncErrorCategory? get category {
    for (final c in SyncErrorCategory.values) {
      if (c.code == code) return c;
    }
    return null;
  }

  @override
  SyncMessageType get type => SyncMessageType.error;

  @override
  void _writeBody(ByteWriter w) => w.u16(code);

  static ErrorMessage _read(ByteReader r) => ErrorMessage.fromCode(r.u16('category'));
}

// --- Security metadata -------------------------------------------------------

/// A signed `sync_origin` row (D7): `sig` over
/// `(group_id, origin_id, member_pub, created_hlc)` (verified in T11).
final class OriginRegistration {
  OriginRegistration({
    required this.origin,
    required List<int> memberPub,
    required this.createdHlc,
    required List<int> sig,
  })  : memberPub = Uint8List.fromList(memberPub).asUnmodifiableView(),
        sig = Uint8List.fromList(sig).asUnmodifiableView() {
    if (this.memberPub.length != publicKeyLength) throw ArgumentError.value(memberPub.length, 'memberPub');
    if (this.sig.length != signatureLength) throw ArgumentError.value(sig.length, 'sig');
    if (!Hlc.isWellFormed(createdHlc)) throw ArgumentError.value(createdHlc, 'createdHlc');
  }

  /// Length of an Ed25519 public key.
  static const publicKeyLength = 32;

  final OriginId origin;
  final Uint8List memberPub;
  final int createdHlc;
  final Uint8List sig;

  static const _wireLength = Id128.length + publicKeyLength + 8 + signatureLength;
}

/// The origin registry rows, sent first in every session (D7).
///
/// Body: `u32 n ‖ n × (16B origin ‖ 32B member_pub ‖ i64 created_hlc ‖ 64B sig)`.
final class OriginRegistry extends SyncMessage {
  OriginRegistry(List<OriginRegistration> entries) : entries = List.unmodifiable(entries);

  final List<OriginRegistration> entries;

  @override
  SyncMessageType get type => SyncMessageType.originRegistry;

  @override
  void _writeBody(ByteWriter w) {
    w.u32(entries.length);
    for (final e in entries) {
      w
        ..fixed(e.origin.bytes)
        ..fixed(e.memberPub)
        ..i64(e.createdHlc)
        ..fixed(e.sig);
    }
  }

  static OriginRegistry _read(ByteReader r) {
    final n = r.count('registry count', minElementBytes: OriginRegistration._wireLength);
    return OriginRegistry([
      for (var i = 0; i < n; i++)
        OriginRegistration(
          origin: OriginId(r.fixed(Id128.length, 'origin')),
          memberPub: r.fixed(OriginRegistration.publicKeyLength, 'member_pub'),
          createdHlc: readHlc(r),
          sig: r.fixed(signatureLength, 'sig'),
        ),
    ]);
  }
}

/// One group-key epoch handed to a peer inside the authenticated session.
final class EpochKeyGrant {
  EpochKeyGrant({required this.epoch, required List<int> key}) : key = Uint8List.fromList(key) {
    if (this.key.length != keyLength) throw ArgumentError.value(key.length, 'key', 'must be $keyLength bytes');
  }

  /// Length of a group key (XChaCha20-Poly1305).
  static const keyLength = 32;

  final EpochId epoch;

  /// Secret key material; callers zero it after use (T11).
  final Uint8List key;

  /// Never prints key bytes.
  @override
  String toString() => 'EpochKeyGrant($epoch)';
}

/// Epoch keys the peer lacks (D7). Travels only inside the Noise session.
///
/// Body: `u32 n ‖ n × (i64 epoch counter ‖ str epoch creator ‖ 32B key)`.
final class KeyHandover extends SyncMessage {
  KeyHandover(List<EpochKeyGrant> grants) : grants = List.unmodifiable(grants);

  final List<EpochKeyGrant> grants;

  @override
  SyncMessageType get type => SyncMessageType.keyHandover;

  @override
  void _writeBody(ByteWriter w) {
    w.u32(grants.length);
    for (final g in grants) {
      w
        ..i64(g.epoch.counter)
        ..string(g.epoch.creator)
        ..fixed(g.key);
    }
  }

  static KeyHandover _read(ByteReader r) {
    final n = r.count('grant count', minElementBytes: 8 + 4 + 1 + EpochKeyGrant.keyLength);
    return KeyHandover([for (var i = 0; i < n; i++) EpochKeyGrant(epoch: _readEpoch(r), key: r.fixed(32, 'key'))]);
  }

  @override
  String toString() => 'KeyHandover(${grants.length} grants)';
}

// --- Change exchange ----------------------------------------------------------

/// A declared seq range `(from, to]` of one origin (D15).
final class SeqRange {
  SeqRange(this.from, this.to) {
    if (from < 0 || to <= from) throw ArgumentError('range ($from, $to] is empty or negative');
  }

  final int from;
  final int to;

  bool contains(int seq) => seq > from && seq <= to;

  @override
  bool operator ==(Object other) => other is SeqRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '($from, $to]';
}

/// Vector and refetch exchange at session start (D15).
///
/// Also lists the epoch ids the sender holds keys for (ids only, never key
/// material): the peer hands over the keys missing from that list (U11, G1).
///
/// Body: `seqmap vector ‖ u32 n ‖ n × (str tbl ‖ str pk ‖ str col) ‖ u32 m ‖
/// m × (i64 epoch counter ‖ str epoch creator)`, where `seqmap` =
/// `u32 n ‖ n × (16B origin ‖ i64 seq)` with strictly ascending origins and
/// the epochs are strictly ascending ([EpochId.compareTo]).
final class VectorExchange extends SyncMessage {
  VectorExchange({
    required Map<OriginId, int> vector,
    List<CellKey> refetch = const [],
    Iterable<EpochId> heldEpochs = const [],
  })  : vector = _sortedSeqMap(vector, 'vector'),
        refetch = List.unmodifiable(refetch),
        heldEpochs = _sortedEpochs(heldEpochs);

  /// This device's received vector (cursor per origin).
  final Map<OriginId, int> vector;

  /// Cells whose apply failed and should be resent (D15).
  final List<CellKey> refetch;

  /// Epochs whose key the sender holds, ascending.
  final List<EpochId> heldEpochs;

  @override
  SyncMessageType get type => SyncMessageType.vectorExchange;

  @override
  void _writeBody(ByteWriter w) {
    _writeSeqMap(w, vector);
    w.u32(refetch.length);
    for (final k in refetch) {
      w
        ..string(k.table)
        ..string(k.pk)
        ..string(k.col);
    }
    w.u32(heldEpochs.length);
    for (final e in heldEpochs) {
      w
        ..i64(e.counter)
        ..string(e.creator);
    }
  }

  static VectorExchange _read(ByteReader r) {
    final vector = _readSeqMap(r, 'vector');
    final n = r.count('refetch count', minElementBytes: 15);
    final refetch = [for (var i = 0; i < n; i++) CellKey(r.name('tbl'), r.name('pk'), r.name('col'))];
    final epochCount = r.count('held epoch count', minElementBytes: _epochMinWireLength);
    final heldEpochs = [for (var i = 0; i < epochCount; i++) _readEpoch(r)];
    for (var i = 1; i < heldEpochs.length; i++) {
      if (heldEpochs[i].compareTo(heldEpochs[i - 1]) <= 0) {
        throw const MalformedMessageException('held epochs: not strictly ascending');
      }
    }
    return VectorExchange(vector: vector, refetch: refetch, heldEpochs: heldEpochs);
  }
}

/// A batch of changes with declared per-origin ranges (D15), the manifests
/// that authenticate them (D7) and the encrypted changes.
///
/// [batchId] identifies the batch for the asynchronous [BatchAck] of a
/// pipelined session (U9/PA-2).
///
/// Validation (constructor and decoder, all-or-nothing):
/// - at most [SyncLimits.maxBatchChanges] envelopes
///   ([BatchTooLargeException]) and manifests;
/// - at most [SyncLimits.maxRangesPerBatch] ranges ([BatchTooLargeException]),
///   checked before anything else;
/// - the ranges of one origin are pairwise disjoint
///   ([BatchRangeViolationException]); they are sorted here, the sender's
///   order is never relied on;
/// - every envelope lies in exactly one range of its origin, else the whole
///   batch is rejected ([BatchRangeViolationException]);
/// - no two envelopes share `(origin, origin_seq)` ([MalformedMessageException]).
///
/// Body: `i64 batch_id ‖ u32 n ‖ n × (16B origin ‖ i64 from ‖ i64 to)`
/// (the ranges of one origin are adjacent, origins strictly ascending between
/// groups) `‖ u32 m ‖ m × manifest ‖ u32 k ‖ k × envelope`.
final class ChangeBatchMessage extends SyncMessage {
  ChangeBatchMessage({
    required this.batchId,
    required Map<OriginId, List<SeqRange>> ranges,
    List<OriginManifest> manifests = const [],
    List<ChangeEnvelope> envelopes = const [],
  })  : ranges = Map.unmodifiable({
          for (final e in ranges.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
            e.key: List<SeqRange>.unmodifiable(e.value.toList()..sort((a, b) => a.from.compareTo(b.from))),
        }),
        manifests = List.unmodifiable(manifests),
        envelopes = List.unmodifiable(envelopes) {
    if (batchId < 0) throw ArgumentError.value(batchId, 'batchId', 'must be non-negative');
    _validate();
  }

  final int batchId;

  /// Declared ranges per origin, ascending by `from` whatever order the sender
  /// wrote them.
  final Map<OriginId, List<SeqRange>> ranges;
  final List<OriginManifest> manifests;
  final List<ChangeEnvelope> envelopes;

  int get rangeCount => ranges.values.fold(0, (n, list) => n + list.length);

  void _validate() {
    if (rangeCount > SyncLimits.maxRangesPerBatch) {
      throw BatchTooLargeException(rangeCount, SyncLimits.maxRangesPerBatch);
    }
    if (envelopes.length > SyncLimits.maxBatchChanges) {
      throw BatchTooLargeException(envelopes.length, SyncLimits.maxBatchChanges);
    }
    if (manifests.length > SyncLimits.maxBatchChanges) {
      throw BatchTooLargeException(manifests.length, SyncLimits.maxBatchChanges);
    }
    ranges.forEach(_checkDisjoint);
    final seen = <OriginId, Set<int>>{};
    for (final e in envelopes) {
      final declared = ranges[e.origin];
      if (declared == null) {
        throw BatchRangeViolationException('change ${e.origin}#${e.originSeq} has no declared range');
      }
      if (!declared.any((range) => range.contains(e.originSeq))) {
        throw BatchRangeViolationException('change ${e.origin}#${e.originSeq} outside declared $declared');
      }
      if (!seen.putIfAbsent(e.origin, () => {}).add(e.originSeq)) {
        throw MalformedMessageException('duplicate change ${e.origin}#${e.originSeq}');
      }
    }
  }

  static void _checkDisjoint(OriginId origin, List<SeqRange> sorted) {
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].from < sorted[i - 1].to) {
        throw BatchRangeViolationException('origin $origin: ranges ${sorted[i - 1]} and ${sorted[i]} overlap');
      }
    }
  }

  @override
  SyncMessageType get type => SyncMessageType.changeBatch;

  @override
  void _writeBody(ByteWriter w) {
    w
      ..i64(batchId)
      ..u32(rangeCount);
    for (final e in ranges.entries) {
      for (final range in e.value) {
        w
          ..fixed(e.key.bytes)
          ..i64(range.from)
          ..i64(range.to);
      }
    }
    w.u32(manifests.length);
    for (final m in manifests) {
      m.writeTo(w);
    }
    w.u32(envelopes.length);
    for (final e in envelopes) {
      e.writeTo(w);
    }
  }

  static ChangeBatchMessage _read(ByteReader r) {
    final batchId = r.seq('batch_id');
    final nRanges = r.count('range count', minElementBytes: Id128.length + 16);
    if (nRanges > SyncLimits.maxRangesPerBatch) throw BatchTooLargeException(nRanges, SyncLimits.maxRangesPerBatch);
    final ranges = <OriginId, List<SeqRange>>{};
    OriginId? previous;
    for (var i = 0; i < nRanges; i++) {
      final origin = OriginId(r.fixed(Id128.length, 'range origin'));
      if (previous != null && origin.compareTo(previous) < 0) {
        throw const MalformedMessageException('ranges: origins not ascending');
      }
      if (origin != previous && ranges.containsKey(origin)) {
        throw const MalformedMessageException('ranges: origin split into several groups');
      }
      previous = origin;
      final from = r.seq('range from');
      final to = r.seq('range to');
      if (to <= from) throw MalformedMessageException('range ($from, $to] is empty');
      ranges.putIfAbsent(origin, () => []).add(SeqRange(from, to));
    }
    final nManifests = r.u32('manifest count');
    if (nManifests > SyncLimits.maxBatchChanges) throw BatchTooLargeException(nManifests, SyncLimits.maxBatchChanges);
    final manifests = [for (var i = 0; i < nManifests; i++) OriginManifest.readFrom(r)];
    final nEnvelopes = r.u32('envelope count');
    if (nEnvelopes > SyncLimits.maxBatchChanges) throw BatchTooLargeException(nEnvelopes, SyncLimits.maxBatchChanges);
    final envelopes = [for (var i = 0; i < nEnvelopes; i++) ChangeEnvelope.readFrom(r)];
    return ChangeBatchMessage(batchId: batchId, ranges: ranges, manifests: manifests, envelopes: envelopes);
  }

  @override
  String toString() => 'ChangeBatchMessage(#$batchId, $ranges, ${manifests.length} manifests, '
      '${envelopes.length} envelopes)';
}

/// The receiver committed batch [batchId] (its cursors advanced, D15). Acks
/// may arrive out of step with sends in a pipelined session (U9/PA-2).
///
/// Body: `i64 batch_id`.
final class BatchAck extends SyncMessage {
  BatchAck(this.batchId) {
    if (batchId < 0) throw ArgumentError.value(batchId, 'batchId', 'must be non-negative');
  }

  final int batchId;

  @override
  SyncMessageType get type => SyncMessageType.batchAck;

  @override
  void _writeBody(ByteWriter w) => w.i64(batchId);

  static BatchAck _read(ByteReader r) => BatchAck(r.seq('batch_id'));
}

// --- Shared helpers -----------------------------------------------------------

/// `i64 counter ‖ u32 creator length ‖ at least one creator byte`.
const _epochMinWireLength = 8 + 4 + 1;

/// [epochs] ascending; duplicates are a protocol violation, like in a seqmap.
List<EpochId> _sortedEpochs(Iterable<EpochId> epochs) {
  final sorted = epochs.toList()..sort();
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i] == sorted[i - 1]) throw MalformedMessageException('held epochs: duplicate ${sorted[i]}');
  }
  return List.unmodifiable(sorted);
}

EpochId _readEpoch(ByteReader r) {
  final counter = r.seq('epoch counter');
  if (counter < 1) throw const MalformedMessageException('epoch counter: must be >= 1');
  if (counter > EpochId.maxCounter) throw const MalformedMessageException('epoch counter: above 2^53');
  return EpochId(counter, r.name('epoch creator'));
}

Map<OriginId, int> _sortedSeqMap(Map<OriginId, int> map, String name) {
  for (final e in map.entries) {
    if (e.value < 0) throw ArgumentError.value(e.value, '$name[${e.key}]', 'must be non-negative');
  }
  return Map.unmodifiable(Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key))));
}

void _writeSeqMap(ByteWriter w, Map<OriginId, int> map) {
  w.u32(map.length);
  for (final e in map.entries) {
    w
      ..fixed(e.key.bytes)
      ..i64(e.value);
  }
}

Map<OriginId, int> _readSeqMap(ByteReader r, String what) {
  final n = r.count('$what count', minElementBytes: Id128.length + 8);
  final map = <OriginId, int>{};
  OriginId? previous;
  for (var i = 0; i < n; i++) {
    final origin = OriginId(r.fixed(Id128.length, '$what origin'));
    if (previous != null && origin.compareTo(previous) <= 0) {
      throw MalformedMessageException('$what: origins not strictly ascending');
    }
    previous = origin;
    map[origin] = r.seq('$what seq');
  }
  return map;
}
