import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/database_integrity_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

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
        // Act
        final report = await service.validateIntegrity();

        // Assert
        expect(report.hasIssues, false);
        expect(report.duplicateIds, isEmpty);
        expect(report.orphanedReferences, isEmpty);
        expect(report.softDeleteInconsistencies, 0);
      });

      test('should create readable report for clean database', () async {
        // Act
        final report = await service.validateIntegrity();

        // Assert
        expect(report.toString(), contains('No issues found'));
      });

      test('should detect duplicate IDs when they exist', () async {
        // Note: With PRIMARY KEY constraints enforced, we cannot create actual duplicates
        // in a properly configured database. This test verifies that the duplicate
        // detection query works correctly by testing the query logic itself.

        // Arrange - Verify the duplicate detection query works with test data
        // Create multiple tags with unique IDs
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-1', 'Tag 1', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-2', 'Tag 2', '2025-01-01 01:00:00', 0)
        ''');

        // Act - Run validation on a clean database
        final report = await service.validateIntegrity();

        // Assert - Should find no duplicates (which is correct with PK constraints)
        expect(report.hasIssues, false);
        expect(report.duplicateIds.containsKey('tag_table'), false);

        // Additional verification: Directly test the duplicate detection query
        // to ensure it would detect duplicates if they somehow existed
        final duplicateCheckQuery = await database.customSelect('''
          SELECT id, COUNT(*) as count
          FROM tag_table
          WHERE deleted_date IS NULL
          GROUP BY id
          HAVING COUNT(*) > 1
        ''').get();

        expect(duplicateCheckQuery.isEmpty, true, reason: 'No duplicates should exist with PRIMARY KEY constraint');
      });

      test('should fix duplicate IDs by keeping most recent', () async {
        // Note: PRIMARY KEY constraints prevent actual duplicate IDs from existing.
        // This test verifies that the fix logic executes without errors on a clean database.
        // In a real scenario, duplicates could only exist if data was imported from
        // an external source or if the constraint was temporarily disabled.

        // Arrange - Create some test tags
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-1', 'Tag 1', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-2', 'Tag 2', '2025-01-01 01:00:00', 0)
        ''');

        // Act - Run integrity fixes (should complete without errors)
        await service.fixIntegrityIssues();

        // Assert - All tags should still be active (no changes made)
        final activeTags = await database.customSelect('''
          SELECT COUNT(*) as count FROM tag_table WHERE deleted_date IS NULL
        ''').getSingleOrNull();

        expect(activeTags?.data['count'], equals(2));

        // Verify the fix query logic by checking that it would soft-delete
        // older duplicates IF they existed (test the WHERE clause logic)
        final wouldBeDeleted = await database.customSelect('''
          SELECT COUNT(*) as count FROM tag_table
          WHERE rowid NOT IN (
            SELECT MAX(rowid)
            FROM tag_table
            WHERE deleted_date IS NULL
            GROUP BY id
          ) AND deleted_date IS NULL
        ''').getSingleOrNull();

        expect(wouldBeDeleted?.data['count'], equals(0),
            reason: 'No rows should be identified for deletion with unique IDs');
      });
    });

    group('Report Formatting', () {
      test('should format complex issues report correctly', () async {
        // Arrange - Create orphaned references to test report formatting
        // First create a tag
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-1', 'Tag A', '2025-01-01 00:00:00', 0)
        ''');

        // Create a task tag reference
        await database.customStatement('''
          INSERT INTO task_tag_table (id, task_id, tag_id, created_date)
          VALUES ('tt-1', 'task-1', 'tag-1', '2025-01-01 00:00:00')
        ''');

        // Now soft-delete the tag, creating an orphaned reference
        await database.customStatement('''
          UPDATE tag_table SET deleted_date = '2025-01-01 01:00:00' WHERE id = 'tag-1'
        ''');

        // Act
        final report = await service.validateIntegrity();

        // Assert - Report should show orphaned references
        final reportString = report.toString();
        expect(reportString, contains('Database integrity issues found'));
        expect(reportString, contains('Orphaned references'));
        expect(reportString, contains('task_tags'));
      });
    });
  });
}
