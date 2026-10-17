/// Received-change vector of one replica (D6b, D15).
library;

/// Per origin, the highest seq up to which this replica holds every change of
/// that origin (or a version that supersedes it).
///
/// A received range `(fromSeq, toSeq]` advances the cursor to its declared
/// upper bound only when it is contiguous with the cursor
/// (`fromSeq <= cursor < toSeq`), so reordered or truncated delivery never
/// skips changes and duplicates are no-ops. Seqs of a declared range that
/// carry no cell were superseded at the sender and are still covered.
final class VersionVector {
  /// Creates a vector from [cursors]; every cursor must be non-negative.
  VersionVector([Map<String, int> cursors = const {}]) {
    for (final entry in cursors.entries) {
      _checkSeq(entry.value, 'cursors[${entry.key}]');
      if (entry.value > 0) _cursors[entry.key] = entry.value;
    }
  }

  final Map<String, int> _cursors = {};

  /// The cursor of [origin]; 0 when nothing of it was received.
  int cursorOf(String origin) => _cursors[origin] ?? 0;

  /// Origins with a non-zero cursor, sorted.
  List<String> get origins => _cursors.keys.toList()..sort();

  /// Unmodifiable snapshot of the non-zero cursors, keyed in sorted order.
  Map<String, int> toMap() => Map.unmodifiable({for (final o in origins) o: _cursors[o]!});

  /// Whether the change [seq] of [origin] is held or superseded here.
  bool covers(String origin, int seq) => cursorOf(origin) >= seq;

  /// Records the receipt of [origin]'s declared range `(fromSeq, toSeq]`.
  ///
  /// Returns `true` when the cursor advanced (to [toSeq]). A range that does
  /// not reach the cursor (gap) or lies below it (duplicate) changes nothing.
  /// Throws [ArgumentError] for a negative or inverted range.
  bool advance(String origin, {required int fromSeq, required int toSeq}) {
    _checkSeq(fromSeq, 'fromSeq');
    _checkSeq(toSeq, 'toSeq');
    if (toSeq < fromSeq) throw ArgumentError.value(toSeq, 'toSeq', 'must be >= fromSeq ($fromSeq)');
    final cursor = cursorOf(origin);
    if (fromSeq > cursor || toSeq <= cursor) return false;
    _cursors[origin] = toSeq;
    return true;
  }

  @override
  String toString() => 'VersionVector(${toMap()})';

  static void _checkSeq(int seq, String name) {
    if (seq < 0) throw ArgumentError.value(seq, name, 'must be non-negative');
  }
}
