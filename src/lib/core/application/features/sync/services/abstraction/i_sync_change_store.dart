import 'dart:typed_data';

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

  /// Origins for which a different canonical change was seen under an
  /// already-stored `(origin, seq)` (D14: a copied data directory).
  final Set<String> duplicateIdentityOrigins;

  const SyncApplyReport({
    this.applied = 0,
    this.unchanged = 0,
    this.held = 0,
    this.failed = 0,
    this.cursorAdvanced = false,
    this.duplicateIdentityOrigins = const {},
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

  /// Never-sent security cells (no manifest) that stay on the sealed origin
  /// after `restore` or `key_lost` (D14, U11/rooted).
  final int securityLeftBehind;

  const SyncOriginSwitchReport({
    required this.oldOrigin,
    required this.newOrigin,
    required this.sealedCursor,
    required this.reauthorScheduled,
    this.securityLeftBehind = 0,
  });

  /// The group must re-invite this device when its security rows could not
  /// be delivered.
  bool get needsRepairing => securityLeftBehind > 0;
}

/// The device's local sync state as the D14 startup check reads it.
class SyncLocalState {
  /// `sync_state.member_id`; `null` while the DB holds no sync identity.
  final String? memberId;
  final String localOrigin;

  /// The next own seq (`next_seq`); the highest authored seq is one below.
  final int nextSeq;
  final int hlc;

  const SyncLocalState({
    required this.memberId,
    required this.localOrigin,
    required this.nextSeq,
    required this.hlc,
  });
}

/// Drift-backed replica store of the synced user tables (D1, D4, D5b, D6b,
/// D14, D15). All methods are asynchronous because the shared Drift
/// connection is (the package `ReplicaStore` port is synchronous, so the
/// store implements `AsyncReplicaStore`).
abstract interface class ISyncChangeStore implements AsyncReplicaStore {
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
  /// [manifest] is the verified manifest covering [batch]; its id is attached
  /// to the stored cells. [peerMemberId] receives the duplicate-identity
  /// status when one is detected (D14).
  ///
  /// Reads (`readChanges`) may run while an apply is in flight (T12
  /// pipelining); each sees the state before or after the whole batch.
  Future<SyncApplyReport> applyBatch(
    ChangeBatch batch, {
    OriginManifest? manifest,
    String? peerMemberId,
  });

  /// Authors a security row (`sync_member`, `sync_revocation`,
  /// `sync_epoch_grant`) on the own origin: validates [record], stores the
  /// row and a clock row with a fresh HLC and seq. Security tables have no
  /// capture triggers, so this is the only local write path.
  Future<CellRecord> writeSecurityCell(CellKey key, Uint8List record);

  /// Builds, signs and persists manifests for the own cells above the last
  /// signed seq (chunks of at most `SyncLimits.maxBatchChanges`), setting
  /// `manifest_id` on the covered clock rows. Empty when nothing is unsigned.
  Future<List<OriginManifest>> signOwnManifests(ManifestSigner signer);

  /// Stored manifests of [origin] overlapping `(afterSeq, upToSeq]`, in seq
  /// order, to be forwarded verbatim.
  Future<List<OriginManifest>> readManifests(
    String origin, {
    required int afterSeq,
    required int upToSeq,
  });

  /// Keys of the items held after a failed apply (`sync_held_envelope`,
  /// reason `apply_failed`): the session sends them as `Refetch` and the
  /// re-delivered cell goes through `applyBatch` again (FR-010, FR-011).
  Future<List<CellKey>> refetchKeys();

  /// The own origin id (hex) that stamps local writes.
  Future<String> localOrigin();

  /// Renames the placeholder origin of a database that never had a sync
  /// identity (`local-origin-...`, written by `onCreate`) to [newOrigin], a
  /// random 128-bit id. Clock rows and `next_seq` stay: no peer ever saw the
  /// placeholder, so the rename cannot collide with a held `(origin, seq)`.
  Future<void> adoptInitialOrigin(String newOrigin);

  /// Identity, origin, `next_seq` and HLC of this device (D14 startup check).
  Future<SyncLocalState> readLocalState();

  /// Every stored security row (`sync_member`, `sync_revocation`,
  /// `sync_epoch_grant`) as a row-level `*` cell with its carrier origin and
  /// seq, in carrier order. The membership service rebuilds its view from it
  /// (D13).
  Future<List<CellRecord>> readSecurityCells();

  /// Stamps the local identity on `sync_state`: [memberId] becomes the node of
  /// local writes, [groupId] (hex, `null` when ungrouped) is what manifests
  /// sign over (D7). Called on group creation, join, switch and key loss.
  Future<void> bindIdentity({required String memberId, String? groupId});

  /// Stored `sync_origin` registrations, sent first in every session (D7).
  Future<List<OriginRegistration>> readRegistrations();

  /// Stores unknown registrations; returns how many were new.
  Future<int> mergeRegistrations(Iterable<OriginRegistration> registrations);

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
