import 'dart:collection';

import '../merge/cell_merge.dart';
import 'merge_policy.dart';
import 'replica_store.dart';

/// In-memory [ReplicaStore] keeping the latest version of every cell.
///
/// Clock stamping and conflict resolution are delegated to a [MergePolicy], so
/// the same store runs the naive policy of the T1 simulator and the HLC merge
/// of `HlcMergePolicy`. The real engine's store (per-origin cursors, manifests,
/// held envelopes, origin switch) is `SyncStore`.
///
/// Sync cursors: [vector] holds, per origin, the highest seq below which every
/// change is held or superseded. A received batch advances the cursor only when
/// it is contiguous with it (`fromSeq <= cursor < toSeq`), so reordered or
/// truncated delivery never skips changes; duplicates are no-ops.
final class InMemoryReplicaStore implements ReplicaStore {
  InMemoryReplicaStore({required this.nodeId, required this.policy});

  @override
  final String nodeId;

  final MergePolicy policy;

  /// table -> pk -> col -> record.
  final Map<String, Map<String, Map<String, CellRecord>>> _tables = {};

  /// origin -> originSeq -> record, for every stored record.
  final Map<String, SplayTreeMap<int, CellRecord>> _byOrigin = {};

  final Map<String, int> _vector = {};
  int _nextSeq = 0;

  @override
  CellRecord writeLocal(CellKey key, Object? value, {required int nowMs, RowRef? cause}) {
    if (cause != null && !key.isExistence) throw ArgumentError.value(cause, 'cause', 'only on an existence cell');
    final record = CellRecord(
      key: key,
      value: value,
      clock: policy.stampLocal(nowMs),
      node: nodeId,
      origin: nodeId,
      originSeq: ++_nextSeq,
      cause: cause,
    );
    _store(record);
    _vector[nodeId] = _nextSeq;
    return record;
  }

  @override
  CellRecord? read(CellKey key) => _tables[key.table]?[key.pk]?[key.col];

  @override
  Iterable<CellRecord> get cells sync* {
    for (final rows in _tables.values) {
      for (final row in rows.values) {
        yield* row.values;
      }
    }
  }

  @override
  Iterable<String> rowsOf(String table) => _tables[table]?.keys ?? const [];

  /// Cascade-aware (D5b): delegates to [rowExistence] over the held cells.
  @override
  bool isRowAlive(String table, String pk) => rowExistence(RowRef(table, pk), _lookup) == RowExistence.alive;

  RowCells? _lookup(RowRef row) {
    final cells = _tables[row.table]?[row.pk];
    return cells == null ? null : CellListRow(cells.values);
  }

  @override
  Map<String, int> get vector => Map.unmodifiable(_vector);

  @override
  List<ChangeBatch> changesSince(Map<String, int> peerVector, {int maxCellsPerBatch = 256}) {
    if (maxCellsPerBatch < 1) throw ArgumentError.value(maxCellsPerBatch, 'maxCellsPerBatch');
    final batches = <ChangeBatch>[];
    final origins = _vector.keys.toList()..sort();
    for (final origin in origins) {
      final held = _vector[origin]!;
      var from = peerVector[origin] ?? 0;
      if (held <= from) continue;
      final bySeq = _byOrigin[origin];
      var pending = <CellRecord>[];
      var seq = bySeq?.firstKeyAfter(from);
      while (seq != null && seq <= held) {
        pending.add(bySeq![seq]!);
        if (pending.length == maxCellsPerBatch) {
          batches.add(ChangeBatch(origin: origin, fromSeq: from, toSeq: seq, cells: pending));
          from = seq;
          pending = <CellRecord>[];
        }
        seq = bySeq.firstKeyAfter(seq);
      }
      if (pending.isNotEmpty || from < held) {
        batches.add(ChangeBatch(origin: origin, fromSeq: from, toSeq: held, cells: pending));
      }
    }
    return batches;
  }

  @override
  bool applyBatch(ChangeBatch batch) {
    var changed = false;
    for (final remote in batch.cells) {
      policy.observeRemote(remote);
      final current = read(remote.key);
      if (current == null || policy.compare(remote, current) > 0) {
        _store(remote);
        changed = true;
      }
    }
    final cursor = _vector[batch.origin] ?? 0;
    if (batch.fromSeq <= cursor && batch.toSeq > cursor) {
      _vector[batch.origin] = batch.toSeq;
      changed = true;
    }
    return changed;
  }

  void _store(CellRecord record) {
    final key = record.key;
    final row = _tables.putIfAbsent(key.table, () => {}).putIfAbsent(key.pk, () => {});
    final previous = row[key.col];
    if (previous != null) _byOrigin[previous.origin]?.remove(previous.originSeq);
    row[key.col] = record;
    _byOrigin.putIfAbsent(record.origin, SplayTreeMap.new)[record.originSeq] = record;
  }
}
