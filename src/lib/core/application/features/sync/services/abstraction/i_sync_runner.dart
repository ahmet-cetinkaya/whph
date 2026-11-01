import 'package:whph/core/application/features/sync/models/sync_run_report.dart';

/// Runs sync sessions with the peers of the group.
abstract interface class ISyncRunner {
  Future<SyncRunReport> syncAll();

  Future<SyncRunReport> syncPeer(String memberId);
}
