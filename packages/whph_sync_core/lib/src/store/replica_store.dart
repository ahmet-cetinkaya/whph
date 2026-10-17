/// Storage abstraction for one replica (device) of the synced data set.
///
/// The model is per-cell (D1): every synced column of a row is a cell with its
/// own clock metadata, row-level tables use the single cell `*`, and every row
/// has an existence cell `~` whose value is the row's `deleted_date`
/// (`null` = alive, non-null = tombstone).
library;

/// Identifies one replicated cell: column [col] of row [pk] in [table].
final class CellKey {
  const CellKey(this.table, this.pk, this.col);

  /// Wire name of the existence cell (value = `deleted_date`).
  static const existenceCol = '~';

  /// Wire name of the single cell of a row-level table.
  static const rowCol = '*';

  final String table;
  final String pk;
  final String col;

  bool get isExistence => col == existenceCol;

  @override
  bool operator ==(Object other) => other is CellKey && other.table == table && other.pk == pk && other.col == col;

  @override
  int get hashCode => Object.hash(table, pk, col);

  /// The row this cell belongs to.
  RowRef get row => RowRef(table, pk);

  @override
  String toString() => '$table/$pk/$col';
}

/// Identifies one replicated row (item): row [pk] of [table].
///
/// Also the wire form of a tombstone's cascade cause, `(table name, pk)` (D1).
final class RowRef implements Comparable<RowRef> {
  const RowRef(this.table, this.pk);

  final String table;
  final String pk;

  @override
  int compareTo(RowRef other) {
    final byTable = table.compareTo(other.table);
    return byTable != 0 ? byTable : pk.compareTo(other.pk);
  }

  @override
  bool operator ==(Object other) => other is RowRef && other.table == table && other.pk == pk;

  @override
  int get hashCode => Object.hash(table, pk);

  @override
  String toString() => '$table/$pk';
}

/// One stored version of a cell together with its clock metadata.
///
/// [clock] is an ordering stamp owned by the store's merge policy (a packed HLC
/// in the real engine, D2). [node] is the authoring member id; [origin] and
/// [originSeq] identify the write in the author's local change sequence and
/// drive sync cursors. [cause] is set only on an existence (`~`) cell written
/// by a cascading delete: the item whose deletion cascaded to this row (D3, D5b).
final class CellRecord {
  const CellRecord({
    required this.key,
    required this.value,
    required this.clock,
    required this.node,
    required this.origin,
    required this.originSeq,
    this.cause,
  });

  final CellKey key;

  /// Cell value: a `String`, an `int` or `null`.
  final Object? value;
  final int clock;
  final String node;
  final String origin;
  final int originSeq;
  final RowRef? cause;

  @override
  String toString() => '$key=$value@$clock/$node($origin#$originSeq${cause == null ? '' : ' cause=$cause'})';
}

/// A slice of one origin's change sequence covering seqs in `(fromSeq, toSeq]`.
///
/// [cells] holds every cell of [origin] in that range that the sender still
/// stores; seqs that are missing were superseded by other versions and need not
/// be transferred. An empty batch only advances the receiver's cursor.
final class ChangeBatch {
  const ChangeBatch({required this.origin, required this.fromSeq, required this.toSeq, required this.cells});

  final String origin;
  final int fromSeq;
  final int toSeq;
  final List<CellRecord> cells;

  @override
  String toString() => 'ChangeBatch($origin, ($fromSeq, $toSeq], ${cells.length} cells)';
}

/// One replica's cell store, merge and received-change vector.
///
/// Implementations must be deterministic: the same sequence of calls yields
/// the same state. Iteration orders are stable.
abstract interface class ReplicaStore {
  /// This replica's member id; used as the node of local writes.
  String get nodeId;

  /// Records a local edit of [key] at local wall time [nowMs] and returns the
  /// stored record. A local write always replaces the current version (it is
  /// what the user sees on this device).
  ///
  /// [cause] may only be set on an existence (`~`) cell: the item whose
  /// cascading delete wrote this tombstone (D3, D5b). Throws [ArgumentError]
  /// for a cause on any other cell.
  CellRecord writeLocal(CellKey key, Object? value, {required int nowMs, RowRef? cause});

  /// The current version of [key], or `null` when the cell is unknown.
  CellRecord? read(CellKey key);

  /// Every stored cell, in a stable order.
  Iterable<CellRecord> get cells;

  /// Every known row of [table] (by pk), in a stable order.
  Iterable<String> rowsOf(String table);

  /// Effective existence of a row (FR-006, D5b): alive when it has no `~`
  /// cell, a `~` cell with a `null` value, a `~` tombstone beaten by a later
  /// edit of another cell of the row, or a tombstone whose cascade cause is
  /// effectively alive. `false` for an unknown row.
  bool isRowAlive(String table, String pk);

  /// Per origin, the highest seq up to which this replica holds every change
  /// (or a version that supersedes it). Unmodifiable snapshot.
  Map<String, int> get vector;

  /// The batches a peer holding [peerVector] is missing, in a stable order,
  /// each with at most [maxCellsPerBatch] cells.
  List<ChangeBatch> changesSince(Map<String, int> peerVector, {int maxCellsPerBatch = 256});

  /// Merges a received batch. Returns `true` when any cell or the vector
  /// changed. Applying the same batch again is a no-op.
  bool applyBatch(ChangeBatch batch);
}
