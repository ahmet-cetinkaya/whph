import 'dart:async';

import 'package:whph/core/application/features/sync/models/sync_run_report.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runner.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Time between two automatic sync runs (FR-008).
const Duration defaultSyncInterval = Duration(minutes: 5);

const String _component = 'SyncScheduler';

/// Starts a sync run every [interval] while it is started, and on request
/// ("sync now", all peers or one). A run that is still in progress when the
/// next one is due is not started twice.
class SyncScheduler {
  final ISyncRunner _engine;
  final Duration _interval;
  Timer? _timer;
  bool _runInProgress = false;

  SyncScheduler(this._engine, {Duration interval = defaultSyncInterval}) : _interval = interval;

  bool get isStarted => _timer != null;

  /// Starts the periodic runs; the first one is due after one interval.
  void start() {
    _timer ??= Timer.periodic(_interval, (_) => unawaited(_runPeriodic()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Runs one sync now with [memberId], or with every peer when it is `null`.
  Future<SyncRunReport> syncNow({String? memberId}) =>
      memberId == null ? _engine.syncAll() : _engine.syncPeer(memberId);

  Future<void> _runPeriodic() async {
    if (_runInProgress) return;
    _runInProgress = true;
    try {
      await _engine.syncAll();
    } on Object catch (error) {
      Logger.warning('periodic sync failed: ${error.runtimeType}', component: _component);
    } finally {
      _runInProgress = false;
    }
  }
}
