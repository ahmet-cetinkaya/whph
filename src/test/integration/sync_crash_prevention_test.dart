import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/database_integrity_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:acore/acore.dart';

/// Integration test for sync crash prevention
///
/// This test verifies that the database integrity validation works correctly
/// and prevents the crashes described in GitHub issue #124.
void main() {
  group('Sync Crash Prevention Integration Test', () {
    late AppDatabase database;
    late DatabaseIntegrityService integrityService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Initialize database for testing - use singleton instance
      database = AppDatabase.instance();

      // Initialize integrity service with real database
      integrityService = DatabaseIntegrityService(database);
    });

    tearDownAll(() async {
      // Database cleanup is handled by the singleton pattern
    });

    test('should validate database integrity without crashing', () async {
      // This is the core test for issue #124 crash prevention
      // If this test completes without throwing, the crash prevention is working

      final report = await integrityService.validateIntegrity();

      // Verify the report was generated successfully
      expect(report, isNotNull);
      expect(report, isA<DatabaseIntegrityReport>());

      // The specific content doesn't matter as much as the fact that it doesn't crash
      print('Database integrity validation completed successfully');
      print('Report: ${report.toString()}');
    });

    test('should handle integrity fixes without crashing', () async {
      // Test the automatic fix functionality

      // This should not throw even if there are issues
      await integrityService.fixCriticalIntegrityIssues();

      // If we reach this point, the fix mechanism worked without crashing
      expect(true, isTrue);
    });

    test('should handle multiple integrity validations without issues', () async {
      // Test repeated validations to ensure stability

      for (int i = 0; i < 3; i++) {
        final report = await integrityService.validateIntegrity();
        expect(report, isNotNull);

        await integrityService.fixCriticalIntegrityIssues();
      }

      // All iterations should complete successfully
      expect(true, isTrue);
    });
  });
}
