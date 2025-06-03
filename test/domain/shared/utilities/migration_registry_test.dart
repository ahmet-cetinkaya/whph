import 'package:flutter_test/flutter_test.dart';
import 'package:whph/domain/shared/utilities/migration_registry.dart';
import 'package:whph/domain/shared/utilities/semantic_version.dart';

void main() {
  group('MigrationRegistry', () {
    late MigrationRegistry registry;

    setUp(() {
      registry = MigrationRegistry();
    });

    group('migration registration', () {
      test('should register migrations correctly', () {
        // Arrange
        Future<Map<String, dynamic>> testMigration(Map<String, dynamic> data) async {
          return {...data, 'migrated': true};
        }

        // Act
        registry.registerMigration(
          fromVersion: '1.0.0',
          toVersion: '1.1.0',
          description: 'Test migration',
          migrationFunction: testMigration,
        );

        // Assert
        final migrations = registry.registeredMigrations;
        expect(migrations.length, 1);
        expect(migrations.first.fromVersion, SemanticVersion.parse('1.0.0'));
        expect(migrations.first.toVersion, SemanticVersion.parse('1.1.0'));
        expect(migrations.first.description, 'Test migration');
      });

      test('should sort migrations by fromVersion', () {
        // Arrange
        Future<Map<String, dynamic>> migration1(Map<String, dynamic> data) async => data;
        Future<Map<String, dynamic>> migration2(Map<String, dynamic> data) async => data;
        Future<Map<String, dynamic>> migration3(Map<String, dynamic> data) async => data;

        // Act - Register in non-chronological order
        registry.registerMigration(
          fromVersion: '2.0.0',
          toVersion: '2.1.0',
          description: 'Migration 3',
          migrationFunction: migration3,
        );

        registry.registerMigration(
          fromVersion: '1.0.0',
          toVersion: '1.1.0',
          description: 'Migration 1',
          migrationFunction: migration1,
        );

        registry.registerMigration(
          fromVersion: '1.1.0',
          toVersion: '2.0.0',
          description: 'Migration 2',
          migrationFunction: migration2,
        );

        // Assert
        final migrations = registry.registeredMigrations;
        expect(migrations.length, 3);
        expect(migrations[0].fromVersion, SemanticVersion.parse('1.0.0'));
        expect(migrations[1].fromVersion, SemanticVersion.parse('1.1.0'));
        expect(migrations[2].fromVersion, SemanticVersion.parse('2.0.0'));
      });
    });

    group('migration path calculation', () {
      setUp(() {
        // Register test migrations
        registry.registerMigration(
          fromVersion: '1.0.0',
          toVersion: '1.1.0',
          description: 'Migration 1.0.0 to 1.1.0',
          migrationFunction: (data) async => {...data, 'step1': true},
        );

        registry.registerMigration(
          fromVersion: '1.1.0',
          toVersion: '1.2.0',
          description: 'Migration 1.1.0 to 1.2.0',
          migrationFunction: (data) async => {...data, 'step2': true},
        );

        registry.registerMigration(
          fromVersion: '1.2.0',
          toVersion: '2.0.0',
          description: 'Migration 1.2.0 to 2.0.0',
          migrationFunction: (data) async => {...data, 'step3': true},
        );
      });

      test('should return empty path when no migration needed', () {
        // Arrange
        final sourceVersion = SemanticVersion.parse('2.0.0');
        final targetVersion = SemanticVersion.parse('2.0.0');

        // Act
        final path = registry.getMigrationPath(sourceVersion, targetVersion);

        // Assert
        expect(path, isEmpty);
      });

      test('should return empty path when source is newer than target', () {
        // Arrange
        final sourceVersion = SemanticVersion.parse('2.0.0');
        final targetVersion = SemanticVersion.parse('1.0.0');

        // Act
        final path = registry.getMigrationPath(sourceVersion, targetVersion);

        // Assert
        expect(path, isEmpty);
      });

      test('should return single migration step', () {
        // Arrange
        final sourceVersion = SemanticVersion.parse('1.0.0');
        final targetVersion = SemanticVersion.parse('1.1.0');

        // Act
        final path = registry.getMigrationPath(sourceVersion, targetVersion);

        // Assert
        expect(path.length, 1);
        expect(path.first.fromVersion, SemanticVersion.parse('1.0.0'));
        expect(path.first.toVersion, SemanticVersion.parse('1.1.0'));
      });

      test('should return multiple migration steps in sequence', () {
        // Arrange
        final sourceVersion = SemanticVersion.parse('1.0.0');
        final targetVersion = SemanticVersion.parse('2.0.0');

        // Act
        final path = registry.getMigrationPath(sourceVersion, targetVersion);

        // Assert
        expect(path.length, 3);
        expect(path[0].fromVersion, SemanticVersion.parse('1.0.0'));
        expect(path[0].toVersion, SemanticVersion.parse('1.1.0'));
        expect(path[1].fromVersion, SemanticVersion.parse('1.1.0'));
        expect(path[1].toVersion, SemanticVersion.parse('1.2.0'));
        expect(path[2].fromVersion, SemanticVersion.parse('1.2.0'));
        expect(path[2].toVersion, SemanticVersion.parse('2.0.0'));
      });

      test('should handle partial migration paths', () {
        // Arrange
        final sourceVersion = SemanticVersion.parse('1.1.0');
        final targetVersion = SemanticVersion.parse('2.0.0');

        // Act
        final path = registry.getMigrationPath(sourceVersion, targetVersion);

        // Assert
        expect(path.length, 2);
        expect(path[0].fromVersion, SemanticVersion.parse('1.1.0'));
        expect(path[0].toVersion, SemanticVersion.parse('1.2.0'));
        expect(path[1].fromVersion, SemanticVersion.parse('1.2.0'));
        expect(path[1].toVersion, SemanticVersion.parse('2.0.0'));
      });

      test('should return empty path when no migrations are defined for range', () {
        // Arrange
        final sourceVersion = SemanticVersion.parse('0.5.0');
        final targetVersion = SemanticVersion.parse('1.0.0');

        // Act
        final path = registry.getMigrationPath(sourceVersion, targetVersion);

        // Assert
        expect(path, isEmpty); // No migrations defined for this range
      });
    });

    group('migration needed check', () {
      test('should return false when versions are equal', () {
        // Arrange
        final sourceVersion = SemanticVersion.parse('1.0.0');
        final targetVersion = SemanticVersion.parse('1.0.0');

        // Act
        final result = registry.isMigrationNeeded(sourceVersion, targetVersion);

        // Assert
        expect(result, false);
      });

      test('should return false when source is newer', () {
        // Arrange
        final sourceVersion = SemanticVersion.parse('2.0.0');
        final targetVersion = SemanticVersion.parse('1.0.0');

        // Act
        final result = registry.isMigrationNeeded(sourceVersion, targetVersion);

        // Assert
        expect(result, false);
      });

      test('should return true when migrations are available', () {
        // Arrange
        registry.registerMigration(
          fromVersion: '1.0.0',
          toVersion: '1.1.0',
          description: 'Test migration',
          migrationFunction: (data) async => data,
        );

        final sourceVersion = SemanticVersion.parse('1.0.0');
        final targetVersion = SemanticVersion.parse('1.1.0');

        // Act
        final result = registry.isMigrationNeeded(sourceVersion, targetVersion);

        // Assert
        expect(result, true);
      });

      test('should return false when no migrations are defined', () {
        // Arrange
        final sourceVersion = SemanticVersion.parse('0.5.0');
        final targetVersion = SemanticVersion.parse('1.0.0');

        // Act
        final result = registry.isMigrationNeeded(sourceVersion, targetVersion);

        // Assert
        expect(result, false);
      });
    });

    group('utility methods', () {
      test('should clear all migrations', () {
        // Arrange
        registry.registerMigration(
          fromVersion: '1.0.0',
          toVersion: '1.1.0',
          description: 'Test migration',
          migrationFunction: (data) async => data,
        );

        // Act
        registry.clear();

        // Assert
        expect(registry.registeredMigrations, isEmpty);
      });
    });

    group('migration function execution', () {
      test('should execute migration functions correctly', () async {
        // Arrange
        Future<Map<String, dynamic>> testMigration(Map<String, dynamic> data) async {
          return {...data, 'migrated': true, 'newField': 'test'};
        }

        registry.registerMigration(
          fromVersion: '1.0.0',
          toVersion: '1.1.0',
          description: 'Test migration',
          migrationFunction: testMigration,
        );

        final sourceVersion = SemanticVersion.parse('1.0.0');
        final targetVersion = SemanticVersion.parse('1.1.0');
        final path = registry.getMigrationPath(sourceVersion, targetVersion);

        // Act
        final inputData = {'original': 'data'};
        final result = await path.first.migrationFunction(inputData);

        // Assert
        expect(result['original'], 'data');
        expect(result['migrated'], true);
        expect(result['newField'], 'test');
      });
    });
  });
}
