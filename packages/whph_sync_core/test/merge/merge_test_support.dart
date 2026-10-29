import 'package:whph_sync_core/whph_sync_core.dart';

/// Merged cell state: the winning version of every cell.
typedef CellState = Map<CellKey, CellRecord>;

CellRecord cell(
  String table,
  String pk,
  String col,
  Object? value, {
  required int hlc,
  required String node,
  int seq = 1,
  RowRef? cause,
}) =>
    CellRecord(
      key: CellKey(table, pk, col),
      value: value,
      clock: hlc,
      node: node,
      origin: 'origin-$node',
      originSeq: seq,
      cause: cause,
    );

/// Merges [incoming] into a copy of [state].
CellState mergeInto(CellState state, Iterable<CellRecord> incoming) {
  final result = Map.of(state);
  for (final record in incoming) {
    result[record.key] = mergeCell(result[record.key], record);
  }
  return result;
}

CellState stateOf(Iterable<CellRecord> cells) => mergeInto({}, cells);

/// Row lookup over a merged state.
RowCellsLookup lookupIn(CellState state) {
  final rows = <RowRef, List<CellRecord>>{};
  for (final record in state.values) {
    rows.putIfAbsent(record.key.row, () => []).add(record);
  }
  return (row) {
    final cells = rows[row];
    return cells == null ? null : CellListRow(cells);
  };
}

RowExistence existenceIn(CellState state, String table, String pk) => rowExistence(RowRef(table, pk), lookupIn(state));

/// Whether two states hold the same version of every cell.
bool sameState(CellState a, CellState b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || compareCellVersions(entry.value, other) != 0) return false;
  }
  return true;
}
