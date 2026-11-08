/// Hybrid logical clock (Kulkarni 2014) as specified by D2.
///
/// An HLC is packed as `wall_ms << 16 | counter` in a signed 64-bit integer.
/// Versions are ordered by `(hlc, node)`: the larger HLC wins, and an exact
/// tie is won by the lexicographically smaller node (the author's member id),
/// the fixed device order of FR-004.
library;

/// Raised when a received HLC is not representable (FR-015): its wall part is
/// negative or at least [Hlc.wallLimitMs].
final class MalformedHlcException implements Exception {
  const MalformedHlcException(this.hlc, this.reason);

  /// The rejected packed value.
  final int hlc;
  final String reason;

  @override
  String toString() => 'MalformedHlcException($hlc): $reason';
}

/// Packing, validation and ordering of HLC values.
abstract final class Hlc {
  /// Number of low bits holding the logical counter.
  static const counterBits = 16;

  /// Largest counter value; one more carries into the wall part.
  static const counterMask = (1 << counterBits) - 1;

  /// Exclusive upper bound of the wall part in ms (2^46 ms, after year 4000).
  static const wallLimitMs = 1 << 46;

  /// Packs [wallMs] and [counter]. Throws [ArgumentError] when either is out
  /// of range.
  static int pack(int wallMs, int counter) {
    if (wallMs < 0 || wallMs >= wallLimitMs) throw ArgumentError.value(wallMs, 'wallMs', 'must be in [0, 2^46)');
    if (counter < 0 || counter > counterMask) throw ArgumentError.value(counter, 'counter', 'must be in [0, 0xFFFF]');
    return (wallMs << counterBits) | counter;
  }

  /// The wall part (ms since the Unix epoch) of a packed HLC.
  static int wallOf(int hlc) => hlc >> counterBits;

  /// The counter part of a packed HLC.
  static int counterOf(int hlc) => hlc & counterMask;

  /// Whether [hlc] is representable: non-negative with a wall part below
  /// [wallLimitMs].
  static bool isWellFormed(int hlc) => hlc >= 0 && wallOf(hlc) < wallLimitMs;

  /// Returns [hlc] or throws [MalformedHlcException] when it is not
  /// representable.
  static int checkWellFormed(int hlc) {
    if (hlc < 0) throw MalformedHlcException(hlc, 'negative wall time');
    if (wallOf(hlc) >= wallLimitMs) throw MalformedHlcException(hlc, 'wall time at or beyond 2^46 ms');
    return hlc;
  }

  /// Total order of versions `(hlcA, nodeA)` and `(hlcB, nodeB)`: positive
  /// when A wins, negative when B wins, zero for the same `(hlc, node)`.
  ///
  /// The larger HLC wins; an exact HLC tie is won by the smaller node.
  static int compareVersions(int hlcA, String nodeA, int hlcB, String nodeB) {
    if (hlcA != hlcB) return hlcA < hlcB ? -1 : 1;
    // Exact tie: the smaller node wins, so it compares as greater.
    return nodeB.compareTo(nodeA);
  }

  /// Human-readable `wall.counter` form for logs and test output.
  static String describe(int hlc) => '${wallOf(hlc)}.${counterOf(hlc)}';
}

/// The HLC state of one replica.
///
/// Local tick: `next = max(prev + 1, now_ms << 16)`; because the value is
/// packed, a counter overflow carries into the wall part. Receive:
/// `state = max(state, remote)` with no forward clamp; the only rejection is a
/// malformed (unrepresentable) remote value.
final class HlcClock {
  /// Starts at [initial] (e.g. the persisted `sync_state.hlc`), which must be
  /// well formed.
  HlcClock([int initial = 0]) : _state = _checkLocal(initial, 'initial');

  int _state;

  /// The last issued or observed HLC.
  int get current => _state;

  /// Stamps a local write made at local wall time [nowMs] and returns the
  /// new HLC, strictly greater than every previous [current].
  ///
  /// Throws [ArgumentError] when [nowMs] is out of range and [StateError]
  /// when the clock cannot advance within the representable range.
  int tick(int nowMs) {
    if (nowMs < 0 || nowMs >= Hlc.wallLimitMs) throw ArgumentError.value(nowMs, 'nowMs', 'must be in [0, 2^46)');
    final physical = nowMs << Hlc.counterBits;
    final logical = _state + 1;
    final next = logical > physical ? logical : physical;
    if (!Hlc.isWellFormed(next)) throw StateError('HLC exhausted: ${Hlc.describe(_state)}');
    return _state = next;
  }

  /// Observes the HLC of a received remote version. Any skew is accepted and
  /// advances the clock; a malformed value throws [MalformedHlcException] and
  /// leaves the clock unchanged.
  void receive(int remote) {
    Hlc.checkWellFormed(remote);
    if (remote > _state) _state = remote;
  }

  static int _checkLocal(int value, String name) {
    if (!Hlc.isWellFormed(value)) throw ArgumentError.value(value, name, 'not a well-formed HLC');
    return value;
  }
}
