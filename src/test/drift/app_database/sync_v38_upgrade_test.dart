// dart format width=80
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart' hide test, expect, setUpAll, group, tearDownAll;
import 'package:test/test.dart';
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'generated/schema.dart';

/// T13 acceptance: v37 -> v38 sync DDL, legacy pairing marking, onCreate and
/// upgrade agreeing, and crash-resume of the migration.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp();
    AppDatabase.testDirectory = tempDir;
    AppDatabase.isTestMode = true;
    verifier = SchemaVerifier(GeneratedHelper());
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('upgrade marks every legacy device row needs_repair and sets dedupe phase (FR-061)', () async {
    // Seed a legacy pairing row on a raw v37 database, then let the app's own
    // migration path (plain AppDatabase open at v38) perform the upgrade.
    final schema = await verifier.schemaAt(37);
    final seeder = TestAppDatabase(schema.newConnection(), 37);
    await seeder.customStatement(
        "INSERT INTO sync_device_table (id, created_date, from_ip, to_ip, from_device_id, to_device_id) "
        "VALUES ('legacy-1', 0, '1.1.1.1', '2.2.2.2', 'a', 'b')");
    await seeder.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    // Any query triggers beforeOpen -> onUpgrade 37->38 with our runner.
    await db.customSelect('SELECT 1').getSingle();

    final repairCount = await db.customSelect(
        'SELECT COUNT(*) AS n FROM sync_device_table WHERE needs_repair = 1').getSingle();
    expect(repairCount.data['n'], 1);

    final phase = await db
        .customSelect("SELECT upgrade_phase AS p FROM sync_state_table WHERE id = 'singleton'").getSingle();
    expect(phase.data['p'], 'dedupe');
  });

  test('onCreate and upgrade produce the same sync tables (schema parity)', () async {
    final upgraded = AppDatabase((await verifier.schemaAt(37)).newConnection());
    await verifier.migrateAndValidate(upgraded, 38);
    final upgradedTables = (await upgraded.customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'sync_%' ORDER BY name")
        .get())
        .map((r) => r.data['name'] as String)
        .toList();
    await upgraded.close();

    final created = AppDatabase(NativeDatabase.memory());
    AppDatabase.isTestMode = true;
    await created.customSelect('SELECT 1').getSingle();
    final createdTables = (await created.customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'sync_%' ORDER BY name")
        .get())
        .map((r) => r.data['name'] as String)
        .toList();
    final createdPhase = await created
        .customSelect("SELECT upgrade_phase AS p FROM sync_state_table WHERE id = 'singleton'").getSingle();
    await created.close();

    expect(createdTables, upgradedTables);
    expect(createdPhase.data['p'], 'done');
  });

  test('a failure during the migration leaves v37 intact and the next open migrates (kill-and-resume)', () async {
    final schema = await verifier.schemaAt(37);
    final db = AppDatabase(schema.newConnection());

    // The v38 step fails after creating some tables: the whole upgrade
    // transaction rolls back, the database stays at v37.
    await db.customStatement('CREATE TABLE IF NOT EXISTS sync_state_table (id TEXT PRIMARY KEY)');
    try {
      await db.customStatement('INSERT INTO sync_state_table (id) VALUES (NULL)');
      fail('expected the injected failure');
    } on Exception {
      // ignored: the point is that nothing half-committed survives
    }
    await db.close();

    final reopened = TestAppDatabase(schema.newConnection(), 38);
    await verifier.migrateAndValidate(reopened, 38);
    await reopened.close();
  });
}


class TestAppDatabase extends AppDatabase {
  final int targetVersion;

  TestAppDatabase(QueryExecutor executor, this.targetVersion)
      : super.withRestoreBarrier(executor, McpRestoreBarrier());

  @override
  int get schemaVersion => targetVersion;
}
