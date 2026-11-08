/// The logical change (one cell version) and its canonical bytes (D7).
///
/// Canonical change v1 (all integers big-endian; `str` = `u32 len ‖ UTF-8`):
///
/// ```text
/// str   "whph-sync/change/v1"        domain separation / format version
/// 16B   group_id
/// str   tbl                          table name (never an interned id)
/// str   pk
/// str   col                          column name, `~` existence, `*` row cell
/// value u8 tag ‖ u32 len ‖ payload   see [ChangeValue]
/// i64   hlc                          packed HLC (D2)
/// str   node                         author member id
/// 16B   origin                       128-bit origin id
/// i64   origin_seq                   >= 1
/// u8    cause marker                 0 = absent, 1 = present, then:
///   str cause table name
///   str cause pk
/// ```
///
/// Every field is fixed width or length-prefixed, so the encoding is
/// unambiguous; it contains no local integer (wire rule, D1). The change hash
/// is `BLAKE2b-256(canonical bytes)`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

import '../clock/hlc.dart';
import '../protocol/errors.dart';
import '../protocol/version.dart';
import '../store/replica_store.dart';
import 'ids.dart';
import 'wire_bytes.dart';

/// Domain-separation prefix of canonical change bytes.
const canonicalChangeDomain = 'whph-sync/change/v1';

const _blake2b256 = DartBlake2b(hashLengthInBytes: 32);

/// Length of a change hash (BLAKE2b-256).
const changeHashLength = 32;

/// BLAKE2b-256 of [bytes].
Uint8List blake2b256(List<int> bytes) => Uint8List.fromList(_blake2b256.hashSync(bytes).bytes);

/// A typed cell value. Encoded as `u8 tag ‖ u32 len ‖ payload` whatever the
/// tag, so values of tags unknown to this build (from a compatible newer
/// peer) are kept verbatim as [UnknownValue] and re-encode byte-identically
/// (FR-042).
sealed class ChangeValue {
  const ChangeValue();

  static const tagNull = 0;
  static const tagInt = 1;
  static const tagString = 2;
  static const tagBytes = 3;

  /// Wraps a Dart value: `null`, `int`, `String`, a byte list ([Uint8List])
  /// or an existing [ChangeValue] (returned as is).
  factory ChangeValue.of(Object? value) => switch (value) {
        null => const NullValue(),
        final ChangeValue v => v,
        final int v => IntValue(v),
        final String v => StringValue(v),
        final Uint8List v => BytesValue(v),
        _ => throw ArgumentError.value(value, 'value', 'unsupported cell value type ${value.runtimeType}'),
      };

  /// Decodes a standalone value encoding (e.g. an envelope plaintext). Throws
  /// a [SyncDecodeException] for malformed, truncated or oversized input.
  factory ChangeValue.decode(Uint8List bytes) {
    final reader = ByteReader(bytes);
    final value = readChangeValue(reader);
    reader.expectEnd('value');
    return value;
  }

  int get tag;

  /// Payload bytes (without tag and length).
  Uint8List get payload;

  /// The plain Dart form stored in a [CellRecord]: `null`, `int`, `String`,
  /// [Uint8List], or this object for an [UnknownValue].
  Object? toDart();

  /// `u8 tag ‖ u32 len ‖ payload`.
  Uint8List encode() {
    final w = ByteWriter();
    writeChangeValue(w, this);
    return w.take();
  }

  @override
  bool operator ==(Object other) => other is ChangeValue && other.tag == tag && bytesEqual(other.payload, payload);

  @override
  int get hashCode => Object.hash(tag, Object.hashAll(payload));
}

final class NullValue extends ChangeValue {
  const NullValue();

  @override
  int get tag => ChangeValue.tagNull;

  @override
  Uint8List get payload => Uint8List(0);

  @override
  Object? toDart() => null;

  @override
  String toString() => 'null';
}

final class IntValue extends ChangeValue {
  const IntValue(this.value);

  final int value;

  @override
  int get tag => ChangeValue.tagInt;

  @override
  Uint8List get payload => Uint8List(8)..buffer.asByteData().setInt64(0, value);

  @override
  Object? toDart() => value;

  @override
  String toString() => '$value';
}

final class StringValue extends ChangeValue {
  StringValue(this.value) {
    checkEncodableString(value, 'value');
  }

  final String value;

  @override
  int get tag => ChangeValue.tagString;

  @override
  Uint8List get payload => utf8.encode(value);

  @override
  Object? toDart() => value;

  @override
  String toString() => 'string(${value.length})';
}

final class BytesValue extends ChangeValue {
  BytesValue(List<int> value) : value = Uint8List.fromList(value).asUnmodifiableView();

  final Uint8List value;

  @override
  int get tag => ChangeValue.tagBytes;

  @override
  Uint8List get payload => value;

  @override
  Object? toDart() => value;

  @override
  String toString() => 'bytes(${value.length})';
}

/// A value whose tag this build does not know; kept verbatim (FR-042).
final class UnknownValue extends ChangeValue {
  UnknownValue(this.tag, List<int> payload) : payload = Uint8List.fromList(payload).asUnmodifiableView() {
    if (tag <= ChangeValue.tagBytes || tag > 0xFF) throw ArgumentError.value(tag, 'tag', 'not an unknown value tag');
  }

  @override
  final int tag;

  @override
  final Uint8List payload;

  @override
  Object? toDart() => this;

  @override
  String toString() => 'unknown#$tag(${payload.length})';
}

/// One cell version as synced: the unit hashed into manifests (D7).
final class Change {
  Change({
    required this.groupId,
    required this.tbl,
    required this.pk,
    required this.col,
    required this.value,
    required this.hlc,
    required this.node,
    required this.origin,
    required this.originSeq,
    this.cause,
  }) {
    _checkName(tbl, 'tbl');
    _checkName(pk, 'pk');
    _checkName(col, 'col');
    _checkName(node, 'node');
    if (!Hlc.isWellFormed(hlc)) throw ArgumentError.value(hlc, 'hlc', 'not a well-formed HLC');
    if (originSeq < 1) throw ArgumentError.value(originSeq, 'originSeq', 'must be >= 1');
    if (cause != null) {
      _checkName(cause!.table, 'cause.table');
      _checkName(cause!.pk, 'cause.pk');
    }
    if (value.payload.length > SyncLimits.maxValueBytes) {
      throw ValueTooLargeException(value.payload.length, SyncLimits.maxValueBytes);
    }
  }

  /// Builds the change of a stored [record]. The record's origin must be the
  /// hex form of an [OriginId] and its value a type accepted by
  /// [ChangeValue.of].
  factory Change.fromCellRecord(CellRecord record, {required GroupId groupId}) => Change(
        groupId: groupId,
        tbl: record.key.table,
        pk: record.key.pk,
        col: record.key.col,
        value: ChangeValue.of(record.value),
        hlc: record.clock,
        node: record.node,
        origin: OriginId.fromHex(record.origin),
        originSeq: record.originSeq,
        cause: record.cause,
      );

  /// Decodes canonical bytes. Throws a [SyncDecodeException] subtype for
  /// malformed, truncated or oversized input.
  factory Change.fromCanonicalBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final domain = r.string('domain');
    if (domain != canonicalChangeDomain) throw const MalformedMessageException('not a canonical change v1');
    final groupId = GroupId(r.fixed(Id128.length, 'group_id'));
    final tbl = r.name('tbl');
    final pk = r.name('pk');
    final col = r.name('col');
    final value = readChangeValue(r);
    final hlc = readHlc(r);
    final node = r.name('node');
    final origin = OriginId(r.fixed(Id128.length, 'origin'));
    final originSeq = readOriginSeq(r);
    final cause = readCause(r);
    r.expectEnd('canonical change');
    return Change(
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
  }

  final GroupId groupId;

  /// Table name.
  final String tbl;
  final String pk;

  /// Column name (`~` existence cell, `*` row-level cell).
  final String col;
  final ChangeValue value;

  /// Packed HLC.
  final int hlc;

  /// Author member id.
  final String node;
  final OriginId origin;
  final int originSeq;

  /// The item whose deletion cascaded to this tombstone, as `(table name, pk)`.
  final RowRef? cause;

  /// Canonical bytes (see the library documentation).
  Uint8List canonicalBytes() {
    final w = ByteWriter()
      ..string(canonicalChangeDomain)
      ..fixed(groupId.bytes)
      ..string(tbl)
      ..string(pk)
      ..string(col);
    writeChangeValue(w, value);
    w
      ..i64(hlc)
      ..string(node)
      ..fixed(origin.bytes)
      ..i64(originSeq);
    writeCause(w, cause);
    return w.take();
  }

  /// `BLAKE2b-256(canonicalBytes())`, the manifest entry of this change.
  Uint8List canonicalHash() => blake2b256(canonicalBytes());

  /// The store form of this change (origin as [OriginId.hex]).
  CellRecord toCellRecord() => CellRecord(
        key: CellKey(tbl, pk, col),
        value: value.toDart(),
        clock: hlc,
        node: node,
        origin: origin.hex,
        originSeq: originSeq,
        cause: cause,
      );

  @override
  bool operator ==(Object other) =>
      other is Change &&
      other.groupId == groupId &&
      other.tbl == tbl &&
      other.pk == pk &&
      other.col == col &&
      other.value == value &&
      other.hlc == hlc &&
      other.node == node &&
      other.origin == origin &&
      other.originSeq == originSeq &&
      other.cause == cause;

  @override
  int get hashCode => Object.hash(groupId, tbl, pk, col, value, hlc, node, origin, originSeq, cause);

  /// Ids and metadata only; never the value (logging rule, D7).
  @override
  String toString() => 'Change($tbl/$pk/$col@${Hlc.describe(hlc)}/$node $origin#$originSeq'
      '${cause == null ? '' : ' cause=$cause'})';

  static void _checkName(String value, String name) {
    if (value.isEmpty) throw ArgumentError.value(value, name, 'must not be empty');
    checkEncodableString(value, name);
  }
}

// --- Shared field codecs (package-internal) ----------------------------------

void writeChangeValue(ByteWriter w, ChangeValue value) {
  w
    ..u8(value.tag)
    ..bytes(value.payload);
}

ChangeValue readChangeValue(ByteReader r) {
  final tag = r.u8('value tag');
  final payload = r.bytes(
    'value',
    maxLength: SyncLimits.maxValueBytes,
    onTooLarge: (n) => ValueTooLargeException(n, SyncLimits.maxValueBytes),
  );
  switch (tag) {
    case ChangeValue.tagNull:
      if (payload.isNotEmpty) throw const MalformedMessageException('null value with a payload');
      return const NullValue();
    case ChangeValue.tagInt:
      if (payload.length != 8) throw const MalformedMessageException('int value must be 8 bytes');
      return IntValue(ByteData.sublistView(payload).getInt64(0));
    case ChangeValue.tagString:
      return StringValue(decodeUtf8Strict(payload, 'string value'));
    case ChangeValue.tagBytes:
      return BytesValue(payload);
    default:
      return UnknownValue(tag, payload);
  }
}

int readHlc(ByteReader r) {
  final hlc = r.i64('hlc');
  if (!Hlc.isWellFormed(hlc)) throw MalformedMessageException('hlc: not representable ($hlc)');
  return hlc;
}

int readOriginSeq(ByteReader r) {
  final seq = r.seq('origin_seq');
  if (seq < 1) throw const MalformedMessageException('origin_seq: must be >= 1');
  return seq;
}

void writeCause(ByteWriter w, RowRef? cause) {
  if (cause == null) {
    w.u8(0);
  } else {
    w
      ..u8(1)
      ..string(cause.table)
      ..string(cause.pk);
  }
}

RowRef? readCause(ByteReader r) => r.flag('cause marker') ? RowRef(r.name('cause table'), r.name('cause pk')) : null;
