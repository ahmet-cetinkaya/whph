import 'dart:async';

import 'package:whph/core/application/features/sync/models/sync_status.dart';

/// Tells which peer this device is syncing with and how far the session is,
/// so the sync devices page can show it on that peer's card only.
class SyncProgressTracker {
  final StreamController<SyncStatus> _controller = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus(state: SyncState.idle);

  SyncStatus get current => _current;

  /// Emits every change of [current].
  Stream<SyncStatus> get changes => _controller.stream;

  /// A session with [memberId] begins; its progress is not known yet.
  void begin(String memberId) => _publish(SyncStatus(state: SyncState.syncing, currentDeviceId: memberId));

  /// [processed] of [total] sequence numbers of the session with [memberId] are done.
  void report(String memberId, int processed, int total) {
    if (total <= 0) return;
    _publish(SyncStatus(
      state: SyncState.syncing,
      currentDeviceId: memberId,
      progress: (processed / total).clamp(0.0, 1.0),
    ));
  }

  /// The session with [memberId] ended, whatever its result.
  void end(String memberId) {
    if (_current.currentDeviceId != memberId) return;
    _publish(const SyncStatus(state: SyncState.idle));
  }

  void _publish(SyncStatus status) {
    _current = status;
    _controller.add(status);
  }
}
