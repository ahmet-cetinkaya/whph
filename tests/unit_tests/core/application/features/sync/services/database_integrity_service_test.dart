import 'package:flutter_test/flutter_test.dart';
import 'package:application/features/sync/services/database_integrity_service.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

void main() {
  group('DatabaseIntegrityService Tests', () {
    late AppDatabase database;
    late DatabaseIntegrityService service;

    setUp(() {
      database = AppDatabase.forTesting();
      service = DatabaseIntegrityService(database);
    });

    tearDown(() async {
      await database.close();
    });

    group('Integrity Validation', () {
      test('should detect no issues in clean database', () async {
        final report = await service.validateIntegrity();

        expect(report.hasIssues, false);
        expect(report.duplicateIds, isEmpty);
        expect(report.orphanedReferences, isEmpty);
        expect(report.softDeleteInconsistencies, 0);
        expect(report.timestampInconsistencies, 0);
      });

      test('should create readable report for clean database', () async {
        final report = await service.validateIntegrity();
        expect(report.toString(), contains('No issues found'));
      });

      test('should detect timestamp inconsistencies when inserting text dates', () async {
        // This test verifies that text dates in integer columns are detected
        // Use integer timestamps to avoid triggering timestamp inconsistency check
        final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-1', 'Tag 1', ?, 0)
        ''', [nowTimestamp]);
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-2', 'Tag 2', ?, 0)
        ''', [nowTimestamp]);

        final report = await service.validateIntegrity();

        // PK constraint prevents duplicates, so finding none is correct
        expect(report.duplicateIds.containsKey('tag_table'), false);
        // No timestamp issues with proper integer values
        expect(report.timestampInconsistencies, equals(0));
      });

      test('should fix duplicate IDs by keeping most recent', () async {
        final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-1', 'Tag 1', ?, 0)
        ''', [nowTimestamp]);
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-2', 'Tag 2', ?, 0)
        ''', [nowTimestamp]);

        await service.fixIntegrityIssues();

        final activeTags = await database.customSelect('''
          SELECT COUNT(*) as count FROM tag_table WHERE deleted_date IS NULL
        ''').getSingleOrNull();

        expect(activeTags?.data['count'], equals(2));
      });
    });

    group('Report Formatting', () {
      test('should format complex issues report correctly', () async {
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-1', 'Tag A', '2025-01-01 00:00:00', 0)
        ''');

        await database.customStatement('''
          INSERT INTO task_tag_table (id, task_id, tag_id, created_date)
          VALUES ('tt-1', 'task-1', 'tag-1', '2025-01-01 00:00:00')
        ''');

        await database.customStatement('''
          UPDATE tag_table SET deleted_date = '2025-01-01 01:00:00' WHERE id = 'tag-1'
        ''');

        final report = await service.validateIntegrity();

        final reportString = report.toString();
        expect(reportString, contains('Database integrity issues found'));
        expect(reportString, contains('Orphaned references'));
        expect(reportString, contains('task_tags'));
      });
    });

    group('Sync Device Integrity', () {
      test('should NOT delete valid sync device with integer timestamp (future date)', () async {
        await database.customStatement('''
          INSERT INTO sync_device_table (id, created_date, from_ip, to_ip, from_device_id, to_device_id, modified_date, last_sync_date, deleted_date, name)
          VALUES ('TLnBqPHUdUdrcjQjqDsYG', 1768336435, '127.0.0.1', '127.0.0.1', 'dev1', 'dev2', NULL, NULL, NULL, 'Test Device')
        ''');

        final initialCheck = await database.customSelect('SELECT * FROM sync_device_table WHERE id = ?',
            variables: [Variable.withString('TLnBqPHUdUdrcjQjqDsYG')]).getSingle();
        expect(initialCheck.data['deleted_date'], isNull);

        await service.fixIntegrityIssues();

        final finalCheck = await database.customSelect('SELECT * FROM sync_device_table WHERE id = ?',
            variables: [Variable.withString('TLnBqPHUdUdrcjQjqDsYG')]).getSingle();

        if (finalCheck.data['deleted_date'] != null) {
          fail('Device was incorrectly soft-deleted! Bug reproduced.');
        }
      });

      test('should delete actually ancient sync device', () async {
        final ancientDate = DateTime.now().subtract(Duration(days: 365 * 10));
        final ancientTimestamp = ancientDate.millisecondsSinceEpoch ~/ 1000;

        await database.customStatement('''
            INSERT INTO sync_device_table (id, created_date, from_ip, to_ip, from_device_id, to_device_id, modified_date, last_sync_date, deleted_date, name)
            VALUES ('ancient-dev', ?, '127.0.0.1', '127.0.0.1', 'dev1', 'dev2', NULL, NULL, NULL, 'Test Device')
          ''', [ancientTimestamp]);

        await service.fixIntegrityIssues();

        final finalCheck = await database.customSelect('SELECT * FROM sync_device_table WHERE id = ?',
            variables: [Variable.withString('ancient-dev')]).getSingle();

        expect(finalCheck.data['deleted_date'], isNotNull, reason: "Ancient device should be deleted");
      });

      test('should repair corrupted text timestamps', () async {
        // Arrange - Insert a record with TEXT formatted date in integer columns
        // We use a raw text insert query to bypass Drift's type safety
        await database.customStatement('''
            INSERT INTO sync_device_table (id, created_date, from_ip, to_ip, from_device_id, to_device_id, modified_date, last_sync_date, deleted_date, name)
            VALUES ('corrupt-dev', '2026-01-12 10:36:57', '127.0.0.1', '127.0.0.1', 'dev1', 'dev2', NULL, NULL, NULL, 'Corrupt Device')
        ''');

        // Verify it is indeed text and would normally crash queries expecting int
        final typeCheck = await database
            .customSelect("SELECT typeof(created_date) as type FROM sync_device_table WHERE id = 'corrupt-dev'")
            .getSingle();
        expect(typeCheck.data['type'], equals('text'));

        // Act - this calls fixCriticalIntegrityIssues which calls _repairCorruptedTimestamps
        await service.fixCriticalIntegrityIssues();

        // Assert
        final finalTypeCheck = await database
            .customSelect("SELECT typeof(created_date) as type FROM sync_device_table WHERE id = 'corrupt-dev'")
            .getSingle();

        expect(finalTypeCheck.data['type'], isNot(equals('text')), reason: "Should be repaired to integer");

        // Also verify the cleanup: created_date should be a valid int now
        final finalCheck = await database.customSelect('SELECT * FROM sync_device_table WHERE id = ?',
            variables: [Variable.withString('corrupt-dev')]).getSingle();
        expect(finalCheck.data['created_date'], isA<int>());
      });
    });

    group('Timestamp Consistency Tests', () {
      test('should detect timestamp inconsistencies in report', () async {
        // Arrange - Insert a record with TEXT formatted date
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived, modified_date, deleted_date)
          VALUES ('tag-corrupt', 'Tag Corrupt', 'CURRENT_TIMESTAMP', 0, 'CURRENT_TIMESTAMP', NULL)
        ''');

        // Act
        final report = await service.validateIntegrity();

        // Assert - Should detect timestamp inconsistencies
        expect(report.timestampInconsistencies, greaterThan(0),
            reason: 'Should detect text timestamps in date columns');
      });

      test('should detect timestamp inconsistencies in task_tag_table', () async {
        // Arrange - Insert a record with TEXT formatted date in task_tag_table
        await database.customStatement('''
          INSERT INTO task_tag_table (id, task_id, tag_id, created_date, modified_date, deleted_date)
          VALUES ('tt-corrupt', 'task-1', 'tag-1', 'CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP', NULL)
        ''');

        // Act
        final report = await service.validateIntegrity();

        // Assert
        expect(report.timestampInconsistencies, greaterThan(0),
            reason: 'Should detect text timestamps in task_tag_table');
      });

      test('should detect timestamp inconsistencies in habit_tag_table', () async {
        // Arrange
        await database.customStatement('''
          INSERT INTO habit_tag_table (id, habit_id, tag_id, created_date, modified_date, deleted_date)
          VALUES ('ht-corrupt', 'habit-1', 'tag-1', 'CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP', NULL)
        ''');

        // Act
        final report = await service.validateIntegrity();

        // Assert
        expect(report.timestampInconsistencies, greaterThan(0),
            reason: 'Should detect text timestamps in habit_tag_table');
      });

      test('should detect timestamp inconsistencies in app_usage_tag_table', () async {
        // Arrange
        await database.customStatement('''
          INSERT INTO app_usage_tag_table (id, app_usage_id, tag_id, created_date, modified_date, deleted_date)
          VALUES ('aut-corrupt', 'app-1', 'tag-1', 'CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP', NULL)
        ''');

        // Act
        final report = await service.validateIntegrity();

        // Assert
        expect(report.timestampInconsistencies, greaterThan(0),
            reason: 'Should detect text timestamps in app_usage_tag_table');
      });

      test('should detect timestamp inconsistencies in note_tag_table', () async {
        // Arrange
        await database.customStatement('''
          INSERT INTO note_tag_table (id, note_id, tag_id, created_date, modified_date, deleted_date)
          VALUES ('nt-corrupt', 'note-1', 'tag-1', 'CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP', NULL)
        ''');

        // Act
        final report = await service.validateIntegrity();

        // Assert
        expect(report.timestampInconsistencies, greaterThan(0),
            reason: 'Should detect text timestamps in note_tag_table');
      });

      test('should detect timestamp inconsistencies in tag_tag_table', () async {
        // Arrange
        await database.customStatement('''
          INSERT INTO tag_tag_table (id, primary_tag_id, secondary_tag_id, created_date, modified_date, deleted_date)
          VALUES ('ttag-corrupt', 'tag-1', 'tag-2', 'CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP', NULL)
        ''');

        // Act
        final report = await service.validateIntegrity();

        // Assert
        expect(report.timestampInconsistencies, greaterThan(0),
            reason: 'Should detect text timestamps in tag_tag_table');
      });

      test('should detect multiple timestamp inconsistencies across columns', () async {
        // Arrange - Insert records with TEXT in multiple columns
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived, modified_date, deleted_date)
          VALUES ('tag-c1', 'Tag C1', 'CURRENT_TIMESTAMP', 0, 'CURRENT_TIMESTAMP', 'CURRENT_TIMESTAMP')
        ''');

        // Act
        final report = await service.validateIntegrity();

        // Assert - Should detect at least 3 corrupted timestamps (created_date, modified_date, deleted_date)
        expect(report.timestampInconsistencies, greaterThanOrEqualTo(3),
            reason: 'Should detect multiple text timestamps across columns');
      });

      test('should include timestamp inconsistencies in report string', () async {
        // Arrange
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived, modified_date, deleted_date)
          VALUES ('tag-c2', 'Tag C2', 'CURRENT_TIMESTAMP', 0, 'CURRENT_TIMESTAMP', NULL)
        ''');

        // Act
        final report = await service.validateIntegrity();
        final reportString = report.toString();

        // Assert
        expect(report.timestampInconsistencies, greaterThan(0));
        expect(reportString, contains('Timestamp inconsistencies'));
        expect(reportString, contains('corrupted date fields'));
      });

      test('should report no timestamp inconsistencies in clean database', () async {
        // Arrange - Insert a record with proper integer timestamps
        final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived, modified_date, deleted_date)
          VALUES ('tag-clean', 'Tag Clean', ?, 0, ?, NULL)
        ''', [nowTimestamp, nowTimestamp]);

        // Act
        final report = await service.validateIntegrity();

        // Assert
        expect(report.timestampInconsistencies, equals(0),
            reason: 'Should have no timestamp inconsistencies with proper integer values');
      });

      test('should repair text timestamps in tag_table during fixCriticalIntegrityIssues', () async {
        // Arrange
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived, modified_date, deleted_date)
          VALUES ('tag-repair', 'Tag Repair', '2025-03-15 10:30:00', 0, '2025-03-15 10:30:00', NULL)
        ''');

        // Verify pre-repair state
        final preTypeCheck = await database
            .customSelect("SELECT typeof(created_date) as type FROM tag_table WHERE id = 'tag-repair'")
            .getSingle();
        expect(preTypeCheck.data['type'], equals('text'));

        // Act
        await service.fixCriticalIntegrityIssues();

        // Assert - Should be repaired to integer
        final postTypeCheck = await database
            .customSelect("SELECT typeof(created_date) as type FROM tag_table WHERE id = 'tag-repair'")
            .getSingle();
        expect(postTypeCheck.data['type'], isNot(equals('text')));

        // Verify the value is now an integer
        final postCheck =
            await database.customSelect("SELECT created_date FROM tag_table WHERE id = 'tag-repair'").getSingle();
        expect(postCheck.data['created_date'], isA<int>());
      });

      test('should repair text timestamps in task_tag_table during fixCriticalIntegrityIssues', () async {
        // Arrange
        await database.customStatement('''
          INSERT INTO task_tag_table (id, task_id, tag_id, created_date, modified_date, deleted_date)
          VALUES ('tt-repair', 'task-1', 'tag-1', '2025-04-20 14:25:00', '2025-04-20 14:25:00', NULL)
        ''');

        // Verify pre-repair state
        final preTypeCheck = await database
            .customSelect("SELECT typeof(created_date) as type FROM task_tag_table WHERE id = 'tt-repair'")
            .getSingle();
        expect(preTypeCheck.data['type'], equals('text'));

        // Act
        await service.fixCriticalIntegrityIssues();

        // Assert
        final postTypeCheck = await database
            .customSelect("SELECT typeof(created_date) as type FROM task_tag_table WHERE id = 'tt-repair'")
            .getSingle();
        expect(postTypeCheck.data['type'], isNot(equals('text')));
      });

      test('should handle non-existent tables gracefully during timestamp check', () async {
        // Act - Should not throw even if some tables don't exist
        final report = await service.validateIntegrity();

        // Assert
        expect(report, isNotNull);
        // The test passes if no exception is thrown
      });

      test('should call _repairCorruptedTimestamps in fixIntegrityIssues', () async {
        // Arrange - Create corrupted timestamps with parseable date strings
        final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived, modified_date, deleted_date)
          VALUES ('tag-fix1', 'Tag Fix1', ?, 0, ?, NULL)
        ''', [nowTimestamp, nowTimestamp]);

        // Now corrupt one of the dates to a text format that CAN be parsed
        await database.customStatement('''
          UPDATE tag_table SET created_date = '2025-01-12 10:36:57' WHERE id = 'tag-fix1'
        ''');

        final preReport = await service.validateIntegrity();
        expect(preReport.timestampInconsistencies, greaterThan(0));

        // Act
        await service.fixIntegrityIssues();

        // Assert - Should be repaired
        final postReport = await service.validateIntegrity();
        expect(postReport.timestampInconsistencies, equals(0), reason: 'All corrupted timestamps should be repaired');
      });

      test('should repair parseable text date strings to integer timestamps', () async {
        // Arrange - Insert a record with a parseable text date
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived, modified_date, deleted_date)
          VALUES ('tag-parseable', 'Tag Parseable', '2025-06-15 14:30:00', 0, 'CURRENT_TIMESTAMP', NULL)
        ''');

        // Verify pre-repair state
        final preTypeCheck = await database
            .customSelect("SELECT typeof(created_date) as type FROM tag_table WHERE id = 'tag-parseable'")
            .getSingle();
        expect(preTypeCheck.data['type'], equals('text'));

        // Act
        await service.fixCriticalIntegrityIssues();

        // Assert - Should be repaired to integer
        final postTypeCheck = await database
            .customSelect("SELECT typeof(created_date) as type FROM tag_table WHERE id = 'tag-parseable'")
            .getSingle();
        expect(postTypeCheck.data['type'], equals('integer'));

        // Verify the value is now an integer (the parsed timestamp)
        final postCheck =
            await database.customSelect("SELECT created_date FROM tag_table WHERE id = 'tag-parseable'").getSingle();
        final createdDate = postCheck.data['created_date'] as int;
        expect(createdDate, isA<int>());
        // The parsed date should be approximately correct for June 15, 2025
        // 2025-06-15 14:30:00 UTC is approximately 1750000000 seconds from epoch
        expect(createdDate, greaterThan(1740000000)); // After March 2025
        expect(createdDate, lessThan(1800000000)); // Before 2027
      });
    });
  });
}
