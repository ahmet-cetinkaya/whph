/// Wire identifiers: 128-bit group and origin ids and group-key epoch ids.
///
/// These are the only identifier forms that appear on the wire, in canonical
/// bytes, in manifests and in AEAD associated data (wire rule, D1): interned
/// local integers never do.
library;

import 'dart:typed_data';

/// A random 128-bit identifier, compared and ordered by its bytes.
abstract base class Id128 implements Comparable<Id128> {
  Id128(List<int> bytes) : bytes = _check(bytes);

  Id128.fromHex(String hex) : bytes = _parseHex(hex);

  /// Length in bytes.
  static const length = 16;

  /// The 16 id bytes (unmodifiable).
  final Uint8List bytes;

  /// Lowercase hex form (32 characters); also the origin key used by stores.
  String get hex => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  @override
  int compareTo(Id128 other) {
    for (var i = 0; i < length; i++) {
      final d = bytes[i] - other.bytes[i];
      if (d != 0) return d;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType && compareTo(other as Id128) == 0;

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => hex;

  static Uint8List _check(List<int> bytes) {
    if (bytes.length != length) throw ArgumentError.value(bytes.length, 'bytes', 'must be $length bytes');
    for (final b in bytes) {
      if (b < 0 || b > 0xFF) throw ArgumentError.value(b, 'bytes', 'not a byte');
    }
    return Uint8List.fromList(bytes).asUnmodifiableView();
  }

  static Uint8List _parseHex(String hex) {
    if (hex.length != length * 2 || !RegExp(r'^[0-9a-f]+$').hasMatch(hex)) {
      throw FormatException('expected $length lowercase hex bytes', hex);
    }
    return Uint8List.fromList([
      for (var i = 0; i < length; i++) int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
    ]).asUnmodifiableView();
  }
}

/// A device's change-sequence origin (D6b): random 128-bit value.
final class OriginId extends Id128 {
  OriginId(super.bytes);
  OriginId.fromHex(super.hex) : super.fromHex();
}

/// A sync group (D7): random 128-bit value.
final class GroupId extends Id128 {
  GroupId(super.bytes);
  GroupId.fromHex(super.hex) : super.fromHex();
}

/// Group-key epoch id `(counter, creator member id)`, totally ordered (D7).
///
/// The counter is bounded by [maxCounter] (2^53) so that a rotation
/// (`counter + 1`) can never wrap and the value is exact on every platform;
/// decoders reject larger counters.
final class EpochId implements Comparable<EpochId> {
  EpochId(this.counter, this.creator) {
    if (counter < 1) throw ArgumentError.value(counter, 'counter', 'must be >= 1');
    if (counter > maxCounter) throw ArgumentError.value(counter, 'counter', 'must be <= $maxCounter');
    if (creator.isEmpty) throw ArgumentError.value(creator, 'creator', 'must not be empty');
  }

  /// Largest valid epoch counter (2^53).
  static const maxCounter = 0x20000000000000;

  final int counter;

  /// Member id of the device that created the epoch.
  final String creator;

  @override
  int compareTo(EpochId other) {
    final byCounter = counter.compareTo(other.counter);
    return byCounter != 0 ? byCounter : creator.compareTo(other.creator);
  }

  @override
  bool operator ==(Object other) => other is EpochId && other.counter == counter && other.creator == creator;

  @override
  int get hashCode => Object.hash(counter, creator);

  @override
  String toString() => 'Epoch($counter, $creator)';
}
