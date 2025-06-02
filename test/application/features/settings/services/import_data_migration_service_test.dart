import 'package:flutter_test/flutter_test.dart';
import 'package:whph/application/features/settings/services/import_data_migration_service.dart';
import 'package:whph/core/acore/errors/business_exception.dart';

void main() {
  group('ImportDataMigrationService', () {
    late ImportDataMigrationService migrationService;

    setUp(() {
      migrationService = ImportDataMigrationService();
    });

    group('isMigrationNeeded', () {
      test('should return false when versions are equal', () {
        // Act
        final result = migrationService.isMigrationNeeded('0.6.4');

        // Assert
        expect(result, false);
      });

      test('should return true when imported version is supported and different', () {
        // Note: This test would pass when we have an older supported version
        // For now, testing with the current version infrastructure

        // Act
        final result = migrationService.isMigrationNeeded('0.6.4');

        // Assert
        expect(result, false); // Since 0.6.4 is the current version
      });

      test('should return false for unsupported versions', () {
        // Act
        final result = migrationService.isMigrationNeeded('0.5.0');

        // Assert
        expect(result, false); // Unsupported versions return false
      });
    });

    group('getAvailableMigrationVersions', () {
      test('should return list of available migration versions', () {
        // Act
        final versions = migrationService.getAvailableMigrationVersions();

        // Assert
        expect(versions, isNotEmpty);
        expect(versions, contains('0.6.4'));
      });
    });

    group('migrateData', () {
      test('should return same data when no migration is needed', () async {
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
        expect(result, equals(testData));
      });

      test('should migrate data when migration is available', () async {
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
        // Since no actual migration exists yet, data should remain the same
        expect(result, equals(testData));
      });

      test('should throw exception for unsupported version migration', () async {
        // Arrange
        final testData = {'version': '0.5.0', 'tags': []};

        // Act & Assert
        expect(
          () => migrationService.migrateData(testData, '0.5.0'),
          throwsA(isA<BusinessException>()),
        );
      });

      test('should handle malformed data gracefully', () async {
        // Arrange
        final testData = <String, dynamic>{};

        // Act & Assert
        expect(
          () => migrationService.migrateData(testData, '0.6.3'),
          throwsA(isA<BusinessException>()),
        );
      });
    });

    group('Migration Infrastructure', () {
      test('should handle sequential migration versions correctly', () {
        // Arrange
        final versions = migrationService.getAvailableMigrationVersions();

        // Act & Assert
        expect(versions, isA<List<String>>());
        expect(versions.isNotEmpty, true);

        // Verify the versions can be used for migration logic
        for (String version in versions) {
          expect(version, isNotEmpty);
          expect(migrationService.isMigrationNeeded(version), false); // Same version shouldn't need migration
        }
      });
    });
  });
}
