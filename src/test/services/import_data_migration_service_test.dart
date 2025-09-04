import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/settings/services/import_data_migration_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';

void main() {
  group('ImportDataMigrationService', () {
    late ImportDataMigrationService migrationService;

    setUp(() {
      migrationService = ImportDataMigrationService();
    });

    group('isMigrationNeeded', () {
      test('should return false when versions are equal', () {
        // Act - Current app version
        final result = migrationService.isMigrationNeeded(AppInfo.version);

        // Assert
        expect(result, false);
      });

      test('should return false when no specific migrations are defined', () {
        // Act - Testing migration from older version to current version
        // No migrations are defined between these versions, so should return false
        final result = migrationService.isMigrationNeeded('0.6.4');

        // Assert
        expect(result, false); // No specific migrations defined, so no migration needed
      });

      test('should return false when source version is newer than current', () {
        // Act - Use a version higher than current
        final result = migrationService.isMigrationNeeded('1.0.0');

        // Assert
        expect(result, false); // Newer versions don't need migration
      });

      test('should return false for invalid version formats', () {
        // Act
        final result = migrationService.isMigrationNeeded('invalid-version');

        // Assert
        expect(result, false); // Invalid versions return false
      });
    });

    group('getAvailableMigrationVersions', () {
      test('should return list containing current app version when no migrations are defined', () {
        // Act
        final versions = migrationService.getAvailableMigrationVersions();

        // Assert
        expect(versions, isNotEmpty);
        expect(versions, contains(AppInfo.version)); // Should contain current app version
      });
    });

    group('migrateData', () {
      test('should return same data when versions are equal', () async {
        // Arrange
        final testData = {
          'version': AppInfo.version,
          'tags': [
            {'id': '1', 'name': 'Test Tag'}
          ]
        };

        // Act
        final result = await migrationService.migrateData(testData, AppInfo.version);

        // Assert
        expect(result, equals(testData));
      });

      test('should update app version when no specific migrations are defined', () async {
        // Arrange
        final testData = {
          'version': '0.6.4',
          'tags': [
            {'id': '1', 'name': 'Test Tag'}
          ]
        };

        // Act
        final result = await migrationService.migrateData(testData, '0.6.4');

        // Assert
        // Data should be preserved as-is, but app version should be updated
        expect(result['version'], equals('0.6.4')); // Original version should be preserved
        expect(result['tags'], equals(testData['tags'])); // Tags should be preserved
        expect(result['appInfo']['version'], equals(AppInfo.version)); // App version should be updated to current
      });

      test('should return data as-is when source version is newer', () async {
        // Arrange - Use a version higher than current
        final newerVersion = '1.0.0'; // This should be newer than current version
        final testData = {
          'version': newerVersion,
          'tags': [
            {'id': '1', 'name': 'Test Tag'}
          ]
        };

        // Act
        final result = await migrationService.migrateData(testData, newerVersion);

        // Assert
        expect(result, equals(testData)); // No migration needed for newer versions
      });

      test('should throw exception for invalid version format', () async {
        // Arrange
        final testData = {'version': 'invalid-version', 'tags': []};

        // Act & Assert
        expect(
          () => migrationService.migrateData(testData, 'invalid-version'),
          throwsA(isA<BusinessException>()),
        );
      });

      test('should handle malformed data gracefully', () async {
        // Arrange
        final testData = <String, dynamic>{};

        // Act
        final result = await migrationService.migrateData(testData, '0.6.4');

        // Assert
        // Should not throw and should add appInfo
        expect(result['appInfo']['version'], equals(AppInfo.version));
      });
    });

    group('Semantic Versioning', () {
      test('should handle different semantic version formats', () async {
        // Arrange
        final testData = {'version': '0.6.4', 'tags': []};

        // Test various version formats
        final versions = ['0.6.4', '0.6.4-alpha', '0.6.4+build.1', 'v0.6.4'];

        for (final version in versions) {
          // Act
          final result = await migrationService.migrateData(testData, version);

          // Assert
          expect(result['appInfo']['version'], equals(AppInfo.version));
        }
      });

      test('should correctly compare semantic versions', () {
        // Test version comparison logic - using versions relative to current version
        final olderVersions = ['0.5.0', '0.6.3', '0.6.4-beta', '0.6.6'];
        final newerVersions = ['1.0.0', '2.0.0', '10.0.0'];

        for (final version in olderVersions) {
          expect(migrationService.isMigrationNeeded(version), false); // No migrations defined
        }

        for (final version in newerVersions) {
          expect(migrationService.isMigrationNeeded(version), false); // Newer versions don't need migration
        }
      });
    });

    group('Migration Infrastructure', () {
      test('should support future migration registration', () {
        // This test demonstrates the extensibility of the system
        // Future migrations would be registered in the _registerMigrations method

        // Arrange
        final versions = migrationService.getAvailableMigrationVersions();

        // Act & Assert
        expect(versions, isA<List<String>>());
        expect(versions.contains(AppInfo.version), true); // Current version should be included

        // The system is ready to handle future migrations when they are defined
        // For example, when a migration from current version to next version is added,
        // the system will automatically detect and apply it
      });
    });
  });
}
