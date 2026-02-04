import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/settings/services/import_data_migration_service.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';

void main() {
  group('ImportDataMigrationService Verification', () {
    late ImportDataMigrationService migrationService;

    setUp(() {
      migrationService = ImportDataMigrationService();
    });

    group('isMigrationNeeded (Real Scenarios)', () {
      test('should return TRUE for version 0.6.9 (Has migration to 0.6.10)', () {
        expect(migrationService.isMigrationNeeded('0.6.9'), true);
      });

      test('should return TRUE for version 0.14.1 (Has migration to 0.15.0)', () {
        expect(migrationService.isMigrationNeeded('0.14.1'), true);
      });

      test('should return TRUE for version 0.15.0 (Has migration to 0.16.0)', () {
        expect(migrationService.isMigrationNeeded('0.15.0'), true);
      });

      test('should return TRUE for version 0.16.0 (Has migration to 0.20.0)', () {
        // This is the new migration we are about to add
        expect(migrationService.isMigrationNeeded('0.16.0'), true);
      });

      test('should return FALSE for version 0.20.3 (No migration to current)', () {
        // As defined in the fix, this should return false so ImportDataCommand can just accept it
        expect(migrationService.isMigrationNeeded('0.20.3'), false);
      });

      test('should return FALSE for current version', () {
        expect(migrationService.isMigrationNeeded(AppInfo.version), false);
      });
    });

    group('migrateData (Real Transformations)', () {
      test('should correctly migrate 0.6.9 -> 0.6.10 (Add usageDate)', () async {
        final inputData = {
          'version': '0.6.9',
          'appUsageTimeRecords': <Map<String, dynamic>>[
            {'id': '1', 'createdDate': '2023-01-01T10:00:00Z'}, // Missing usageDate
            {
              'id': '2',
              'createdDate': '2023-01-02T10:00:00Z',
              'usageDate': '2023-01-02T12:00:00Z'
            } // Existing usageDate
          ]
        };

        final result = await migrationService.migrateData(inputData, '0.6.9');

        expect(result['appInfo']['version'], AppInfo.version);

        final records = result['appUsageTimeRecords'] as List;
        // Record 1: usageDate should be copied from createdDate
        expect(records[0]['usageDate'], '2023-01-01T10:00:00Z');
        // Record 2: usageDate should remain unchanged
        expect(records[1]['usageDate'], '2023-01-02T12:00:00Z');
      });

      test('should correctly migrate 0.14.1 -> 0.15.0 (date -> occurredAt)', () async {
        final inputData = {
          'version': '0.14.1',
          'habitRecords': <Map<String, dynamic>>[
            {'id': '1', 'date': '2023-01-01T10:00:00Z'}, // Old field
            {'id': '2', 'occurredAt': '2023-01-02T10:00:00Z'} // New field already exists
          ]
        };

        final result = await migrationService.migrateData(inputData, '0.14.1');

        expect(result['appInfo']['version'], AppInfo.version);

        final records = result['habitRecords'] as List;
        // Record 1: occurredAt should be set from date, and date removed
        expect(records[0]['occurredAt'], '2023-01-01T10:00:00Z');
        expect(records[0].containsKey('date'), false);

        // Record 2: occurredAt should remain
        expect(records[1]['occurredAt'], '2023-01-02T10:00:00Z');
      });

      test('should correctly migrate 0.16.0 -> 0.20.0 (Backfill missing schema fields)', () async {
        final inputData = {
          'version': '0.16.0',
          'habitRecords': <Map<String, dynamic>>[
            {'id': '1'} // Missing status
          ],
          'tasks': <Map<String, dynamic>>[
            {'id': '1'} // Missing recurrenceConfiguration
          ],
          'tags': <Map<String, dynamic>>[
            {'id': '1'} // Missing type
          ],
          'taskTags': <Map<String, dynamic>>[
            {'id': '1'} // Missing tagOrder
          ]
        };

        final result = await migrationService.migrateData(inputData, '0.16.0');

        expect(result['appInfo']['version'], AppInfo.version);

        // Verify HabitRecord status backfill
        final habitRecords = result['habitRecords'] as List;
        expect(habitRecords[0]['status'], 0); // Default status

        // Verify Task recurrenceConfiguration backfill
        final tasks = result['tasks'] as List;
        expect(tasks[0].containsKey('recurrenceConfiguration'), true);
        expect(tasks[0]['recurrenceConfiguration'], null); // Default null

        // Verify Task reminder offsets backfill
        expect(tasks[0].containsKey('plannedDateReminderCustomOffset'), true);
        expect(tasks[0]['plannedDateReminderCustomOffset'], null);
        expect(tasks[0].containsKey('deadlineDateReminderCustomOffset'), true);
        expect(tasks[0]['deadlineDateReminderCustomOffset'], null);

        // Verify Tag type backfill
        final tags = result['tags'] as List;
        expect(tags[0]['type'], 0); // Default type (label)

        // Verify tagOrder backfill
        final taskTags = result['taskTags'] as List;
        expect(taskTags[0]['tagOrder'], 0); // Default order
      });
    });
  });
}
