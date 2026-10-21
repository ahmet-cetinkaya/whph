import 'package:drift/drift.dart';

import 'sync_table_policy.dart';
import 'sync_trigger_generator.dart';

/// Current capture-shape version. Bump when trigger SQL or the policy
/// changes; `beforeOpen` re-installs when the stored `capture_version`
/// differs.
const String syncCaptureVersion = 'v38-1';

/// D3: installs (or reinstalls) the capture triggers. Idempotent per version:
/// drops the previously installed version's triggers when it differs, then
/// creates the current ones and records the version in `sync_state`.
Future<void> installSyncTriggers(DatabaseConnectionUser db) async {
  if (!await _syncSchemaExists(db)) return;
  final previous = await _storedVersion(db);
  if (previous == syncCaptureVersion) return;

  if (previous != null) {
    for (final policy in syncTablePolicies) {
      for (final op in const ['ai', 'au', 'ad']) {
        await db.customStatement(
            'DROP TRIGGER IF EXISTS ${triggerName(policy, op)}');
      }
    }
  }
  for (final statement in allSyncTriggerStatements()) {
    await db.customStatement(statement);
  }
  await db.customStatement(
      "UPDATE sync_state SET capture_version = '$syncCaptureVersion' WHERE id = 1");
}

Future<String?> _storedVersion(DatabaseConnectionUser db) async {
  final rows = await db
      .customSelect('SELECT capture_version AS v FROM sync_state WHERE id = 1')
      .get();
  if (rows.isEmpty) return null;
  return rows.first.data['v'] as String?;
}

/// Databases opened below schema v38 (migration tests, pinned versions) have
/// no sync tables yet; triggers can only exist once the schema does.
Future<bool> _syncSchemaExists(DatabaseConnectionUser db) async {
  final rows = await db
      .customSelect(
          "SELECT 1 AS present FROM sqlite_master WHERE type = 'table' AND name = 'sync_state'")
      .get();
  return rows.isNotEmpty;
}
