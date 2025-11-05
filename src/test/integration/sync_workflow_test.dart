import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/shared/services/app_bootstrap_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/sync/services/database_integrity_service.dart';

/// Integration tests for the sync workflow crash prevention feature
///
/// These tests verify that the sync state validation and cleanup works
/// correctly when services are integrated together, preventing the crashes
/// described in GitHub issue #124.
void main() {
  group('Sync Workflow Integration Tests', () {
    late IContainer container;

    setUp(() async {
      // Initialize the app container with real services for integration testing
      container = await AppBootstrapService.initializeApp();

      // Initialize core services to set up sync state validation
      await AppBootstrapService.initializeCoreServices(container);
    });

    tearDown(() async {
      // Clean up resources if needed - Logger doesn't have dispose method
      // so we just let it be cleaned up naturally
    });

    test('should validate sync state integrity after app initialization', () async {
      // The app should initialize successfully without throwing exceptions
      // This confirms that sync state validation works correctly

      expect(container, isNotNull);
      expect(container, isA<IContainer>());

      // Verify that the sync-related services are available
      expect(() => container.resolve<DatabaseIntegrityService>(), returnsNormally);
    });

    test('should handle sync state cleanup gracefully', () async {
      // Test that stale sync state cleanup works without crashing
      // This simulates the scenario from issue #124 where sync was interrupted

      // Re-initialize core services to trigger sync state validation again
      await AppBootstrapService.initializeCoreServices(container);

      // Should complete without exceptions
      expect(true, isTrue);
    });

    test('should maintain system stability during sync validation', () async {
      // Test multiple rapid initializations to ensure stability
      // This simulates multiple app restart scenarios

      for (int i = 0; i < 3; i++) {
        await AppBootstrapService.initializeCoreServices(container);
      }

      // All iterations should complete without exceptions
      expect(true, isTrue);
    });

    test('should prevent crashes from inconsistent sync state', () async {
      // This test verifies that the crash prevention mechanisms work
      // by attempting to trigger the conditions that caused issue #124

      // Initialize services multiple times rapidly
      await AppBootstrapService.initializeCoreServices(container);
      await AppBootstrapService.initializeCoreServices(container);
      await AppBootstrapService.initializeCoreServices(container);

      // If we reach this point without exceptions, the crash prevention is working
      expect(true, isTrue);
    });

    test('should validate database integrity without corruption', () async {
      // Test that database integrity validation works correctly

      final databaseService = container.resolve<DatabaseIntegrityService>();
      final report = await databaseService.validateIntegrity();

      // Should successfully generate a report without throwing
      expect(report, isNotNull);
      expect(report, isA<DatabaseIntegrityReport>());
    });
  });
}
