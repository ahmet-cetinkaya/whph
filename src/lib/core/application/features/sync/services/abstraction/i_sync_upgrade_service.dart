import 'package:whph/core/domain/shared/utils/logger.dart';

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

extension SyncUpgradeBackgroundRun on ISyncUpgradeService {
  /// Starts [ISyncUpgradeService.run] without waiting: sync and pairing stay gated until `done`,
  /// so a trigger (origin switch, stuck phase) must not block its caller. Failures are logged.
  void runInBackground() {
    run().catchError((Object error, StackTrace stackTrace) {
      Logger.error('Sync upgrade job failed: $error', component: 'SyncUpgrade', error: error, stackTrace: stackTrace);
    });
  }
}
