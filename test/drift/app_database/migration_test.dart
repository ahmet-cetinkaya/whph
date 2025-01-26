// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart' hide test, expect, setUpAll, group, tearDownAll;
import 'package:test/test.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    final versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // The following template shows how to write tests ensuring your migrations
  // preserve existing data.
  // Testing this can be useful for migrations that change existing columns
  // (e.g. by altercating their type or constraints). Migrations that only add
  // tables or columns typically don't need these advanced tests. For more
  // information, see https://drift.simonbinder.eu/migrations/tests/#verifying-data-integrity
  // it to your own needs when testing migrations with data integrity.
  test("migration from v1 to v2 does not corrupt data", () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    final oldAppUsageTableData = <v1.AppUsageTableData>[];
    final expectedNewAppUsageTableData = <v2.AppUsageTableData>[];

    final oldAppUsageTagTableData = <v1.AppUsageTagTableData>[];
    final expectedNewAppUsageTagTableData = <v2.AppUsageTagTableData>[];

    final oldHabitTableData = <v1.HabitTableData>[];
    final expectedNewHabitTableData = <v2.HabitTableData>[];

    final oldHabitTagTableData = <v1.HabitTagTableData>[];
    final expectedNewHabitTagTableData = <v2.HabitTagTableData>[];

    final oldHabitRecordTableData = <v1.HabitRecordTableData>[];
    final expectedNewHabitRecordTableData = <v2.HabitRecordTableData>[];

    final oldTaskTableData = <v1.TaskTableData>[];
    final expectedNewTaskTableData = <v2.TaskTableData>[];

    final oldTaskTagTableData = <v1.TaskTagTableData>[];
    final expectedNewTaskTagTableData = <v2.TaskTagTableData>[];

    final oldTagTableData = <v1.TagTableData>[];
    final expectedNewTagTableData = <v2.TagTableData>[];

    final oldTagTagTableData = <v1.TagTagTableData>[];
    final expectedNewTagTagTableData = <v2.TagTagTableData>[];

    final oldSettingTableData = <v1.SettingTableData>[];
    final expectedNewSettingTableData = <v2.SettingTableData>[];

    final oldSyncDeviceTableData = <v1.SyncDeviceTableData>[];
    final expectedNewSyncDeviceTableData = <v2.SyncDeviceTableData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.appUsageTable, oldAppUsageTableData);
        batch.insertAll(oldDb.appUsageTagTable, oldAppUsageTagTableData);
        batch.insertAll(oldDb.habitTable, oldHabitTableData);
        batch.insertAll(oldDb.habitTagTable, oldHabitTagTableData);
        batch.insertAll(oldDb.habitRecordTable, oldHabitRecordTableData);
        batch.insertAll(oldDb.taskTable, oldTaskTableData);
        batch.insertAll(oldDb.taskTagTable, oldTaskTagTableData);
        batch.insertAll(oldDb.tagTable, oldTagTableData);
        batch.insertAll(oldDb.tagTagTable, oldTagTagTableData);
        batch.insertAll(oldDb.settingTable, oldSettingTableData);
        batch.insertAll(oldDb.syncDeviceTable, oldSyncDeviceTableData);
      },
      validateItems: (newDb) async {
        expect(expectedNewAppUsageTableData, await newDb.select(newDb.appUsageTable).get());
        expect(expectedNewAppUsageTagTableData, await newDb.select(newDb.appUsageTagTable).get());
        expect(expectedNewHabitTableData, await newDb.select(newDb.habitTable).get());
        expect(expectedNewHabitTagTableData, await newDb.select(newDb.habitTagTable).get());
        expect(expectedNewHabitRecordTableData, await newDb.select(newDb.habitRecordTable).get());
        expect(expectedNewTaskTableData, await newDb.select(newDb.taskTable).get());
        expect(expectedNewTaskTagTableData, await newDb.select(newDb.taskTagTable).get());
        expect(expectedNewTagTableData, await newDb.select(newDb.tagTable).get());
        expect(expectedNewTagTagTableData, await newDb.select(newDb.tagTagTable).get());
        expect(expectedNewSettingTableData, await newDb.select(newDb.settingTable).get());
        expect(expectedNewSyncDeviceTableData, await newDb.select(newDb.syncDeviceTable).get());
      },
    );
  });
}
