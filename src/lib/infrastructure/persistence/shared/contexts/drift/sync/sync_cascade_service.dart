import 'package:drift/drift.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_cascade_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';

/// D5b Drift implementation: stamps `sync_state.cascade_cause_tbl_id/pk`
/// around the cascaded writes so trigger-captured tombstones carry the root
/// item as their cause (D1/T10 wire format `cause = (table name, pk)`).
class DriftSyncCascadeService implements ISyncCascadeService {
  final DatabaseConnectionUser _db;

  DriftSyncCascadeService(this._db);

  @override
  Future<T> withCause<T>(
      String causeTable, String causePk, Future<T> Function() operation) async {
    final policy = syncTablePolicies.firstWhere(
      (p) => p.tableName == causeTable,
      orElse: () => throw ArgumentError(
          'table "$causeTable" is not a synced table', 'causeTable'),
    );
    final previous = await _db.customSelect(
        "SELECT cascade_cause_tbl_id AS tbl, cascade_cause_pk AS pk "
        "FROM sync_state WHERE id = 'singleton'")
      .getSingle();
    // Nested cascades keep the root cause: only set when none is active.
    final hasCause = previous.data['tbl'] != null;
    if (!hasCause) {
      await _db.customStatement(
          "UPDATE sync_state SET cascade_cause_tbl_id = ${policy.tblId}, "
          "cascade_cause_pk = '$causePk' WHERE id = 'singleton'");
    }
    try {
      return await operation();
    } finally {
      if (!hasCause) {
        await _db.customStatement(
            "UPDATE sync_state SET cascade_cause_tbl_id = NULL, "
            "cascade_cause_pk = NULL WHERE id = 'singleton'");
      }
    }
  }
}
