import 'package:whph_sync_core/whph_sync_core.dart';

/// Outcome of applying one received batch (D15: one transaction per batch,
/// one savepoint per item).
class SyncApplyReport {
  /// Items whose version won and was stored.
  final int applied;

  /// Items with the same or an older version (idempotent re-delivery, FR-013).
  final int unchanged;

  /// Items recorded but not yet visible in a base row (D15 staging, or a cell
  /// of a column this build does not know, FR-042).
  final int held;

  /// Items whose savepoint rolled back; each is recorded in
  /// `sync_held_envelope` (FR-010, FR-011).
  final int failed;

  /// Whether `sync_vector` moved to the batch's declared bound.
  final bool cursorAdvanced;

  const SyncApplyReport({
    this.applied = 0,
    this.unchanged = 0,
    this.held = 0,
    this.failed = 0,
    this.cursorAdvanced = false,
  });
}

/// Result of [ISyncChangeStore.switchOrigin].
class SyncOriginSwitchReport {
  final String oldOrigin;
  final String newOrigin;

  /// Cursor set for the sealed old origin; `null` when the vector was cleared.
  final int? sealedCursor;

  /// Whether the `reauthor` upgrade phase was scheduled (adoption or
  /// group-switch re-authoring runs in `SyncUpgradeJob`).
  final bool reauthorScheduled;

  const SyncOriginSwitchReport({
    required this.oldOrigin,
    required this.newOrigin,
    required this.sealedCursor,
    required this.reauthorScheduled,
  });
}

/// Drift-backed replica store of the synced user tables (D1, D4, D5b, D6b,
/// D14, D15). All methods are asynchronous because the shared Drift
/// connection is (the package `ReplicaStore` port is synchronous, see
/// `DriftSyncChangeStore`).
abstract interface class ISyncChangeStore {
  /// The received vector (`sync_vector`) plus this device's own origin at
  /// `next_seq - 1`.
  Future<Map<String, int>> readVector();

  /// The changes of [origin] with seq above [afterSeq], ascending, at most
  /// [limit] cells, up to the declared bound [upToSeq] (default: the vector
  /// entry of [origin]). Values are joined from base rows and held cells.
  Future<ChangeBatch> readChanges(
    String origin, {
    required int afterSeq,
    int? upToSeq,
    int limit = 256,
  });

  /// Merges [batch] on the shared connection with `apply_mode = 1`.
  Future<SyncApplyReport> applyBatch(ChangeBatch batch);

  /// D6b `switch_origin(reason)`, step 2 (one transaction, `apply_mode = 3`).
  /// The caller performs ledger steps 1 and 3. [sentMark] is `max_sent_seq`;
  /// [hlcFloor] is the ledger's `hlc_high` (restore only).
  Future<SyncOriginSwitchReport> switchOrigin(
    OriginSwitchReason reason, {
    required String newOrigin,
    int? sentMark,
    int hlcFloor = 0,
  });

  /// D14 `local_reset`: one transaction holding `switch_origin(local_reset)`
  /// step 2, the truncation of the user tables ([clearUserData]) and, with
  /// `apply_mode = 0`, the imported rows ([importRows]).
  Future<SyncOriginSwitchReport> localReset({
    required String newOrigin,
    Future<void> Function()? clearUserData,
    Future<void> Function()? importRows,
  });
}
