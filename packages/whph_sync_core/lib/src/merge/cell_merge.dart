/// Per-cell last-writer-wins merge and effective row existence (D1, D5b).
///
/// Every function here is pure and deterministic: the result depends only on
/// the synced cells, so every replica computes the same outcome whatever the
/// order in which it received them (FR-002..FR-007, FR-013).
library;

import '../clock/hlc.dart';
import '../store/replica_store.dart';

/// Total order over versions of one cell: positive when [a] wins over [b],
/// negative when [b] wins, zero only for identical versions.
///
/// Versions are ordered by `(hlc, node)` (D2). Two distinct versions never
/// share `(hlc, node)` in a correct system, because each author's HLC is
/// strictly increasing; should it happen anyway (corrupt or replayed data), a
/// fixed fallback on origin, origin seq, value and cause keeps the merge
/// deterministic, commutative and associative.
int compareCellVersions(CellRecord a, CellRecord b) {
  final byVersion = Hlc.compareVersions(a.clock, a.node, b.clock, b.node);
  if (byVersion != 0) return byVersion;
  final byOrigin = b.origin.compareTo(a.origin);
  if (byOrigin != 0) return byOrigin;
  final bySeq = a.originSeq.compareTo(b.originSeq);
  if (bySeq != 0) return bySeq;
  final byValue = _compareValues(a.value, b.value);
  if (byValue != 0) return byValue;
  return _compareCauses(a.cause, b.cause);
}

/// Whether [incoming] replaces [current]: only a strictly winning version
/// does, so a stale version never overwrites a newer one (FR-007) and
/// re-applying the held version is a no-op (FR-013).
bool incomingWins(CellRecord? current, CellRecord incoming) =>
    current == null || compareCellVersions(incoming, current) > 0;

/// The version of the cell to keep after merging [incoming] into [current].
///
/// Throws [ArgumentError] when both versions are not of the same cell.
CellRecord mergeCell(CellRecord? current, CellRecord incoming) {
  if (current != null && current.key != incoming.key) {
    throw ArgumentError.value(incoming.key, 'incoming', 'differs from the current cell ${current.key}');
  }
  return incomingWins(current, incoming) ? incoming : current!;
}

/// Effective existence of an item.
enum RowExistence {
  /// No cell of the row is known.
  absent,

  /// The row exists and is not effectively deleted.
  alive,

  /// The row's tombstone is effective.
  deleted,
}

/// The winning cells of one row, as held by a store.
abstract interface class RowCells {
  /// The winning existence (`~`) cell, or `null` when none is known.
  CellRecord? get existence;

  /// The winning versions of every other cell of the row.
  Iterable<CellRecord> get dataCells;
}

/// Looks up the winning cells of [row]; `null` when the row is unknown.
typedef RowCellsLookup = RowCells? Function(RowRef row);

/// A [RowCells] over the winning cells of one row (the `~` cell is picked
/// out; when several are given, the last one is used).
final class CellListRow implements RowCells {
  factory CellListRow(Iterable<CellRecord> cells) {
    CellRecord? existence;
    final data = <CellRecord>[];
    for (final cell in cells) {
      if (cell.key.isExistence) {
        existence = cell;
      } else {
        data.add(cell);
      }
    }
    return CellListRow._(existence, List.unmodifiable(data));
  }

  const CellListRow._(this.existence, this.dataCells);

  @override
  final CellRecord? existence;

  @override
  final List<CellRecord> dataCells;
}

/// The data cell of [row] with the greatest `(hlc, node)`, or `null`.
CellRecord? maxDataCell(RowCells row) {
  CellRecord? max;
  for (final cell in row.dataCells) {
    if (max == null || Hlc.compareVersions(cell.clock, cell.node, max.clock, max.node) > 0) max = cell;
  }
  return max;
}

/// Whether the row's own tombstone is in force, ignoring any cascade cause:
/// its `~` cell is a tombstone (non-null value) whose `(hlc, node)` beats the
/// row's max other-cell `(hlc, node)`. A later edit of any other cell revives
/// the row with the edited data and every other field per its own cell
/// (FR-006).
bool isOwnTombstoneInForce(RowCells row) {
  final tomb = row.existence;
  if (tomb == null || tomb.value == null) return false;
  final edit = maxDataCell(row);
  return edit == null || Hlc.compareVersions(tomb.clock, tomb.node, edit.clock, edit.node) >= 0;
}

/// Effective existence of [row] (FR-006, D5b).
///
/// * No known cell: [RowExistence.absent].
/// * No `~` cell, a revival `~` (null value), or a tombstone beaten by a later
///   edit of another cell of the row: [RowExistence.alive].
/// * A tombstone in force without cause: [RowExistence.deleted] (children
///   deleted independently stay deleted).
/// * A tombstone in force with cause P: deleted only while P is effectively
///   deleted or absent; alive while P is effectively alive.
///
/// A cause cycle (never produced by D3, but possible in corrupt data) counts
/// as deleted, so the result stays a pure function of the cells.
RowExistence rowExistence(RowRef row, RowCellsLookup lookup) => _existence(row, lookup, <RowRef>{});

/// Whether [row] is effectively alive (see [rowExistence]).
bool isRowEffectivelyAlive(RowRef row, RowCellsLookup lookup) => rowExistence(row, lookup) == RowExistence.alive;

RowExistence _existence(RowRef row, RowCellsLookup lookup, Set<RowRef> visiting) {
  final cells = lookup(row);
  if (cells == null || (cells.existence == null && cells.dataCells.isEmpty)) return RowExistence.absent;
  if (!isOwnTombstoneInForce(cells)) return RowExistence.alive;
  final cause = cells.existence!.cause;
  if (cause == null || !visiting.add(row)) return RowExistence.deleted;
  final causeExistence = _existence(cause, lookup, visiting);
  visiting.remove(row);
  return causeExistence == RowExistence.alive ? RowExistence.alive : RowExistence.deleted;
}

/// Orders cell values: null < int < String.
int _compareValues(Object? a, Object? b) {
  final rank = _valueRank(a).compareTo(_valueRank(b));
  if (rank != 0) return rank;
  if (a is int && b is int) return a.compareTo(b);
  if (a is String && b is String) return a.compareTo(b);
  if (a == null && b == null) return 0;
  return a.toString().compareTo(b.toString());
}

int _valueRank(Object? value) => switch (value) {
      null => 0,
      int() => 1,
      String() => 2,
      _ => 3,
    };

int _compareCauses(RowRef? a, RowRef? b) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : -1) : 1;
  return a.compareTo(b);
}
