import 'replica_store.dart';

/// Pluggable clock and conflict rule of a cell store such as `InMemoryReplicaStore`.
///
/// One instance belongs to one replica and may keep clock state (e.g. the HLC
/// of D2). The real engine (T9/T12) supplies an HLC policy; tests may supply
/// deliberately naive ones.
abstract interface class MergePolicy {
  /// The clock stamp for a local write made at local wall time [nowMs].
  int stampLocal(int nowMs);

  /// Called for every received remote record before it is merged, whether or
  /// not it wins (e.g. HLC receive).
  void observeRemote(CellRecord remote);

  /// Total order over versions of the same cell: positive when [a] wins over
  /// [b], negative when [b] wins, zero for the same version.
  int compare(CellRecord a, CellRecord b);
}
