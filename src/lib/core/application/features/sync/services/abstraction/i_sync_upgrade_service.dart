/// D17 phases of the resumable post-open upgrade, in execution order.
enum SyncUpgradePhase { dedupe, bootstrap, reauthor, done }

/// Where the upgrade job stands; UI (T23/T24) shows it, sync and pairing gate on [isDone].
class SyncUpgradeProgress {
  final SyncUpgradePhase phase;

  /// Opaque resume position inside [phase]; null before the phase starts.
  final String? cursor;

  const SyncUpgradeProgress({required this.phase, this.cursor});

  bool get isDone => phase == SyncUpgradePhase.done;
}

abstract class ISyncUpgradeService {
  Future<SyncUpgradeProgress> getProgress();

  /// Runs the job until phase `done`. Concurrent calls share one run.
  Future<void> run();
}
