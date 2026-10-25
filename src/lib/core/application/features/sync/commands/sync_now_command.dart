import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/sync_run_report.dart';
import 'package:whph/core/application/features/sync/services/sync_scheduler.dart';

/// Starts a sync session now with every peer, or with [memberId] only.
class SyncNowCommand implements IRequest<SyncNowCommandResponse> {
  final String? memberId;

  SyncNowCommand({this.memberId});
}

class SyncNowCommandResponse {
  final SyncRunReport report;

  const SyncNowCommandResponse(this.report);

  /// Every session that ran ended complete; a run that had nothing to do
  /// (not paired, or the upgrade job is still running) counts as complete.
  bool get isComplete => report.skipped || report.peers.every((peer) => peer.result?.isComplete ?? false);

  bool get hasErrors => report.peers.any((peer) => peer.category != null);

  int get syncedDeviceCount => report.peers.where((peer) => peer.result?.exchanged ?? false).length;
}

class SyncNowCommandHandler implements IRequestHandler<SyncNowCommand, SyncNowCommandResponse> {
  final SyncScheduler _scheduler;

  SyncNowCommandHandler(this._scheduler);

  @override
  Future<SyncNowCommandResponse> call(SyncNowCommand request) async =>
      SyncNowCommandResponse(await _scheduler.syncNow(memberId: request.memberId));
}
