/// Session outcomes `{complete | partial(reasons) | failed(category)}` and
/// per-session counters (D15, FR-016).
library;

import '../protocol/version.dart';

/// Why a session that exchanged its data is not fully successful.
enum PartialReason {
  /// Some received items could not be applied (FR-011; held `apply_failed`).
  itemsFailed,

  /// Some received items were rejected (tampered, revoked above cutoff,
  /// unverifiable; FR-015, FR-021) and counted.
  itemsRejected,

  /// The sent-seq mark could not be persisted; sending stopped (D7).
  storageError,
}

/// Why a session failed before completing its exchange.
enum SessionFailure {
  /// The transport closed or was cut (FR-016 "not reachable"; resumes per
  /// FR-012).
  notReachable,

  /// The peer's static key is not a non-revoked member (FR-020, FR-028).
  notAuthorized,

  /// The peer closed right after authentication (it refused this device:
  /// FR-016 "needs re-pairing" from this side).
  refusedByPeer,

  /// Protocol versions are incompatible (FR-041).
  needsUpdate,

  /// Another session with this peer is running (D15 arbitration).
  busy,

  /// The peer's cursor for this device's origin is ahead: the local DB is
  /// behind; `switch_origin(restore)` ran and the session must be retried
  /// (D15).
  restoreDetected,

  /// The peer is preparing (upgrade job, origin switch) and asked to retry.
  peerPreparing,

  /// The peer aborted with an error category.
  peerError,

  /// A malformed, oversized or unexpected message (FR-015).
  protocolError,

  /// Noise failure: a replayed, reordered or altered frame (FR-022).
  securityError,

  /// This device is not in a group.
  notPaired,

  /// This device was removed from the group.
  removedFromGroup,

  /// An unexpected local error (a bug); see [SessionFailed.error].
  internal,
}

/// Counters of one session (never values or key material).
final class SessionStats {
  int batchesSent = 0;
  int envelopesSent = 0;
  int refetchSent = 0;

  /// Cells held above this store's own cursor, served with single-seq
  /// ranges (after `local_reset`).
  int aboveCursorSent = 0;
  int heldRelayed = 0;

  /// Superseded versions in the store's index at the end of the session (F5).
  int supersededIndexed = 0;
  int manifestsSigned = 0;

  /// `origin#seq` of every envelope sent in this session (FR-014 checks).
  final List<String> sentVersions = [];

  int batchesApplied = 0;
  int envelopesReceived = 0;
  int applied = 0;
  int unchanged = 0;
  int failed = 0;
  int heldMissingKey = 0;
  int heldUnverified = 0;
  int heldRetriedApplied = 0;
  int rejected = 0;
  final Map<String, int> rejectedByReason = {};

  /// Keys handed to / received from the peer.
  int keysHandedOver = 0;
  int keysReceived = 0;

  /// Largest number of unacknowledged batches at the moment an ack arrived
  /// (> 1 means the sender kept streaming while the receiver applied, PA-2).
  int maxUnackedAtAck = 0;

  /// Largest number of batches in flight at any time.
  int maxInFlight = 0;

  int framesSent = 0;
  int bytesSent = 0;

  void reject(String reason) {
    rejected++;
    rejectedByReason[reason] = (rejectedByReason[reason] ?? 0) + 1;
  }

  @override
  String toString() => 'SessionStats(sent=$envelopesSent in $batchesSent batches, applied=$applied, '
      'unchanged=$unchanged, failed=$failed, held=${heldMissingKey + heldUnverified}, rejected=$rejected, '
      'maxInFlight=$maxInFlight)';
}

/// The outcome of one session, as seen by one side.
sealed class SessionResult {
  const SessionResult(this.stats, this.peerMemberId);

  final SessionStats stats;

  /// The authenticated peer, when known.
  final String? peerMemberId;

  bool get isComplete => this is SessionComplete;

  /// Complete or partial: the data exchange finished.
  bool get exchanged => this is SessionComplete || this is SessionPartial;
}

/// Every received change applied, every change sent (FR-016 success).
final class SessionComplete extends SessionResult {
  const SessionComplete(super.stats, super.peerMemberId);

  @override
  String toString() => 'SessionComplete($stats)';
}

/// The exchange finished but the session is not fully successful.
final class SessionPartial extends SessionResult {
  SessionPartial(super.stats, super.peerMemberId, Set<PartialReason> reasons) : reasons = Set.unmodifiable(reasons);

  final Set<PartialReason> reasons;

  @override
  String toString() => 'SessionPartial(${reasons.map((r) => r.name).join(', ')}, $stats)';
}

/// The session ended before its exchange finished.
final class SessionFailed extends SessionResult {
  const SessionFailed(
    super.stats,
    super.peerMemberId,
    this.category, {
    this.mustUpdate,
    this.peerCursor,
    this.error,
  });

  final SessionFailure category;

  /// For [SessionFailure.needsUpdate]: the device that must update.
  final DeviceRef? mustUpdate;

  /// For [SessionFailure.restoreDetected]: the peer's cursor for this
  /// device's origin.
  final int? peerCursor;

  /// For [SessionFailure.internal] (and diagnostics): the local error.
  final Object? error;

  @override
  String toString() => 'SessionFailed(${category.name}${error == null ? '' : ': $error'}, $stats)';
}
