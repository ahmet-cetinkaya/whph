/// Outcome of one session-end diagnostics pass (T19, D14).
class SyncDiagnosticsReport {
  /// Rows that hold staged cells but are not yet visible in a base row.
  final int stagedRowCount;

  /// SHA-256 hex per synced table over base content plus staged cells;
  /// `null` when the content hash was not requested.
  final Map<String, String>? tableHashes;

  /// Tables whose hash differs from the peer's. Only table names (the
  /// category) are ever reported, never values.
  final List<String> divergentTables;

  const SyncDiagnosticsReport({
    required this.stagedRowCount,
    this.tableHashes,
    this.divergentTables = const [],
  });
}

/// Session-end diagnostics and optional housekeeping of the sync tables.
abstract interface class ISyncDiagnosticsService {
  /// Reads the staged-row count and, with [includeContentHash], the per-table
  /// content hashes.
  Future<SyncDiagnosticsReport> collect({bool includeContentHash = false});

  /// Collects, writes the session-end log line (staged-row count) and, when
  /// [peerTableHashes] is given, logs one mismatch line per divergent table
  /// naming the table only.
  Future<SyncDiagnosticsReport> logSessionEnd({
    bool includeContentHash = false,
    Map<String, String>? peerTableHashes,
  });

  /// Deletes manifests that no clock row and no held cell references (D7).
  /// Returns the number deleted.
  Future<int> deleteUnreferencedManifests();
}
