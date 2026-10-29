import '../clock/hlc.dart';
import '../store/merge_policy.dart';
import '../store/replica_store.dart';
import 'cell_merge.dart';

/// The real engine's [MergePolicy]: HLC stamping and receive (D2) with the
/// per-cell `(hlc, node)` order of [compareCellVersions].
///
/// [observeRemote] throws [MalformedHlcException] for an unrepresentable
/// remote HLC (FR-015) without changing the clock.
final class HlcMergePolicy implements MergePolicy {
  HlcMergePolicy({HlcClock? clock}) : clock = clock ?? HlcClock();

  final HlcClock clock;

  @override
  int stampLocal(int nowMs) => clock.tick(nowMs);

  @override
  void observeRemote(CellRecord remote) => clock.receive(remote.clock);

  @override
  int compare(CellRecord a, CellRecord b) => compareCellVersions(a, b);
}
