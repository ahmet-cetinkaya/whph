// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'dart:io';
import 'package:drift/drift.dart';
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

  group('specific migration scenarios', () {
    test('migration from v29 to v30 sets default status to 0 (Complete)', () async {
      final schema29 = await verifier.schemaAt(29);
      // Use TestAppDatabase to enforce schema version 30 during this test
      final db = TestAppDatabase(schema29.newConnection(), 30);

      // Create a dummy record in v29.
      final habitId = 'habit_1';
      final recordId = 'record_1';
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert parent habit first to satisfy FK constraints if any (good practice)
      // Note: We use raw insert because the table object might be the latest version.
      await db.customStatement(
          'INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, "order") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [habitId, now, 'Test Habit', 'Desc', 0, '', 0, 1, 7, 0.0]);

      await db.customStatement(
          'INSERT INTO habit_record_table (id, created_date, habit_id, occurred_at) VALUES (?, ?, ?, ?)',
          [recordId, now, habitId, now]);

      // Migrate to v30
      await verifier.migrateAndValidate(db, 30);

      // Verify status
      final result = await db.customSelect('SELECT status FROM habit_record_table WHERE id = ?',
          variables: [Variable.withString(recordId)]).getSingle();

      expect(result.data['status'], 0, reason: 'Status should default to 0 (Complete)');

      await db.close();
    });
  });
}

class TestAppDatabase extends AppDatabase {
  final int _targetVersion;

  TestAppDatabase(super.e, this._targetVersion);

  @override
  int get schemaVersion => _targetVersion;
}
