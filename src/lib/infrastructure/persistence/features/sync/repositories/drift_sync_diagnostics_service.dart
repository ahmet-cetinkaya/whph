import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_diagnostics_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';

const String _logComponent = 'SyncDiagnostics';
const String _heldKindStaged = 'staged';
const Set<String> _unsyncedColumns = {'created_date', 'modified_date'};
const Set<String> _identityColumns = {'id', 'deleted_date'};

/// Drift implementation of [ISyncDiagnosticsService] (T19). Diagnostic only:
/// it never changes synced content.
class DriftSyncDiagnosticsService implements ISyncDiagnosticsService {
  final AppDatabase _db;
  final void Function(String message) _log;

  DriftSyncDiagnosticsService(this._db, {void Function(String message)? log})
      : _log = log ??
            ((message) => Logger.info(message, component: _logComponent));

  @override
  Future<SyncDiagnosticsReport> collect(
          {bool includeContentHash = false}) async =>
      SyncDiagnosticsReport(
        stagedRowCount: await _stagedRowCount(),
        tableHashes: includeContentHash ? await _tableHashes() : null,
      );

  @override
  Future<SyncDiagnosticsReport> logSessionEnd({
    bool includeContentHash = false,
    Map<String, String>? peerTableHashes,
  }) async {
    final local = await collect(includeContentHash: includeContentHash);
    _log('sync session end: staged_rows=${local.stagedRowCount}');
    final localHashes = local.tableHashes;
    if (localHashes == null || peerTableHashes == null) return local;

    final divergent = [
      for (final entry in localHashes.entries)
        if (peerTableHashes[entry.key] != entry.value) entry.key,
    ];
    for (final table in divergent) {
      _log('sync content divergence: category=$table');
    }
    return SyncDiagnosticsReport(
      stagedRowCount: local.stagedRowCount,
      tableHashes: localHashes,
      divergentTables: divergent,
    );
  }

  @override
  Future<int> deleteUnreferencedManifests() async {
    final unreferenced = await _db
        .customSelect(
          'SELECT manifest_id FROM sync_origin_batch '
          'WHERE manifest_id NOT IN (SELECT manifest_id FROM sync_clock WHERE manifest_id IS NOT NULL) '
          'AND manifest_id NOT IN (SELECT manifest_id FROM sync_held_cell WHERE manifest_id IS NOT NULL)',
        )
        .get();
    for (final row in unreferenced) {
      await _db.customStatement(
          'DELETE FROM sync_origin_batch WHERE manifest_id = ?',
          [row.data['manifest_id']]);
    }
    return unreferenced.length;
  }

  Future<int> _stagedRowCount() async {
    final row = await _db
        .customSelect(
          "SELECT COUNT(*) AS total FROM (SELECT DISTINCT tbl, pk FROM sync_held_cell WHERE kind = '$_heldKindStaged')",
        )
        .getSingle();
    return row.data['total'] as int;
  }

  Future<Map<String, String>> _tableHashes() async => {
        for (final policy in syncTablePolicies)
          policy.tableName: await _tableHash(policy),
      };

  Future<String> _tableHash(SyncTablePolicy policy) async {
    final lines = StringBuffer();
    final rows = await _db
        .customSelect('SELECT * FROM "${policy.tableName}" ORDER BY id')
        .get();
    for (final row in rows) {
      final syncedEntries = row.data.entries
          .where((entry) => _isSyncedColumn(policy, entry.key))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      lines.writeln(jsonEncode([
        for (final entry in syncedEntries)
          [entry.key, _encodeValue(entry.value)]
      ]));
    }
    final staged = await _db.customSelect(
      'SELECT pk, col, value FROM sync_held_cell WHERE tbl = ? AND kind = ? ORDER BY pk, col',
      variables: [
        Variable<String>(policy.tableName),
        const Variable<String>(_heldKindStaged)
      ],
    ).get();
    for (final row in staged) {
      lines.writeln(jsonEncode([
        'staged',
        row.data['pk'],
        row.data['col'],
        _encodeValue(row.data['value'])
      ]));
    }
    return sha256.convert(utf8.encode(lines.toString())).toString();
  }

  bool _isSyncedColumn(SyncTablePolicy policy, String column) {
    if (_unsyncedColumns.contains(column)) return false;
    return policy.rowLevel ||
        _identityColumns.contains(column) ||
        policy.columns.containsKey(column);
  }

  Object? _encodeValue(Object? value) =>
      value is Uint8List ? base64Encode(value) : value;
}
