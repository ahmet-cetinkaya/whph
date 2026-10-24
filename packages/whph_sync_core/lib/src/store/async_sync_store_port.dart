/// The asynchronous cell-level store the async session engine runs over
/// (T22b): the exact queries and writes `AsyncSyncSession` needs, so a
/// database-backed store (Drift) can serve the same protocol as the
/// in-memory [SyncStore]. Semantics of every method are those of the
/// same-named [SyncStore] member.
library;

import '../protocol/messages.dart';
import '../model/ids.dart';
import '../model/change.dart';
import '../model/manifest.dart';
import 'replica_store.dart';
import 'sync_store.dart';

/// The next send-scan candidates of one origin (see
/// [AsyncSyncStorePort.nextOfOrigin]).
typedef OriginScanEntry = ({StoredCell? cell, HeldEnvelope? held, (int, CellKey)? superseded});

abstract interface class AsyncSyncStorePort {
  // --- Local state ---------------------------------------------------------------

  /// The current own origin.
  Future<OriginId> localOrigin();

  /// The seq the next own write gets.
  Future<int> nextSeq();

  /// The current hybrid logical clock value.
  Future<int> hlc();

  /// The highest own seq covered by a signed manifest.
  Future<int> ownSignedTo();

  /// The version vector (own origin included, `next_seq − 1`).
  Future<Map<String, int>> vector();

  /// Every origin registration held.
  Future<List<OriginRegistration>> registrations();

  // --- Cells ---------------------------------------------------------------------

  Future<StoredCell?> storedCell(CellKey key);

  /// The first stored cell of [origin] with a seq above [afterSeq].
  Future<StoredCell?> nextCellOfOrigin(String origin, int afterSeq);

  /// The next cell, held envelope and superseded entry of [origin] above
  /// [afterSeq], read as one consistent snapshot. The send scan must not read
  /// them one by one: a concurrent held retry moves an item between the three
  /// and the scan would skip its seq.
  Future<OriginScanEntry> nextOfOrigin(String origin, int afterSeq);

  /// Origins of which at least one cell is stored.
  Future<List<String>> cellOrigins();

  /// Own cells of the current origin with seq in `(fromSeq, toSeq]`.
  Future<List<CellRecord>> ownCellsInRange(int fromSeq, int toSeq);

  /// Attaches a freshly signed own manifest to the cells it covers.
  Future<void> attachOwnManifest(OriginManifest manifest);

  // --- Superseded index (F5) -----------------------------------------------------

  Future<(int, CellKey)?> nextSupersededOfOrigin(String origin, int afterSeq);

  Future<void> dropSupersededEntry(String origin, int seq);

  Future<int> supersededIndexed();

  // --- Received data -------------------------------------------------------------

  /// Applies one verified remote change (one savepoint on a database).
  Future<ApplyOutcome> applyRemote(Change change, OriginManifest manifest, {required int nowMs});

  /// Advances the cursor of [origin] for a committed declared range (D15).
  Future<bool> advanceCursor(String origin, {required int fromSeq, required int toSeq});

  /// Records that a received version was committed (diagnostics).
  Future<void> logCommit(String origin, int seq);

  /// Runs [body] as one atomic unit (the batch transaction).
  Future<T> inTransaction<T>(Future<T> Function() body);

  // --- Held envelopes ------------------------------------------------------------

  Future<List<HeldEnvelope>> heldEnvelopes();

  Future<HeldEnvelope?> heldAt(String origin, int seq);

  /// Inserts or updates [held]; an existing entry for the same
  /// `(origin, seq)` keeps its higher fail count.
  Future<void> putHeld(HeldEnvelope held);

  Future<bool> removeHeld(String origin, int seq);

  /// Whether a version at least as new as [held] is already stored.
  Future<bool> isSuperseded(HeldEnvelope held);

  Future<void> dropSupersededHeld(HeldEnvelope held);

  // --- Security view -------------------------------------------------------------

  /// An in-memory [SyncStore] holding the security cells and registrations,
  /// which `Membership` reads and extends. A database store builds it afresh
  /// on each call; the in-memory store returns itself.
  Future<SyncStore> securityProjection();

  /// Stores registration rows `Membership` accepted into the projection.
  Future<void> persistRegistrations(Iterable<OriginRegistration> rows);
}
