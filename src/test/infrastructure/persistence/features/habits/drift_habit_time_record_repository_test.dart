import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;

void main() {
  group('DriftHabitTimeRecordRepository Tests', () {
    late AppDatabase database;
    late Directory tempDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      tempDir = await Directory.systemTemp.createTemp();
      AppDatabase.testDirectory = tempDir;
      AppDatabase.isTestMode = true;
    });

    setUp(() async {
      // Create in-memory database for testing
      database = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    });

    tearDown(() async {
      await database.close();
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    test('should create HabitTimeRecord table in database', () async {
      // Verify table exists by trying to query it
      final result = await database
          .customSelect('SELECT name FROM sqlite_master WHERE type="table" AND name="habit_time_record_table"')
          .get();
      expect(result.length, 1);
      expect(result.first.data['name'], 'habit_time_record_table');
    });

    test('should create index on habit_time_record table', () async {
      // Check for habit time record related index (SQLite auto-creates indexes for primary keys)
      final habitTimeRecordIndexes = await database
          .customSelect('SELECT name FROM sqlite_master WHERE type="index" AND name LIKE "%habit_time_record%"')
          .get();
      expect(habitTimeRecordIndexes.length, greaterThan(0),
          reason: 'Should have at least one habit time record related index');

      // Verify the auto-generated primary key index exists
      final autoIndex =
          habitTimeRecordIndexes.where((idx) => (idx.data['name'] as String).contains('autoindex')).toList();
      expect(autoIndex.length, 1, reason: 'Should have auto-generated primary key index');
    });

    test('should have correct table structure', () async {
      // Verify table columns
      final result = await database.customSelect('PRAGMA table_info(habit_time_record_table)').get();

      final columnNames = result.map((row) => row.data['name'] as String).toList();
      expect(columnNames, contains('id'));
      expect(columnNames, contains('created_date'));
      expect(columnNames, contains('modified_date'));
      expect(columnNames, contains('deleted_date'));
      expect(columnNames, contains('habit_id'));
      expect(columnNames, contains('duration'));
    });

    test('should allow basic CRUD operations on habit time records', () async {
      // First, create a habit record for the foreign key reference
      await database.into(database.habitTable).insert(
            HabitTableCompanion.insert(
              id: 'habit-123',
              createdDate: DateTime.utc(2024, 1, 1),
              name: 'Test Habit',
              description: 'Test Description',
            ),
          );

      // Insert a test record using Drift methods
      await database.into(database.habitTimeRecordTable).insert(
            HabitTimeRecordTableCompanion.insert(
              id: 'test-id',
              createdDate: DateTime.utc(2024, 1, 15, 14),
              habitId: 'habit-123',
              duration: 1800,
            ),
          );

      // Query the record
      final result = await database.customSelect(
        'SELECT * FROM habit_time_record_table WHERE id = ?',
        variables: [Variable<String>('test-id')],
      ).get();

      expect(result.length, 1);
      expect(result.first.data['id'], 'test-id');
      expect(result.first.data['habit_id'], 'habit-123');
      expect(result.first.data['duration'], 1800);
    });

    test('should support aggregation queries for total duration', () async {
      const habitId = 'habit-123';

      // First, create a habit record for the foreign key reference
      await database.customStatement(
        'INSERT INTO habit_table (id, created_date, name, description) VALUES (?, ?, ?, ?)',
        [habitId, DateTime.utc(2024, 1, 1).millisecondsSinceEpoch, 'Test Habit', 'Test Description'],
      );

      // Insert multiple records
      await database.customStatement(
        'INSERT INTO habit_time_record_table (id, created_date, habit_id, duration) VALUES (?, ?, ?, ?)',
        ['record-1', DateTime.utc(2024, 1, 15, 14).millisecondsSinceEpoch, habitId, 900],
      );

      await database.customStatement(
        'INSERT INTO habit_time_record_table (id, created_date, habit_id, duration) VALUES (?, ?, ?, ?)',
        ['record-2', DateTime.utc(2024, 1, 15, 15).millisecondsSinceEpoch, habitId, 1200],
      );

      // Query total duration
      final result = await database.customSelect(
        'SELECT SUM(duration) as total FROM habit_time_record_table WHERE habit_id = ?',
        variables: [Variable<String>(habitId)],
      ).get();

      expect(result.first.data['total'], 2100); // 900 + 1200
    });

    test('should support date range filtering', () async {
      const habitId = 'habit-123';

      // First, create a habit record for the foreign key reference
      await database.customStatement(
        'INSERT INTO habit_table (id, created_date, name, description) VALUES (?, ?, ?, ?)',
        [habitId, DateTime.utc(2024, 1, 1).millisecondsSinceEpoch, 'Test Habit', 'Test Description'],
      );

      // Insert records across different dates (using timestamps for direct comparison)
      final date1 = DateTime.utc(2024, 1, 10, 14).millisecondsSinceEpoch; // Before range
      final date2 = DateTime.utc(2024, 1, 15, 14).millisecondsSinceEpoch; // In range
      final date3 = DateTime.utc(2024, 1, 20, 14).millisecondsSinceEpoch; // After range

      await database.customStatement(
        'INSERT INTO habit_time_record_table (id, created_date, habit_id, duration) VALUES (?, ?, ?, ?)',
        ['record-1', date1, habitId, 900],
      );

      await database.customStatement(
        'INSERT INTO habit_time_record_table (id, created_date, habit_id, duration) VALUES (?, ?, ?, ?)',
        ['record-2', date2, habitId, 1200],
      );

      await database.customStatement(
        'INSERT INTO habit_time_record_table (id, created_date, habit_id, duration) VALUES (?, ?, ?, ?)',
        ['record-3', date3, habitId, 800],
      );

      // Query with date range filter (should only get middle record)
      final startTimestamp = DateTime.utc(2024, 1, 12).millisecondsSinceEpoch;
      final endTimestamp = DateTime.utc(2024, 1, 18).millisecondsSinceEpoch;

      final result = await database.customSelect(
        'SELECT SUM(duration) as total FROM habit_time_record_table WHERE habit_id = ? AND created_date >= ? AND created_date <= ?',
        variables: [
          Variable<String>(habitId),
          Variable<int>(startTimestamp),
          Variable<int>(endTimestamp),
        ],
      ).get();

      expect(result.first.data['total'] ?? 0, 1200); // Only the middle record
    });

    test('should handle NULL values correctly', () async {
      // First, create a habit record for the foreign key reference
      await database.customStatement(
        'INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, "order") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'habit-123',
          DateTime.utc(2024, 1, 1).millisecondsSinceEpoch,
          'Test Habit',
          'Test Description',
          0,
          '',
          0,
          1,
          7,
          0.0
        ],
      );

      // Insert record with NULL optional fields
      await database.customStatement(
        'INSERT INTO habit_time_record_table (id, created_date, habit_id, duration, modified_date, deleted_date) VALUES (?, ?, ?, ?, ?, ?)',
        ['test-id', DateTime.utc(2024, 1, 15, 14).millisecondsSinceEpoch, 'habit-123', 1800, null, null],
      );

      final result = await database.customSelect(
        'SELECT * FROM habit_time_record_table WHERE id = ?',
        variables: [Variable<String>('test-id')],
      ).get();

      expect(result.length, 1);
      expect(result.first.data['modified_date'], isNull);
      expect(result.first.data['deleted_date'], isNull);
    });
  });
}
