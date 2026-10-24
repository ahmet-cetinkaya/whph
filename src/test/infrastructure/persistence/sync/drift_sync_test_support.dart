// Shared devices and sync helpers for the Drift change store tests (T18).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_change_store.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_generator.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_installer.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

const int msPerSecond = 1000;
const int hlcBits = 16;
const int farFutureMs = 60 * 60 * msPerSecond;
const int manifestedMarker = 7;

class SyncTestDevice {
  final String name;
  final AppDatabase db;
  final DriftSyncChangeStore store;

  SyncTestDevice(this.name, this.db) : store = DriftSyncChangeStore(db);

  String get origin => 'origin-$name';

  static Future<SyncTestDevice> open(String name) async {
    final db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').getSingle();
    for (final statement in syncInternSeedStatements(
        nodeValue: 'node-$name', originValue: 'origin-$name')) {
      await db.customStatement(statement);
    }
    await installSyncTriggers(db);
    return SyncTestDevice(name, db);
  }

  Future<List<Map<String, Object?>>> rows(String sql,
          [List<Variable> args = const []]) async =>
      (await db.customSelect(sql, variables: args).get())
          .map((r) => r.data)
          .toList();

  Future<int> count(String sql) async =>
      (await rows(sql)).single.values.first as int;

  Future<void> sql(String statement, [List<Object?> args = const []]) =>
      db.customStatement(statement, args);

  Future<void> insertNote(String id, String title) => sql(
      "INSERT INTO note_table (id, created_date, title, content) VALUES ('$id', 1, '$title', 'body')");

  Future<void> setTitle(String id, String title) =>
      sql("UPDATE note_table SET title = '$title' WHERE id = '$id'");

  Future<Map<String, Object?>> note(String id) async =>
      (await rows("SELECT * FROM note_table WHERE id = '$id'")).single;

  /// Synced content of every policy table (never `modified_date`, FR-001).
  Future<String> content() async {
    final out = StringBuffer();
    for (final policy in syncTablePolicies) {
      final columns = policy.rowLevel
          ? ['*']
          : policy.columns.keys.map((c) => '"$c"').toList();
      final select =
          policy.rowLevel ? '*' : 'id, deleted_date, ${columns.join(', ')}';
      for (final row in await rows(
          'SELECT $select FROM "${policy.tableName}" ORDER BY id')) {
        final entries = row.entries
            .where((e) => e.key != 'modified_date' && e.key != 'created_date');
        out.writeln(
            '${policy.tableName} ${entries.map((e) => '${e.key}=${e.value}').join('|')}');
      }
    }
    return out.toString();
  }

  Future<void> forceHlcAhead() => sql(
      "UPDATE sync_state SET hlc = ((CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) + $farFutureMs) << $hlcBits)");

  Future<void> close() => db.close();
}

/// One directional sync: every origin `from` holds above `into`'s cursor.
Future<void> pullChanges(SyncTestDevice from, SyncTestDevice into,
    {Set<String>? onlyOrigins}) async {
  final theirs = await from.store.readVector();
  final mine = await into.store.readVector();
  for (final entry in theirs.entries) {
    if (entry.key == into.origin ||
        (onlyOrigins != null && !onlyOrigins.contains(entry.key))) continue;
    var after = mine[entry.key] ?? 0;
    while (after < entry.value) {
      final batch = await from.store.readChanges(entry.key,
          afterSeq: after, upToSeq: entry.value, limit: 7);
      await into.store.applyBatch(batch);
      after = batch.toSeq;
    }
  }
}

Future<void> syncAllDevices(List<SyncTestDevice> devices) async {
  for (var round = 0; round < 2; round++) {
    for (final a in devices) {
      for (final b in devices) {
        if (a != b) await pullChanges(a, b);
      }
    }
  }
}

CellRecord testCell(String table, String pk, String col, Object? value,
        {required int clock,
        String node = 'node-x',
        String origin = 'origin-x',
        int seq = 1,
        RowRef? cause}) =>
    CellRecord(
        key: CellKey(table, pk, col),
        value: value,
        clock: clock,
        node: node,
        origin: origin,
        originSeq: seq,
        cause: cause);

int hlcAt(int wallMs) => wallMs << hlcBits;
