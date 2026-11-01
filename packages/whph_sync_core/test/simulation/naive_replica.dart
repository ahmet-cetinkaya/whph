import 'package:whph_sync_core/whph_sync_core.dart';

/// Deliberately naive last-writer-wins by local wall clock.
///
/// Stamps are the device's raw wall time, there is no causal or HLC tracking,
/// and exact ties go to the smaller node. With skewed clocks a device that had
/// already received a change can lose to it (FR-003 violated), so the
/// simulator's oracle must catch it. Used only as the harness self-check.
final class NaiveWallClockPolicy implements MergePolicy {
  @override
  int stampLocal(int nowMs) => nowMs;

  @override
  void observeRemote(CellRecord remote) {}

  @override
  int compare(CellRecord a, CellRecord b) {
    if (a.clock != b.clock) return a.clock.compareTo(b.clock);
    return b.node.compareTo(a.node);
  }
}

ReplicaStore createNaiveReplica(String nodeId) => InMemoryReplicaStore(nodeId: nodeId, policy: NaiveWallClockPolicy());
