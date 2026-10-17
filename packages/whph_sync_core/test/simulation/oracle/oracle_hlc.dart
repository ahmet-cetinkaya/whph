/// The oracle's own hybrid logical clock (D2), independent of the package.
///
/// Packed as `wall_ms << 16 | counter`. Local tick: `max(prev + 1, now << 16)`
/// (a counter overflow carries into the wall part). Receive:
/// `max(local, remote)`. Versions are ordered by `(hlc, node)`: the larger HLC
/// wins and an exact HLC tie is won by the lexicographically smaller node.
///
/// The engine's full order (`compareCellVersions`) continues after an exact
/// `(hlc, node)` tie with origin (smaller wins), then origin seq. The oracle
/// does not model those two keys, and stays exact without them: a version is
/// identified by `(table, pk, col, node, hlc)` and survives re-authoring
/// (adoption on `switch_origin`, group-switch re-author), which changes only
/// its origin and seq. Two distinct recorded writes of one cell therefore never
/// tie on `(hlc, node)`: such a pair is reported as
/// `OracleViolationKind.ambiguousVersion` at recording time. Copies of one
/// version that differ only in origin and seq stand for the same write, so
/// whichever copy the engine keeps carries the same value and cause.
library;

const oracleCounterBits = 16;
const oracleCounterMask = (1 << oracleCounterBits) - 1;

int oracleHlcPack(int wallMs, int counter) => (wallMs << oracleCounterBits) | (counter & oracleCounterMask);

int oracleHlcWall(int hlc) => hlc >> oracleCounterBits;

int oracleHlcCounter(int hlc) => hlc & oracleCounterMask;

/// Positive when version `(hlcA, nodeA)` wins over `(hlcB, nodeB)`.
int oracleCompareVersions(int hlcA, String nodeA, int hlcB, String nodeB) {
  if (hlcA != hlcB) return hlcA.compareTo(hlcB);
  // Exact tie: the smaller node wins, so it compares as "greater".
  return nodeB.compareTo(nodeA);
}

/// HLC state of one simulated device.
final class OracleHlc {
  int _state = 0;

  int get current => _state;

  /// Stamps a local write made at local wall time [nowMs].
  int tick(int nowMs) {
    if (nowMs < 0) throw ArgumentError.value(nowMs, 'nowMs');
    final physical = oracleHlcPack(nowMs, 0);
    final next = _state + 1 > physical ? _state + 1 : physical;
    _state = next;
    return next;
  }

  /// Observes a received remote HLC.
  void receive(int remote) {
    if (remote > _state) _state = remote;
  }
}
