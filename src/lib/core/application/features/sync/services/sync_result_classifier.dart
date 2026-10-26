import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// The status category a session [result] leaves on its peer (FR-016), or
/// `null` when the result leaves none: a complete session, a session that
/// did not run (`busy`) and local states (not paired, removed from the group)
/// that no peer causes.
SyncResultCategory? classifySessionResult(SessionResult result) => switch (result) {
      SessionComplete() => null,
      SessionPartial(:final reasons) => _classifyPartial(reasons),
      SessionFailed(:final category) => _classifyFailure(category),
    };

SyncResultCategory _classifyPartial(Set<PartialReason> reasons) {
  if (reasons.contains(PartialReason.storageError)) return SyncResultCategory.storageError;
  if (reasons.contains(PartialReason.itemsRejected)) return SyncResultCategory.rejectedItems;
  return SyncResultCategory.someItemsFailed;
}

SyncResultCategory? _classifyFailure(SessionFailure failure) => switch (failure) {
      SessionFailure.notReachable => SyncResultCategory.notReachable,
      SessionFailure.notAuthorized || SessionFailure.refusedByPeer => SyncResultCategory.needsRepairing,
      SessionFailure.needsUpdate => SyncResultCategory.needsUpdate,
      SessionFailure.peerPreparing || SessionFailure.restoreDetected => SyncResultCategory.preparing,
      SessionFailure.protocolError || SessionFailure.securityError => SyncResultCategory.rejectedItems,
      SessionFailure.peerError || SessionFailure.internal => SyncResultCategory.someItemsFailed,
      SessionFailure.busy || SessionFailure.notPaired || SessionFailure.removedFromGroup => null,
    };

/// Whether [result] says nothing about the peer (the peer was busy, or a local
/// state stopped the session), so the peer's status stays as it was.
bool leavesStatusUnchanged(SessionResult result) =>
    result is SessionFailed &&
    (result.category == SessionFailure.busy ||
        result.category == SessionFailure.notPaired ||
        result.category == SessionFailure.removedFromGroup);
