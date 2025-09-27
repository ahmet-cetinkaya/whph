import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

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
      test('should handle custom query with multiple records gracefully', () async {
        // Arrange - Create duplicate tags manually (simulating sync issue)
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('duplicate-id', 'Older Tag', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('duplicate-id', 'Newer Tag', '2025-01-01 01:00:00', 0)
        ''');

        // Act - This should NOT throw "Too many elements" error
        // Simulating the fixed query from DriftBaseRepository.getById
        final results = await database.customSelect('''
          SELECT * FROM tag_table
          WHERE id = ? AND deleted_date IS NULL
          ORDER BY created_date DESC LIMIT 1
        ''', variables: [Variable.withString('duplicate-id')]).get();

        // Assert
        expect(results.length, equals(1));
        expect(results.first.data['name'], equals('Newer Tag'));
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

      test('should handle old getSingleOrNull approach (will fail with duplicates)', () async {
        // Arrange - Create duplicate tags manually
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('dup-id', 'Tag 1', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('dup-id', 'Tag 2', '2025-01-01 01:00:00', 0)
        ''');

        // Act & Assert - Old approach should fail
        expect(() async {
          await database.customSelect('''
            SELECT * FROM tag_table WHERE id = ? AND deleted_date IS NULL
          ''', variables: [Variable.withString('dup-id')]).getSingleOrNull();
        }, throwsA(isA<StateError>()));
      });

      test('should verify new approach works with duplicates', () async {
        // Arrange - Create duplicate tags
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('new-approach-id', 'Tag 1', '2025-01-01 00:00:00', 0)
        ''');
        await database.customStatement('''
          INSERT INTO tag_table (id, name, created_date, is_archived)
          VALUES ('new-approach-id', 'Tag 2', '2025-01-01 01:00:00', 0)
        ''');

        // Act - New approach should work
        final results = await database.customSelect('''
          SELECT * FROM tag_table
          WHERE id = ? AND deleted_date IS NULL
          ORDER BY created_date DESC LIMIT 1
        ''', variables: [Variable.withString('new-approach-id')]).get();

        // Assert
        expect(results.length, equals(1));
        expect(results.first.data['name'], equals('Tag 2')); // Most recent
      });
    });
  });
}
