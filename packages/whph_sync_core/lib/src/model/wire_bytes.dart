/// Big-endian, length-prefixed primitives shared by the canonical encodings
/// and the message codec. Internal to the package (not exported).
///
/// Layout rules:
/// - integers are fixed width, big-endian (`u8`, `u16`, `u32`, `i64`);
/// - strings are `u32 length ‖ UTF-8 bytes`, strictly decoded (a leading BOM
///   is kept, invalid or overlong UTF-8 is rejected) and never contain an
///   unpaired surrogate, so the string ↔ bytes mapping is a bijection;
/// - byte strings are `u32 length ‖ bytes`; fixed-size fields have no prefix.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../protocol/errors.dart';

const _bom = [0xEF, 0xBB, 0xBF];

/// Throws [ArgumentError] when [value] contains an unpaired UTF-16 surrogate,
/// which UTF-8 cannot represent (it would be replaced, making two strings
/// encode to the same bytes).
void checkEncodableString(String value, String name) {
  final units = value.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    if (u >= 0xD800 && u <= 0xDBFF) {
      if (i + 1 < units.length && units[i + 1] >= 0xDC00 && units[i + 1] <= 0xDFFF) {
        i++;
        continue;
      }
      throw ArgumentError.value(value, name, 'contains an unpaired surrogate');
    }
    if (u >= 0xDC00 && u <= 0xDFFF) throw ArgumentError.value(value, name, 'contains an unpaired surrogate');
  }
}

/// Strict UTF-8 decode that keeps a leading BOM (Dart's decoder drops it),
/// so decoding is the exact inverse of `utf8.encode`. Throws
/// [MalformedMessageException] for invalid or overlong UTF-8.
String decodeUtf8Strict(Uint8List raw, String what) {
  try {
    final hasBom = raw.length >= 3 && raw[0] == _bom[0] && raw[1] == _bom[1] && raw[2] == _bom[2];
    final body = utf8.decode(hasBom ? Uint8List.sublistView(raw, 3) : raw);
    return hasBom ? '\uFEFF$body' : body;
  } on FormatException {
    throw MalformedMessageException('$what: invalid UTF-8');
  }
}

/// Byte-wise equality of two byte lists.
bool bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Appends primitives to a growing buffer.
final class ByteWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);
  final ByteData _scratch = ByteData(8);

  int get length => _out.length;

  void u8(int v) {
    RangeError.checkValueInInterval(v, 0, 0xFF, 'u8');
    _out.addByte(v);
  }

  void u16(int v) {
    RangeError.checkValueInInterval(v, 0, 0xFFFF, 'u16');
    _scratch.setUint16(0, v);
    _out.add(Uint8List.fromList(_scratch.buffer.asUint8List(0, 2)));
  }

  void u32(int v) {
    RangeError.checkValueInInterval(v, 0, 0xFFFFFFFF, 'u32');
    _scratch.setUint32(0, v);
    _out.add(Uint8List.fromList(_scratch.buffer.asUint8List(0, 4)));
  }

  void i64(int v) {
    _scratch.setInt64(0, v);
    _out.add(Uint8List.fromList(_scratch.buffer.asUint8List(0, 8)));
  }

  /// Raw bytes without a length prefix (fixed-size fields).
  void fixed(List<int> bytes) => _out.add(Uint8List.fromList(bytes));

  void bytes(List<int> bytes) {
    u32(bytes.length);
    fixed(bytes);
  }

  void string(String value) {
    checkEncodableString(value, 'string');
    bytes(utf8.encode(value));
  }

  Uint8List take() => _out.takeBytes();
}

/// Reads primitives from [bytes]; every read past the end throws
/// [TruncatedMessageException].
final class ByteReader {
  ByteReader(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int _offset = 0;

  int get remaining => _bytes.length - _offset;

  void _need(int n, String what) {
    if (n > remaining) throw TruncatedMessageException('$what: needs $n bytes, $remaining left');
  }

  int u8(String what) {
    _need(1, what);
    return _bytes[_offset++];
  }

  int u16(String what) {
    _need(2, what);
    final v = _data.getUint16(_offset);
    _offset += 2;
    return v;
  }

  int u32(String what) {
    _need(4, what);
    final v = _data.getUint32(_offset);
    _offset += 4;
    return v;
  }

  int i64(String what) {
    _need(8, what);
    final v = _data.getInt64(_offset);
    _offset += 8;
    return v;
  }

  /// A non-negative `i64` (seqs, counters, cursors).
  int seq(String what) {
    final v = i64(what);
    if (v < 0) throw MalformedMessageException('$what: negative ($v)');
    return v;
  }

  /// A boolean encoded as `u8` 0 or 1.
  bool flag(String what) => switch (u8(what)) {
        0 => false,
        1 => true,
        final v => throw MalformedMessageException('$what: invalid flag $v'),
      };

  Uint8List fixed(int n, String what) {
    _need(n, what);
    final out = Uint8List.fromList(Uint8List.sublistView(_bytes, _offset, _offset + n));
    _offset += n;
    return out;
  }

  /// Reads the `u32` length of a byte string. [onTooLarge] builds the error
  /// for a declared length above [maxLength] (checked before reading).
  Uint8List bytes(String what, {int? maxLength, SyncDecodeException Function(int length)? onTooLarge}) {
    final length = u32(what);
    if (maxLength != null && length > maxLength) {
      throw onTooLarge?.call(length) ?? MalformedMessageException('$what: $length bytes exceed $maxLength');
    }
    return fixed(length, what);
  }

  String string(String what) => decodeUtf8Strict(bytes(what), what);

  /// A non-empty string.
  String name(String what) {
    final v = string(what);
    if (v.isEmpty) throw MalformedMessageException('$what: empty');
    return v;
  }

  /// Reads a `u32` element count; rejects counts that cannot fit in the
  /// remaining bytes given at least [minElementBytes] per element, so a forged
  /// count never triggers a large allocation.
  int count(String what, {required int minElementBytes}) {
    final n = u32(what);
    if (n * minElementBytes > remaining) {
      throw TruncatedMessageException('$what: $n elements cannot fit in $remaining bytes');
    }
    return n;
  }

  /// Throws [MalformedMessageException] when bytes are left over.
  void expectEnd(String what) {
    if (remaining != 0) throw MalformedMessageException('$what: $remaining trailing bytes');
  }
}
