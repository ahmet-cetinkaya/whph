// dart format width=80
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_generator.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_installer.dart';

/// T14 acceptance 1: every synced column of every synced table is captured
/// by the generated triggers; a table missing from the policy fails by name.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').getSingle();
    // Seed a local identity so the triggers can stamp (T17/T18 own the real
    // one; capture coverage only needs stable node/origin rows).
    for (final s in syncInternSeedStatements(
        nodeValue: 'test-node-local', originValue: 'test-origin-local')) {
      await db.customStatement(s);
    }
    await installSyncTriggers(db);
  });

  tearDown(() async => db.close());

  test('every synced table in the schema has a policy', () async {
    final tables = (await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get())
        .map((r) => r.data['name'] as String)
        .toSet();
    final missing = [
      for (final p in syncTablePolicies)
        if (!tables.contains(p.tableName)) p.tableName,
    ];
    expect(missing, isEmpty,
        reason: 'policies naming unknown tables: $missing');
  });

  test('an insert captures one cell per synced column plus ~ (field-level)',
      () async {
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title, description) "
        "VALUES ('t1', 0, 'T', 'D')");
    final rows = await db
        .customSelect(
            "SELECT c.key % 256 AS col FROM sync_clock c JOIN sync_row r ON c.key / 256 = r.id "
            "WHERE r.tbl_id = 1 AND r.pk = 't1'")
        .get();
    final cols = rows.map((r) => r.data['col'] as int).toSet();
    // 22 synced columns + tombstone = 23 cells (D3 INSERT).
    expect(cols.length, 23, reason: 'captured: $cols');
    expect(cols, contains(tombstoneColId));
  });

  test('a row-level insert captures exactly the * and ~ cells', () async {
    await db.customStatement(
        "INSERT INTO task_time_record_table (id, created_date, task_id, duration) "
        "VALUES ('r1', 0, 't1', 300)");
    final rows = await db
        .customSelect(
            "SELECT c.key % 256 AS col FROM sync_clock c JOIN sync_row r ON c.key / 256 = r.id "
            "WHERE r.tbl_id = 3 AND r.pk = 'r1'")
        .get();
    final cols = rows.map((r) => r.data['col'] as int).toSet();
    expect(cols, {rowLevelColId, tombstoneColId});
  });

  test('an update of one field-level column writes exactly that cell',
      () async {
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title) VALUES ('t2', 0, 'A')");
    await db.customStatement("DELETE FROM sync_clock");
    await db.customStatement("DELETE FROM sync_row");
    await db
        .customStatement("UPDATE task_table SET title = 'B' WHERE id = 't2'");
    final rows = await db
        .customSelect(
            "SELECT c.key % 256 AS col FROM sync_clock c JOIN sync_row r ON c.key / 256 = r.id "
            "WHERE r.tbl_id = 1 AND r.pk = 't2'")
        .get();
    final cols = rows.map((r) => r.data['col'] as int).toSet();
    expect(cols, {3}); // title's fixed colId in the policy.
  });

  test('soft delete writes one ~ cell whose value is the new deleted_date',
      () async {
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title) VALUES ('t3', 0, 'A')");
    await db.customStatement("DELETE FROM sync_clock");
    await db.customStatement("DELETE FROM sync_row");
    await db.customStatement(
        "UPDATE task_table SET deleted_date = 1234 WHERE id = 't3'");
    final rows = await db
        .customSelect(
            "SELECT c.key % 256 AS col, c.tomb_value AS v FROM sync_clock c "
            "JOIN sync_row r ON c.key / 256 = r.id WHERE r.tbl_id = 1 AND r.pk = 't3'")
        .get();
    expect(rows.length, 1);
    expect(rows.first.data['col'], tombstoneColId);
    expect(rows.first.data['v'], 1234);
  });

  test('a modified_date-only update writes zero cells', () async {
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title) VALUES ('t4', 0, 'A')");
    await db.customStatement("DELETE FROM sync_clock");
    await db.customStatement("DELETE FROM sync_row");
    await db.customStatement(
        "UPDATE task_table SET modified_date = 99 WHERE id = 't4'");
    final count = await db
        .customSelect('SELECT COUNT(*) AS n FROM sync_clock')
        .getSingle();
    expect(count.data['n'], 0);
  });

  test('apply_mode 1 (remote apply) captures nothing', () async {
    await db.customStatement(
        "UPDATE sync_state SET apply_mode = 1 WHERE id = 'singleton'");
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title) VALUES ('t5', 0, 'A')");
    await db.customStatement(
        "UPDATE sync_state SET apply_mode = 0 WHERE id = 'singleton'");
    final count = await db
        .customSelect('SELECT COUNT(*) AS n FROM sync_clock')
        .getSingle();
    expect(count.data['n'], 0);
  });

  test('the installer is idempotent per version and bumps capture_version',
      () async {
    await installSyncTriggers(db);
    final triggers = (await db
            .customSelect(
                "SELECT COUNT(*) AS n FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'sync_cap_%'")
            .getSingle())
        .data['n'];
    expect(triggers, syncTablePolicies.length * 3);
    final version = await db
        .customSelect(
            "SELECT capture_version AS v FROM sync_state WHERE id = 'singleton'")
        .getSingle();
    expect(version.data['v'], syncCaptureVersion);
  });

  test('apply_mode 3 and 4 capture nothing', () async {
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title) VALUES ('t6', 0, 'A')");
    await db.customStatement("DELETE FROM sync_clock");
    await db.customStatement("DELETE FROM sync_row");
    for (final mode in const ['3', '4']) {
      await db.customStatement(
          "UPDATE sync_state SET apply_mode = $mode WHERE id = 'singleton'");
      await db
          .customStatement('INSERT INTO task_table (id, created_date, title) '
              "VALUES ('tm$mode', 0, 'A')");
      await db.customStatement(
          "UPDATE sync_state SET apply_mode = 0 WHERE id = 'singleton'");
    }
    final count = await db
        .customSelect('SELECT COUNT(*) AS n FROM sync_clock')
        .getSingle();
    expect(count.data['n'], 0);
  });

  test('local-only tables capture nothing', () async {
    await db.customStatement(
        "INSERT INTO sync_device_table (id, created_date, from_ip, to_ip, from_device_id, to_device_id) "
        "VALUES ('d1', 0, 'a', 'b', 'x', 'y')");
    final count = await db
        .customSelect('SELECT COUNT(*) AS n FROM sync_clock')
        .getSingle();
    expect(count.data['n'], 0);
  });
}
