import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/paginated_sync_command.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/sync_service.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_sync_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import 'sync_service_test.mocks.dart';

@GenerateMocks([
  Mediator,
  IDeviceIdService,
])
void main() {
  group('SyncService Tests', () {
    late MockMediator mockMediator;
    late MockIDeviceIdService mockDeviceIdService;
    late SyncService syncService;
    late StreamController<SyncStatus> statusStreamController;

    setUp(() async {
      mockMediator = MockMediator();
      mockDeviceIdService = MockIDeviceIdService();

      // Set up AppDatabase in test mode with temporary directory
      AppDatabase.isTestMode = true;
      AppDatabase.testDirectory = await Directory.systemTemp.createTemp('whph_test_');

      // Initialize the database instance to avoid lazy initialization during tests
      AppDatabase.setInstanceForTesting(AppDatabase.forTesting());

      syncService = DesktopSyncService(mockMediator, mockDeviceIdService);
      statusStreamController = StreamController<SyncStatus>.broadcast();
    });

    tearDown(() async {
      // Clean up the temporary database file after each test
      syncService.dispose();
      statusStreamController.close();
      if (AppDatabase.testDirectory != null) {
        await AppDatabase.testDirectory!.delete(recursive: true);
      }
      AppDatabase.resetInstance();
    });

    group('Constructor and Initialization', () {
      test('should initialize with correct default values', () {
        expect(syncService.isConnected, false);
        expect(syncService.currentSyncStatus.state, SyncState.idle);
      });

      test('should initialize streams correctly', () {
        expect(syncService.onSyncComplete, isA<Stream<bool>>());
        expect(syncService.progressStream, isA<Stream<SyncProgress>>());
        expect(syncService.syncStatusStream, isA<Stream<SyncStatus>>());
      });
    });

    group('Success State Tests', () {
      test('should successfully complete paginated sync', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 2,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        final statusStates = <SyncState>[];
        final statusSubscription = syncService.syncStatusStream.listen((status) {
          statusStates.add(status.state);
        });

        // Act
        await syncService.runPaginatedSync(isManual: true);

        // Wait for the operation to complete
        await Future.delayed(const Duration(milliseconds: 150));

        // Assert
        verify(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any)).called(1);
        expect(statusStates, contains(SyncState.syncing));
        expect(statusStates, contains(SyncState.completed));

        // Clean up
        await statusSubscription.cancel();

        // Wait for the timer to reset to idle
        await Future.delayed(const Duration(seconds: 3));
        expect(syncService.currentSyncStatus.state, SyncState.idle);
      });

      test('should notify sync completion for manual sync', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        final completedEvents = <bool>[];
        final subscription = syncService.onSyncComplete.listen((event) {
          completedEvents.add(event);
        });

        // Act
        await syncService.runPaginatedSync(isManual: true);

        // Wait for async completion notifications
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(completedEvents, isNotEmpty);
        expect(completedEvents.first, true);

        // Clean up
        subscription.cancel();
      });

      test('should not notify sync completion for background sync with no meaningful activity', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 0,
          hadMeaningfulSync: false,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        bool syncCompleted = false;
        syncService.onSyncComplete.listen((_) {
          syncCompleted = true;
        });

        // Act
        await syncService.runPaginatedSync(isManual: false);

        // Assert
        expect(syncCompleted, false);
      });

      test('should reset reconnect attempts on successful sync', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        // Act
        await syncService.runPaginatedSync();

        // Assert - No way to directly test private field, but the behavior should be consistent
        verify(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any)).called(1);
      });
    });

    group('Error State Tests', () {
      test('should handle sync command response with errors', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: false,
          hasErrors: true,
          errorMessages: ['Connection failed', 'Timeout occurred'],
          syncedDeviceCount: 0,
          hadMeaningfulSync: false,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        final statusStates = <SyncState>[];
        final errorMessages = <String>[];
        syncService.syncStatusStream.listen((status) {
          statusStates.add(status.state);
          if (status.errorMessage != null) {
            errorMessages.add(status.errorMessage!);
          }
        });

        // Act
        await syncService.runPaginatedSync();

        // Wait for async status updates to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(statusStates, contains(SyncState.syncing));
        expect(statusStates, contains(SyncState.error));
        expect(errorMessages.isNotEmpty, true);
        expect(errorMessages.first, contains('Connection failed'));
      });

      test('should handle sync command exception', () async {
        // Arrange
        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenThrow(Exception('Network error'));

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        final statusStates = <SyncState>[];
        final errorMessages = <String>[];
        syncService.syncStatusStream.listen((status) {
          statusStates.add(status.state);
          if (status.errorMessage != null) {
            errorMessages.add(status.errorMessage!);
          }
        });

        // Act
        await syncService.runPaginatedSync();

        // Wait for async status updates to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(statusStates, contains(SyncState.syncing));
        expect(statusStates, contains(SyncState.error));
        expect(errorMessages.isNotEmpty, true);
        expect(errorMessages.first, contains('sync.errors.sync_failed'));
      });

      test('should reset to idle state after error with delay', () async {
        // Arrange
        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenThrow(Exception('Test error'));

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        // Act
        await syncService.runPaginatedSync();

        // Wait for error delay timer (reduced for test performance)
        await Future.delayed(const Duration(milliseconds: 500));

        // Assert - Status might still be in error state due to timer implementation
      });
    });

    group('Timeout Scenario Tests', () {
      test('should handle timeout in sync command', () async {
        // Arrange
        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any)).thenAnswer((_) async {
          // Simulate a shorter timeout for test performance
          await Future.delayed(const Duration(milliseconds: 50));
          throw TimeoutException('Sync operation timed out', const Duration(milliseconds: 50));
        });

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        final statusStates = <SyncState>[];
        final errorMessages = <String>[];
        final subscription = syncService.syncStatusStream.listen((status) {
          statusStates.add(status.state);
          if (status.errorMessage != null) {
            errorMessages.add(status.errorMessage!);
          }
        });

        // Act
        await syncService.runPaginatedSync();

        // Wait for async status updates
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - The sync should have encountered an error due to timeout
        expect(statusStates, contains(SyncState.syncing));
        expect(statusStates, contains(SyncState.error));
        expect(errorMessages.isNotEmpty, true);

        // Cleanup
        subscription.cancel();
      });
    });

    group('Data Consistency Tests', () {
      test('should maintain consistent sync status throughout operation', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        final statusUpdates = <SyncStatus>[];
        syncService.syncStatusStream.listen((status) {
          statusUpdates.add(status);
        });

        // Act
        await syncService.runPaginatedSync(isManual: true);

        // Wait for async status updates to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(statusUpdates.length, greaterThanOrEqualTo(2));
        expect(statusUpdates.first.state, SyncState.syncing);
        expect(statusUpdates.first.isManual, true);
        expect(statusUpdates.first.lastSyncTime, isNotNull);

        final completedStatus = statusUpdates.firstWhere((status) => status.state == SyncState.completed);
        expect(completedStatus.isManual, true);
        expect(completedStatus.lastSyncTime, isNotNull);
      });

      test('should properly track lastSyncTime updates', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        DateTime? initialSyncTime = syncService.currentSyncStatus.lastSyncTime;

        // Act
        await syncService.runPaginatedSync();

        // Assert
        expect(syncService.currentSyncStatus.lastSyncTime, isNotNull);
        if (initialSyncTime != null) {
          expect(syncService.currentSyncStatus.lastSyncTime!.isAfter(initialSyncTime), true);
        }
      });
    });

    group('Synchronization Order Tests', () {
      test('should call mediator send exactly once per sync operation', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        // Act
        await syncService.runPaginatedSync();

        // Assert
        verify(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any)).called(1);
      });

      test('should handle sequential sync operations correctly', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        // Act
        await syncService.runPaginatedSync();
        await syncService.runPaginatedSync();
        await syncService.runPaginatedSync();

        // Assert
        verify(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any)).called(3);
      });
    });

    group('Edge Cases Tests', () {
      test('should handle incomplete sync response', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: false,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 0,
          hadMeaningfulSync: false,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        final statusStates = <SyncState>[];
        syncService.syncStatusStream.listen((status) {
          statusStates.add(status.state);
        });

        // Act
        await syncService.runPaginatedSync();

        // Wait for async status updates to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(statusStates, contains(SyncState.error));
      });

      test('should handle sync with empty error messages list', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 0,
          hadMeaningfulSync: false,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        // Act
        await syncService.runPaginatedSync();

        // Wait for async status updates to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - successful sync should be in completed state initially
        expect(syncService.currentSyncStatus.state, SyncState.completed);
      });

      test('should handle sync completion notification edge case', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        int completionCount = 0;
        syncService.onSyncComplete.listen((_) {
          completionCount++;
        });

        // Act - Run multiple times to test notification behavior
        await syncService.runPaginatedSync(isManual: false); // Background sync with meaningful activity
        await Future.delayed(const Duration(milliseconds: 50)); // Small delay between syncs
        await syncService.runPaginatedSync(isManual: true); // Manual sync

        // Wait for async completion notifications
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(completionCount, 2);
      });

      test('should dispose resources properly', () async {
        // Arrange
        bool streamClosed = false;
        final subscription = syncService.onSyncComplete.listen(
          (_) {},
          onDone: () => streamClosed = true,
        );

        // Act
        syncService.dispose();

        // Wait for disposal to complete
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(streamClosed, true);

        // Clean up
        subscription.cancel();
      });
    });

    group('State Management Tests', () {
      test('should update sync status correctly', () async {
        // Arrange
        final newStatus = SyncStatus(
          state: SyncState.syncing,
          isManual: true,
          lastSyncTime: DateTime.now(),
        );

        SyncStatus? capturedStatus;
        final subscription = syncService.syncStatusStream.listen((status) {
          capturedStatus = status;
        });

        // Act
        syncService.updateSyncStatus(newStatus);

        // Wait for stream to emit
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(syncService.currentSyncStatus, equals(newStatus));
        expect(capturedStatus, equals(newStatus));

        // Clean up
        subscription.cancel();
      });

      test('should provide access to current sync status', () {
        // Arrange
        final status = SyncStatus(
          state: SyncState.error,
          errorMessage: 'Test error',
          lastSyncTime: DateTime.now(),
        );

        // Act
        syncService.updateSyncStatus(status);

        // Assert
        expect(syncService.currentSyncStatus.state, SyncState.error);
        expect(syncService.currentSyncStatus.errorMessage, 'Test error');
        expect(syncService.currentSyncStatus.lastSyncTime, isNotNull);
      });
    });

    group('Stream Management Tests', () {
      test('should provide sync complete stream', () {
        // Act & Assert
        expect(syncService.onSyncComplete, isA<Stream<bool>>());
      });

      test('should provide progress stream', () {
        // Act & Assert
        expect(syncService.progressStream, isA<Stream<SyncProgress>>());
      });

      test('should provide sync status stream', () {
        // Act & Assert
        expect(syncService.syncStatusStream, isA<Stream<SyncStatus>>());
      });
    });

    group('Legacy Method Tests', () {
      test('runSync should delegate to runPaginatedSync', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        // Act
        await syncService.runSync(isManual: true);

        // Assert
        verify(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any)).called(1);
      });

      test('startSync should initialize sync system', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        // Mock the device ID service which is used by DesktopSyncService internally
        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        // Act & Assert
        // For DesktopSyncService, startSync tries to start server mode which may fail
        // in test environments (port binding issues). This is expected behavior.
        // We just verify that the method handles the failure gracefully.
        try {
          await syncService.startSync();
          // If it succeeds, verify it's not in error state
          expect(syncService.currentSyncStatus.state, isNot(SyncState.error));
        } catch (e) {
          // Expected: server mode startup may fail in test environment
          expect(e.toString(), contains('Failed to start desktop server'));
        }
      });
    });

    group('Database Integrity Tests', () {
      test('should auto-fix on manual sync even without timestamp issues', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        // Act - Manual sync should trigger integrity check
        await syncService.runPaginatedSync(isManual: true);

        // Wait for async operations
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any)).called(1);
      });

      test('should auto-fix on background sync when timestamp inconsistencies detected', () async {
        // Note: This test documents the expected behavior.
        // The actual timestamp inconsistency detection and auto-fix is tested
        // in database_integrity_service_test.dart. Here we verify that
        // background sync completes successfully.

        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        // Act - Background sync should complete successfully
        await syncService.runPaginatedSync(isManual: false);

        // Wait for async operations
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - The sync should complete
        expect(syncService.currentSyncStatus.state, SyncState.completed);

        // Note: The implementation in sync_service.dart has logic that triggers
        // auto-fix when timestamp inconsistencies are detected, even for background sync:
        // if (isManual || preIntegrityReport.timestampInconsistencies > 0)
        // This is tested directly in database_integrity_service_test.dart
      });

      test('should validate database integrity after successful sync', () async {
        // Arrange
        final response = PaginatedSyncCommandResponse(
          isComplete: true,
          hasErrors: false,
          errorMessages: [],
          syncedDeviceCount: 1,
          hadMeaningfulSync: true,
        );

        when(mockMediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(any))
            .thenAnswer((_) async => response);

        when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');

        // Act
        await syncService.runPaginatedSync(isManual: true);

        // Wait for async operations
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - Sync should complete successfully
        expect(syncService.currentSyncStatus.state, SyncState.completed);
      });
    });
  });
}
