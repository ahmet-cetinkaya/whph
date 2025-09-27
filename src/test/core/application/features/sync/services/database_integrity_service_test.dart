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
        // Arrange - Create duplicate tags manually
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('duplicate-id', 'Tag 1', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('duplicate-id', 'Tag 2', '2025-01-01 01:00:00', 0)
        ''');

        // Act
        final report = await service.validateIntegrity();

        // Assert
        expect(report.hasIssues, true);
        expect(report.duplicateIds.containsKey('tag_table'), true);
        expect(report.duplicateIds['tag_table'], equals(1));
      });

      test('should fix duplicate IDs by keeping most recent', () async {
        // Arrange - Create duplicate tags
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('dup-id', 'Older Tag', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('dup-id', 'Newer Tag', '2025-01-01 01:00:00', 0)
        ''');

        // Act
        await service.fixIntegrityIssues();

        // Assert - Check that only one record remains (newer one)
        final remainingTags = await database.customSelect('''
          SELECT name FROM tag_table WHERE id = 'dup-id' AND deleted_date IS NULL
        ''').get();

        expect(remainingTags.length, equals(1));
        expect(remainingTags.first.data['name'], equals('Newer Tag'));

        // Check that older tag is soft-deleted
        final softDeletedTags = await database.customSelect('''
          SELECT name FROM tag_table WHERE id = 'dup-id' AND deleted_date IS NOT NULL
        ''').get();

        expect(softDeletedTags.length, equals(1));
        expect(softDeletedTags.first.data['name'], equals('Older Tag'));
      });
    });

    group('Report Formatting', () {
      test('should format complex issues report correctly', () async {
        // Arrange - Create multiple issues
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('dup1', 'Tag A', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('dup1', 'Tag B', '2025-01-01 01:00:00', 0)
        ''');

        // Act
        final report = await service.validateIntegrity();

        // Assert
        final reportString = report.toString();
        expect(reportString, contains('Database integrity issues found'));
        expect(reportString, contains('Duplicate IDs'));
        expect(reportString, contains('tag_table: 1 duplicates'));
      });
    });
  });
}
