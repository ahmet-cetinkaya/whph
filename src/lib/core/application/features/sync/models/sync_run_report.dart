import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// The outcome of syncing with one peer.
class SyncPeerReport {
  final String memberId;

  /// The session result; `null` when no session ran.
  final SessionResult? result;

  /// The category left on the peer; `null` after a complete session.
  final SyncResultCategory? category;
  final bool itemsCannotBeApplied;

  const SyncPeerReport({
    required this.memberId,
    this.result,
    this.category,
    this.itemsCannotBeApplied = false,
  });
}

class SyncRunReport {
  final List<SyncPeerReport> peers;

  /// The run did not start because the upgrade job has not reached `done`
  /// (D17) or this device is not paired.
  final bool skipped;

  const SyncRunReport({this.peers = const [], this.skipped = false});
}
