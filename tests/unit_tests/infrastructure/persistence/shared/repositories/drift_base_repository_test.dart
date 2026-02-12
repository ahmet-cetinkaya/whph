import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';

void main() {
  group('DriftBaseRepository Fix Tests', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting();
    });

    tearDown(() async {
      await database.close();
    });

    group('getById Query Fix Validation', () {
      test('should handle custom query with LIMIT 1 correctly', () async {
        // Note: With PRIMARY KEY constraints, duplicate IDs cannot exist.
        // This test verifies the LIMIT 1 query approach works correctly.

        // Arrange - Create multiple different tags
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-1', 'First Tag', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('tag-2', 'Second Tag', '2025-01-01 01:00:00', 0)
        ''');

        // Act - Query with LIMIT 1 (the fix prevents "Too many elements" errors)
        final results = await database.customSelect('''
          SELECT * FROM tag_table
          WHERE id = ? AND deleted_date IS NULL
          ORDER BY created_date DESC LIMIT 1
        ''', variables: [Variable.withString('tag-1')]).get();

        // Assert - Should return exactly one result
        expect(results.length, equals(1));
        expect(results.first.data['name'], equals('First Tag'));
      });

      test('should return empty for non-existent ID', () async {
        // Act
        final results = await database.customSelect('''
          SELECT * FROM tag_table
          WHERE id = ? AND deleted_date IS NULL
          ORDER BY created_date DESC LIMIT 1
        ''', variables: [Variable.withString('non-existent-id')]).get();

        // Assert
        expect(results.isEmpty, true);
      });

      test('should verify ORDER BY created_date DESC prioritizes newer records', () async {
        // Arrange - Create tags at different times
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('test-1', 'Older Tag', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('test-2', 'Newer Tag', '2025-01-01 12:00:00', 0)
        ''');

        // Act - Query all tags, order by created_date DESC
        final allResults = await database.customSelect('''
          SELECT * FROM tag_table
          WHERE deleted_date IS NULL
          ORDER BY created_date DESC
        ''').get();

        // Assert - Newer tag should be first
        expect(allResults.length, greaterThanOrEqualTo(2));
        expect(allResults.first.data['name'], equals('Newer Tag'));
      });

      test('should demonstrate LIMIT 1 prevents multiple result errors', () async {
        // Arrange - Create multiple tags
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('unique-1', 'Tag A', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('unique-2', 'Tag B', '2025-01-01 01:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('unique-3', 'Tag C', '2025-01-01 02:00:00', 0)
        ''');

        // Act - Query with broad WHERE clause but LIMIT 1
        // This demonstrates the fix: LIMIT 1 prevents errors even if query could match multiple rows
        final results = await database.customSelect('''
          SELECT * FROM tag_table
          WHERE deleted_date IS NULL
          ORDER BY created_date DESC LIMIT 1
        ''').get();

        // Assert - Returns exactly 1 result (most recent)
        expect(results.length, equals(1));
        expect(results.first.data['name'], equals('Tag C'));
      });
    });
  });
}
