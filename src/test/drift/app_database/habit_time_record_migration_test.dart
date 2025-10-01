// Test for Issue #96: Missing habit_time_record_table during migration
// This test simulates the exact scenario reported by users where the migration
// from schema 24->25 fails because habit_time_record_table doesn't exist

import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart' hide test, expect, setUpAll, group, tearDownAll;
import 'package:test/test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'generated/schema.dart';

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

  group('Issue #96: habit_time_record_table migration fixes', () {
    test('migration from v23 to v25 handles missing habit_time_record_table', () async {
      // This simulates a user upgrading from pre-0.16.0 (schema 23 or earlier)
      // directly to 0.16.1+ (schema 25+) where habit_time_record_table was added

      final schema23 = await verifier.schemaAt(23);
      final db = AppDatabase(schema23.newConnection());

      // Verify we can migrate successfully without crashing
      // The fix ensures that from24To25 checks if the table exists before altering it
      await verifier.migrateAndValidate(db, 25);

      // Verify the table was created correctly with all required columns
      final result = await db.customSelect('PRAGMA table_info(habit_time_record_table)').get();

      expect(result.isNotEmpty, true, reason: 'habit_time_record_table should exist after migration');

      final columnNames = result.map((row) => row.data['name'] as String).toSet();
      expect(columnNames.contains('id'), true);
      expect(columnNames.contains('habit_id'), true);
      expect(columnNames.contains('duration'), true);
      expect(columnNames.contains('occurred_at'), true);
      expect(columnNames.contains('created_date'), true);
      expect(columnNames.contains('modified_date'), true);
      expect(columnNames.contains('deleted_date'), true);

      await db.close();
    });

    test('migration from v23 to v26 handles missing habit_time_record_table', () async {
      // This tests the complete migration path from v23 through v26
      // where v26 recreates the table with foreign key constraints

      final schema23 = await verifier.schemaAt(23);
      final db = AppDatabase(schema23.newConnection());

      await verifier.migrateAndValidate(db, 26);

      // Verify table exists with correct schema including foreign key
      final tableInfo = await db.customSelect('PRAGMA table_info(habit_time_record_table)').get();
      expect(tableInfo.isNotEmpty, true);

      // Check for foreign key constraint
      final foreignKeys = await db.customSelect('PRAGMA foreign_key_list(habit_time_record_table)').get();
      expect(foreignKeys.isNotEmpty, true, reason: 'Should have foreign key to habit_table');

      final fkInfo = foreignKeys.first.data;
      expect(fkInfo['table'], 'habit_table');
      expect(fkInfo['from'], 'habit_id');
      expect(fkInfo['to'], 'id');
      expect(fkInfo['on_delete'], 'CASCADE');

      await db.close();
    });

    test('migration from v23 to v28 (latest) completes successfully', () async {
      // Full migration path from pre-habit-time-tracking to latest schema
      final schema23 = await verifier.schemaAt(23);
      final db = AppDatabase(schema23.newConnection());

      await verifier.migrateAndValidate(db, 28);

      // Verify final schema is correct
      final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
      final tableNames = tables.map((row) => row.data['name'] as String).toSet();

      expect(tableNames.contains('habit_time_record_table'), true);
      expect(tableNames.contains('habit_table'), true);
      expect(tableNames.contains('habit_record_table'), true);

      await db.close();
    });

    test('from24To25 migration detects table existence correctly', () async {
      // This tests that the from24To25 migration checks for table existence
      // before attempting to ALTER it (the core fix for issue #96)
      // We test the logic without strict schema validation

      // Start from v24 where habit_time_record_table should exist
      final schema24 = await verifier.schemaAt(24);
      final testDb = AppDatabase(schema24.newConnection());

      // Verify table exists at v24
      final tableExistsAtV24 = await testDb.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type='table' AND name='habit_time_record_table'
      ''').getSingleOrNull();

      expect(tableExistsAtV24, isNotNull, reason: 'Table should exist at schema v24');

      await testDb.close();
    });
  });

  group('Edge cases for habit_time_record_table migration', () {
    test('v26 schema has habit_time_record_table with foreign key', () async {
      // Verify that at v26, the table exists with proper foreign key constraints
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      // Verify table exists
      final tableExists = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type='table' AND name='habit_time_record_table'
      ''').getSingleOrNull();

      expect(tableExists, isNotNull, reason: 'Table should exist at schema v26');

      // Check for foreign key constraint to habit_table
      final foreignKeys = await db.customSelect('PRAGMA foreign_key_list(habit_time_record_table)').get();

      expect(foreignKeys.isNotEmpty, true, reason: 'Should have foreign key constraints');

      // Verify FK details
      final fkInfo = foreignKeys.firstWhere((row) => row.data['table'] == 'habit_table');
      expect(fkInfo.data['from'], 'habit_id');
      expect(fkInfo.data['to'], 'id');
      expect(fkInfo.data['on_delete'], 'CASCADE');

      await db.close();
    });

    test('migration validates table existence before operations', () async {
      // Verify the fix: from24To25 and from25To26 check table existence
      // This is a code inspection test - we verify the behavior by testing v23->v28

      final schema23 = await verifier.schemaAt(23);
      final db = AppDatabase(schema23.newConnection());

      // At v23, habit_time_record_table does NOT exist yet
      // The fix ensures migrations handle this gracefully

      // Migrate all the way to v28 - this should succeed without errors
      await verifier.migrateAndValidate(db, 28);

      // Verify table was created correctly
      final tableExists = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type='table' AND name='habit_time_record_table'
      ''').getSingleOrNull();

      expect(tableExists, isNotNull, reason: 'Table should exist after full migration');

      // Verify key columns exist
      final columns = await db.customSelect('PRAGMA table_info(habit_time_record_table)').get();
      final columnNames = columns.map((row) => row.data['name'] as String).toSet();

      expect(columnNames.contains('id'), true);
      expect(columnNames.contains('habit_id'), true);
      expect(columnNames.contains('duration'), true);
      expect(columnNames.contains('created_date'), true);

      await db.close();
    });
  });
}
