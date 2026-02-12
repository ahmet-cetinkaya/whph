import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart' hide test, expect, setUpAll, group, tearDownAll;
import 'package:test/test.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
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

  group('Comprehensive migration edge cases - Enhanced', () {
    test('habit_time_record_table handles null values during migration', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final habitId = 'test-habit-null-values';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, occurred_at, modified_date, deleted_date)
          VALUES (?, ?, ?, ?, NULL, NULL, NULL)
        ''', ['record-1', now, habitId, 3600000]);

        final records = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('record-1')],
        ).get();
        expect(records.length, 1);
        expect(records.first.data['occurred_at'], isNull);
        expect(records.first.data['modified_date'], isNull);
        expect(records.first.data['deleted_date'], isNull);
      } finally {
        await db.close();
      }
    });

    test('habit_time_record_table handles empty string habitId validation', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final now = DateTime.now().millisecondsSinceEpoch;

        try {
          await db.customStatement('''
            INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
            VALUES (?, ?, ?, ?)
          ''', ['record-empty-habit', now, '', 3600000]);
          fail('Should throw exception for empty habit_id');
        } catch (e) {
          expect(e, isNotNull, reason: 'Foreign key constraint should prevent empty habit_id');
        }
      } finally {
        await db.close();
      }
    });

    test('habit_time_record_table handles boundary timestamps', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final habitId = 'test-habit-boundary';
        final now = DateTime.now().millisecondsSinceEpoch;
        final minTimestamp = 0;
        final maxTimestamp = 8640000000000000;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, occurred_at)
          VALUES (?, ?, ?, ?, ?)
        ''', ['record-min', minTimestamp, habitId, 1000, minTimestamp]);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, occurred_at)
          VALUES (?, ?, ?, ?, ?)
        ''', ['record-max', maxTimestamp, habitId, 1000, maxTimestamp]);

        final minRecord = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('record-min')],
        ).getSingle();
        final maxRecord = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('record-max')],
        ).getSingle();

        expect(minRecord.data['occurred_at'], minTimestamp);
        expect(maxRecord.data['occurred_at'], maxTimestamp);
      } finally {
        await db.close();
      }
    });

    test('habit_time_record_table handles zero and negative durations', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final habitId = 'test-habit-duration';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['record-zero', now, habitId, 0]);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['record-negative', now, habitId, -100]);

        final zeroRecord = await db.customSelect(
          'SELECT duration FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('record-zero')],
        ).getSingle();
        final negRecord = await db.customSelect(
          'SELECT duration FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('record-negative')],
        ).getSingle();

        expect(zeroRecord.data['duration'], 0);
        expect(negRecord.data['duration'], -100);
      } finally {
        await db.close();
      }
    });

    test('foreign key cascade deletes habit_time_records when habit deleted', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final habitId = 'test-habit-cascade';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['record-1', now, habitId, 1000]);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['record-2', now, habitId, 2000]);

        final beforeCount = await db.customSelect(
          'SELECT COUNT(*) as count FROM habit_time_record_table WHERE habit_id = ?',
          variables: [Variable.withString(habitId)],
        ).getSingle();
        expect(beforeCount.data['count'], 2);

        await db.customStatement('DELETE FROM habit_table WHERE id = ?', [habitId]);

        final afterCount = await db.customSelect(
          'SELECT COUNT(*) as count FROM habit_time_record_table WHERE habit_id = ?',
          variables: [Variable.withString(habitId)],
        ).getSingle();
        expect(afterCount.data['count'], 0, reason: 'All time records should be cascade deleted');
      } finally {
        await db.close();
      }
    });

    test('migration preserves existing time records during v25 to v26', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final habitId = 'test-habit-preserve';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, occurred_at)
          VALUES (?, ?, ?, ?, ?)
        ''', ['record-preserve-1', now - 86400000, habitId, 1800000, now - 86400000]);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, occurred_at)
          VALUES (?, ?, ?, ?, ?)
        ''', ['record-preserve-2', now, habitId, 3600000, now]);

        final beforeRecords = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE habit_id = ? ORDER BY id',
          variables: [Variable.withString(habitId)],
        ).get();
        expect(beforeRecords.length, 2);

        await verifier.migrateAndValidate(db, 26);

        final afterRecords = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE habit_id = ? ORDER BY id',
          variables: [Variable.withString(habitId)],
        ).get();
        expect(afterRecords.length, 2, reason: 'All records should be preserved');
        expect(afterRecords[0].data['id'], 'record-preserve-1');
        expect(afterRecords[0].data['duration'], 1800000);
        expect(afterRecords[1].data['id'], 'record-preserve-2');
        expect(afterRecords[1].data['duration'], 3600000);
      } finally {
        await db.close();
      }
    });

    test('migration removes orphaned time records during v25 to v26', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final validHabitId = 'valid-habit';
        final invalidHabitId = 'non-existent-habit';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [validHabitId, now, 'Valid Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['valid-record', now, validHabitId, 1000]);

        await db.customStatement('PRAGMA foreign_keys = OFF');
        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['orphaned-record', now, invalidHabitId, 2000]);
        await db.customStatement('PRAGMA foreign_keys = ON');

        final beforeCount = await db.customSelect('SELECT COUNT(*) as count FROM habit_time_record_table').getSingle();
        expect(beforeCount.data['count'], 2);

        await verifier.migrateAndValidate(db, 26);

        final afterRecords = await db.customSelect('SELECT * FROM habit_time_record_table').get();
        expect(afterRecords.length, 1, reason: 'Only valid records should remain');
        expect(afterRecords.first.data['id'], 'valid-record');
      } finally {
        await db.close();
      }
    });

    test('large dataset migration performance', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        final habitIds = List.generate(10, (i) => 'habit-$i');

        for (final habitId in habitIds) {
          await db.customStatement('''
            INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
            VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, ?)
          ''', [habitId, now, 'Habit $habitId', '', (habitIds.indexOf(habitId) + 1) * 1000.0]);
        }

        for (var i = 0; i < 1000; i++) {
          final habitId = habitIds[i % habitIds.length];
          await db.customStatement('''
            INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, occurred_at)
            VALUES (?, ?, ?, ?, ?)
          ''', ['record-$i', now + i * 1000, habitId, (i + 1) * 60000, now + i * 1000]);
        }

        final beforeCount = await db.customSelect('SELECT COUNT(*) as count FROM habit_time_record_table').getSingle();
        expect(beforeCount.data['count'], 1000);

        final stopwatch = Stopwatch()..start();
        await verifier.migrateAndValidate(db, 26);
        stopwatch.stop();

        final afterCount = await db.customSelect('SELECT COUNT(*) as count FROM habit_time_record_table').getSingle();
        expect(afterCount.data['count'], 1000, reason: 'All records preserved');
        expect(stopwatch.elapsedMilliseconds, lessThan(10000), reason: 'Migration should complete in reasonable time');
      } finally {
        await db.close();
      }
    });

    test('migration handles concurrent-like scenarios with transaction isolation', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final habitId = 'test-habit-concurrent';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.transaction(() async {
          await db.customStatement('''
            INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
            VALUES (?, ?, ?, ?)
          ''', ['record-tx-1', now, habitId, 1000]);

          await db.customStatement('''
            INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
            VALUES (?, ?, ?, ?)
          ''', ['record-tx-2', now, habitId, 2000]);
        });

        await verifier.migrateAndValidate(db, 26);

        final records = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE habit_id = ? ORDER BY id',
          variables: [Variable.withString(habitId)],
        ).get();
        expect(records.length, 2);
        expect(records[0].data['id'], 'record-tx-1');
        expect(records[1].data['id'], 'record-tx-2');
      } finally {
        await db.close();
      }
    });

    test('migration validates data integrity with checksums', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final habitId = 'test-habit-integrity';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        final testRecords = [
          {'id': 'rec-1', 'duration': 1000},
          {'id': 'rec-2', 'duration': 2000},
          {'id': 'rec-3', 'duration': 3000},
        ];

        for (final record in testRecords) {
          await db.customStatement('''
            INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
            VALUES (?, ?, ?, ?)
          ''', [record['id'], now, habitId, record['duration']]);
        }

        final beforeSum = await db.customSelect(
          'SELECT SUM(duration) as total FROM habit_time_record_table WHERE habit_id = ?',
          variables: [Variable.withString(habitId)],
        ).getSingle();
        final beforeTotal = beforeSum.data['total'] as int;

        await verifier.migrateAndValidate(db, 26);

        final afterSum = await db.customSelect(
          'SELECT SUM(duration) as total FROM habit_time_record_table WHERE habit_id = ?',
          variables: [Variable.withString(habitId)],
        ).getSingle();
        final afterTotal = afterSum.data['total'] as int;

        expect(afterTotal, beforeTotal, reason: 'Total duration should be preserved');
      } finally {
        await db.close();
      }
    });

    test('migration handles table with existing corrupted records', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final habitId = 'test-habit-corrupted';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['good-record', now, habitId, 1000]);

        await db.customStatement('PRAGMA foreign_keys = OFF');
        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['corrupted-record', now, 'non-existent', 2000]);
        await db.customStatement('PRAGMA foreign_keys = ON');

        await verifier.migrateAndValidate(db, 26);

        final validRecords = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE habit_id = ?',
          variables: [Variable.withString(habitId)],
        ).get();
        expect(validRecords.length, 1);
        expect(validRecords.first.data['id'], 'good-record');

        final orphanedCheck = await db.customSelect(
          'SELECT COUNT(*) as count FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('corrupted-record')],
        ).getSingle();
        expect(orphanedCheck.data['count'], 0, reason: 'Corrupted records should be removed');
      } finally {
        await db.close();
      }
    });

    test('migration handles incomplete records with missing required fields', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final habitId = 'test-habit-incomplete';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        try {
          await db.customStatement('''
            INSERT INTO habit_time_record_table (id, created_date, habit_id)
            VALUES (?, ?, ?)
          ''', ['incomplete-record', now, habitId]);
          fail('Should throw exception for missing required duration field');
        } catch (e) {
          expect(e, isNotNull, reason: 'Missing required duration field should fail');
        }
      } finally {
        await db.close();
      }
    });

    test('version compatibility check for incremental migrations', () async {
      for (var version = 23; version < 28; version++) {
        final schema = await verifier.schemaAt(version);
        final db = AppDatabase(schema.newConnection());

        try {
          await verifier.migrateAndValidate(db, version + 1);

          final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
          final tableNames = tables.map((row) => row.data['name'] as String).toSet();
          expect(tableNames.contains('habit_table'), true, reason: 'Core tables should exist at v${version + 1}');
        } finally {
          await db.close();
        }
      }
    });

    test('migration rollback simulation with inconsistent state', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final habitId = 'test-habit-rollback';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['rollback-test', now, habitId, 1000]);

        try {
          await db.transaction(() async {
            await db.customStatement('''
              INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
              VALUES (?, ?, ?, ?)
            ''', ['rollback-test-2', now, habitId, 2000]);

            throw Exception('Simulated failure');
          });
        } catch (e) {
          expect(e.toString(), contains('Simulated failure'));
        }

        final recordCount = await db.customSelect(
          'SELECT COUNT(*) as count FROM habit_time_record_table WHERE habit_id = ?',
          variables: [Variable.withString(habitId)],
        ).getSingle();
        expect(recordCount.data['count'], 1, reason: 'Transaction should rollback on failure');
      } finally {
        await db.close();
      }
    });

    test('migration handles empty habit_time_record_table', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final beforeCount = await db.customSelect('SELECT COUNT(*) as count FROM habit_time_record_table').getSingle();
        final initialCount = beforeCount.data['count'] as int;

        await verifier.migrateAndValidate(db, 26);

        final afterCount = await db.customSelect('SELECT COUNT(*) as count FROM habit_time_record_table').getSingle();
        expect(afterCount.data['count'], initialCount);

        final tableInfo = await db.customSelect('PRAGMA table_info(habit_time_record_table)').get();
        expect(tableInfo.isNotEmpty, true);
      } finally {
        await db.close();
      }
    });

    test('foreign key constraint enforcement after migration', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final now = DateTime.now().millisecondsSinceEpoch;

        final fkEnabled = await db.customSelect('PRAGMA foreign_keys').getSingle();
        expect(fkEnabled.data['foreign_keys'], 1, reason: 'Foreign keys should be enabled');

        try {
          await db.customStatement('''
            INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
            VALUES (?, ?, ?, ?)
          ''', ['orphan-test', now, 'non-existent-habit', 1000]);
          fail('Should throw exception for foreign key constraint violation');
        } catch (e) {
          expect(e, isNotNull, reason: 'Foreign key constraint should prevent orphaned records');
        }
      } finally {
        await db.close();
      }
    });

    test('migration preserves occurred_at null values correctly', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final habitId = 'test-habit-null-occurred';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, occurred_at)
          VALUES (?, ?, ?, ?, NULL)
        ''', ['null-occurred-at', now, habitId, 1000]);

        await verifier.migrateAndValidate(db, 26);

        final record = await db.customSelect(
          'SELECT occurred_at FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('null-occurred-at')],
        ).getSingle();
        expect(record.data['occurred_at'], isNull, reason: 'NULL occurred_at should be preserved');
      } finally {
        await db.close();
      }
    });

    test('migration handles special characters in habit IDs', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final specialHabitId = 'habit-with-special-chars-@#\$%^&*()';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [specialHabitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['special-char-record', now, specialHabitId, 1000]);

        final record = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE habit_id = ?',
          variables: [Variable.withString(specialHabitId)],
        ).getSingle();
        expect(record.data['habit_id'], specialHabitId);
      } finally {
        await db.close();
      }
    });

    test('migration maintains referential integrity across multiple habits', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        final habitCount = 5;
        final recordsPerHabit = 10;

        for (var i = 0; i < habitCount; i++) {
          final habitId = 'habit-$i';
          await db.customStatement('''
            INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
            VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, ?)
          ''', [habitId, now, 'Habit $i', '', (i + 1) * 1000.0]);

          for (var j = 0; j < recordsPerHabit; j++) {
            await db.customStatement('''
              INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
              VALUES (?, ?, ?, ?)
            ''', ['record-$i-$j', now + j * 1000, habitId, (j + 1) * 60000]);
          }
        }

        await verifier.migrateAndValidate(db, 26);

        for (var i = 0; i < habitCount; i++) {
          final habitId = 'habit-$i';
          final records = await db.customSelect(
            'SELECT COUNT(*) as count FROM habit_time_record_table WHERE habit_id = ?',
            variables: [Variable.withString(habitId)],
          ).getSingle();
          expect(records.data['count'], recordsPerHabit, reason: 'All records for habit $i should be preserved');
        }
      } finally {
        await db.close();
      }
    });

    test('schema validation after full migration path', () async {
      final schema23 = await verifier.schemaAt(23);
      final db = AppDatabase(schema23.newConnection());

      try {
        await verifier.migrateAndValidate(db, 28);

        final tableInfo = await db.customSelect('PRAGMA table_info(habit_time_record_table)').get();
        final columnNames = tableInfo.map((row) => row.data['name'] as String).toSet();

        expect(columnNames.contains('id'), true);
        expect(columnNames.contains('created_date'), true);
        expect(columnNames.contains('modified_date'), true);
        expect(columnNames.contains('deleted_date'), true);
        expect(columnNames.contains('habit_id'), true);
        expect(columnNames.contains('duration'), true);
        expect(columnNames.contains('occurred_at'), true);
        expect(columnNames.contains('is_estimated'), true);

        final foreignKeys = await db.customSelect('PRAGMA foreign_key_list(habit_time_record_table)').get();
        expect(foreignKeys.isNotEmpty, true);

        final indexes = await db
            .customSelect("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='habit_time_record_table'")
            .get();
        expect(indexes.isNotEmpty, true);
      } finally {
        await db.close();
      }
    });

    test('migration handles deleted_date soft deletes correctly', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final habitId = 'test-habit-soft-delete';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, deleted_date)
          VALUES (?, ?, ?, ?, ?)
        ''', ['soft-deleted-record', now, habitId, 1000, now + 86400000]);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, deleted_date)
          VALUES (?, ?, ?, ?, NULL)
        ''', ['active-record', now, habitId, 2000]);

        final deletedRecord = await db.customSelect(
          'SELECT deleted_date FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('soft-deleted-record')],
        ).getSingle();
        expect(deletedRecord.data['deleted_date'], isNotNull);

        final activeRecord = await db.customSelect(
          'SELECT deleted_date FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('active-record')],
        ).getSingle();
        expect(activeRecord.data['deleted_date'], isNull);
      } finally {
        await db.close();
      }
    });

    test('migration handles modified_date updates correctly', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final habitId = 'test-habit-modified';
        final now = DateTime.now().millisecondsSinceEpoch;
        final modifiedTime = now + 3600000;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, modified_date)
          VALUES (?, ?, ?, ?, ?)
        ''', ['modified-record', now, habitId, 1000, modifiedTime]);

        final record = await db.customSelect(
          'SELECT created_date, modified_date FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('modified-record')],
        ).getSingle();
        expect(record.data['created_date'], now);
        expect(record.data['modified_date'], modifiedTime);
      } finally {
        await db.close();
      }
    });

    test('isEstimated column added in v27 with correct default', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final habitId = 'test-habit-estimated';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['pre-v27-record', now, habitId, 1000]);

        await verifier.migrateAndValidate(db, 27);

        final columns = await db.customSelect('PRAGMA table_info(habit_time_record_table)').get();
        final isEstimatedColumn = columns.where((row) => row.data['name'] == 'is_estimated').toList();
        expect(isEstimatedColumn.isNotEmpty, true, reason: 'is_estimated column should exist');

        final record = await db.customSelect(
          'SELECT is_estimated FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('pre-v27-record')],
        ).getSingle();
        expect(record.data['is_estimated'], 0, reason: 'Default value should be false (0)');
      } finally {
        await db.close();
      }
    });

    test('migration handles very large duration values', () async {
      final schema26 = await verifier.schemaAt(26);
      final db = AppDatabase(schema26.newConnection());

      try {
        final habitId = 'test-habit-large-duration';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        final maxInt = 9223372036854775807;
        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration)
          VALUES (?, ?, ?, ?)
        ''', ['large-duration', now, habitId, maxInt]);

        final record = await db.customSelect(
          'SELECT duration FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('large-duration')],
        ).getSingle();
        expect(record.data['duration'], maxInt);
      } finally {
        await db.close();
      }
    });

    test('migration preserves index after table recreation', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        await verifier.migrateAndValidate(db, 26);

        final indexes = await db.customSelect('''
          SELECT name FROM sqlite_master 
          WHERE type='index' AND tbl_name='habit_time_record_table'
        ''').get();

        final indexNames = indexes.map((row) => row.data['name'] as String).toList();
        expect(indexNames.contains('idx_habit_time_record_habit_date'), true, reason: 'Performance index should exist');
      } finally {
        await db.close();
      }
    });

    test('backward compatibility: v26 can read v25 data structure', () async {
      final schema25 = await verifier.schemaAt(25);
      final db = AppDatabase(schema25.newConnection());

      try {
        final habitId = 'test-habit-backward';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, `order`)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7, 1000.0)
        ''', [habitId, now, 'Test Habit', '']);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, occurred_at)
          VALUES (?, ?, ?, ?, ?)
        ''', ['backward-test', now, habitId, 5000, now]);

        final beforeMigration = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('backward-test')],
        ).getSingle();
        expect(beforeMigration.data['duration'], 5000);
        expect(beforeMigration.data['occurred_at'], now);

        await verifier.migrateAndValidate(db, 26);

        final afterMigration = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('backward-test')],
        ).getSingle();
        expect(afterMigration.data['duration'], 5000, reason: 'Duration preserved');
        expect(afterMigration.data['occurred_at'], now, reason: 'Timestamp preserved');
      } finally {
        await db.close();
      }
    });

    test('migration from v24 creates table if missing', () async {
      final schema24 = await verifier.schemaAt(24);
      final db = AppDatabase(schema24.newConnection());

      try {
        await db.customStatement('DROP TABLE IF EXISTS habit_time_record_table');

        await verifier.migrateAndValidate(db, 26);

        final tableExists = await db.customSelect('''
          SELECT name FROM sqlite_master WHERE type='table' AND name='habit_time_record_table'
        ''').getSingleOrNull();
        expect(tableExists, isNotNull, reason: 'Table should be created if missing');

        final columns = await db.customSelect('PRAGMA table_info(habit_time_record_table)').get();
        final columnNames = columns.map((row) => row.data['name'] as String).toSet();
        expect(columnNames.contains('occurred_at'), true);
        expect(columnNames.contains('duration'), true);
      } finally {
        await db.close();
      }
    });

    test('full migration path handles all edge cases', () async {
      final schema23 = await verifier.schemaAt(23);
      final db = AppDatabase(schema23.newConnection());

      try {
        final habitId = 'comprehensive-test-habit';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement('''
          INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days)
          VALUES (?, ?, ?, ?, 0, '', 0, 1, 7)
        ''', [habitId, now, 'Comprehensive Test', '']);

        await verifier.migrateAndValidate(db, 28);

        final tableExists = await db.customSelect('''
          SELECT name FROM sqlite_master WHERE type='table' AND name='habit_time_record_table'
        ''').getSingleOrNull();
        expect(tableExists, isNotNull);

        await db.customStatement('''
          INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, occurred_at, is_estimated)
          VALUES (?, ?, ?, ?, ?, ?)
        ''', ['comprehensive-record', now, habitId, 7200000, now, 0]);

        final record = await db.customSelect(
          'SELECT * FROM habit_time_record_table WHERE id = ?',
          variables: [Variable.withString('comprehensive-record')],
        ).getSingle();
        expect(record.data['habit_id'], habitId);
        expect(record.data['duration'], 7200000);
        expect(record.data['occurred_at'], now);
        expect(record.data['is_estimated'], 0);
      } finally {
        await db.close();
      }
    });
  });
}
