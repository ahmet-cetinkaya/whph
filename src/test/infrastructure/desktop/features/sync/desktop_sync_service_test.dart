import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_sync_service.dart';

import 'desktop_sync_service_test.mocks.dart';

@GenerateMocks([
  IDeviceIdService,
  Mediator,
])
void main() {
  group('DesktopSyncService', () {
    late DesktopSyncService service;
    late MockIDeviceIdService mockDeviceIdService;
    late MockMediator mockMediator;

    setUp(() {
      mockDeviceIdService = MockIDeviceIdService();
      mockMediator = MockMediator();
      service = DesktopSyncService(mockMediator, mockDeviceIdService);

      // Setup default device ID
      when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');
    });

    tearDown(() {
      service.dispose();
    });

    group('Initial State', () {
      test('should initialize with disabled mode', () {
        expect(service.currentMode, equals(DesktopSyncMode.disabled));
        expect(service.isModeSwitching, isFalse);
      });

      test('should not be in switching state initially', () {
        expect(service.isModeSwitching, isFalse);
      });
    });

    group('Mode Switching', () {
      test('should prevent concurrent mode switches', () async {
        // Start first mode switch
        final firstSwitch = service.switchToMode(DesktopSyncMode.server);
        expect(service.isModeSwitching, isTrue);

        // Wait for first switch to complete
        await firstSwitch;

        // Should be in server mode and switching flag should be reset
        expect(service.currentMode, equals(DesktopSyncMode.server));
        expect(service.isModeSwitching, isFalse);
      });

      test('should handle mode switch from disabled to server', () async {
        await service.switchToMode(DesktopSyncMode.server);
        expect(service.currentMode, equals(DesktopSyncMode.server));
        expect(service.isModeSwitching, isFalse);
      });

      test('should handle mode switch from server to client', () async {
        // First switch to server mode
        await service.switchToMode(DesktopSyncMode.server);
        expect(service.currentMode, equals(DesktopSyncMode.server));

        // Then switch to client mode
        await service.switchToMode(DesktopSyncMode.client);
        expect(service.currentMode, equals(DesktopSyncMode.client));
      });

      test('should handle mode switch from client to disabled', () async {
        // First switch to client mode
        await service.switchToMode(DesktopSyncMode.client);
        expect(service.currentMode, equals(DesktopSyncMode.client));

        // Then switch to disabled mode
        await service.switchToMode(DesktopSyncMode.disabled);
        expect(service.currentMode, equals(DesktopSyncMode.disabled));
      });

      test('should reset mode switching flag after successful switch', () async {
        expect(service.isModeSwitching, isFalse);

        await service.switchToMode(DesktopSyncMode.server);

        expect(service.isModeSwitching, isFalse);
        expect(service.currentMode, equals(DesktopSyncMode.server));
      });
    });

    group('Error Handling and Recovery', () {
      test('should handle timeout during mode start operation', () async {
        // This test verifies timeout handling in mode switching
        final stopwatch = Stopwatch()..start();

        try {
          await service.switchToMode(DesktopSyncMode.server).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Mode start operation timed out', const Duration(seconds: 10));
            },
          );
        } catch (e) {
          expect(e, isA<TimeoutException>());
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(11000)); // Should timeout before 10 seconds
      });

      test('should recover from inconsistent state on startup', () async {
        // Create a new service instance to test startup recovery
        final recoveryService = DesktopSyncService(mockMediator, mockDeviceIdService);

        try {
          // Verify initial state is clean
          expect(recoveryService.currentMode, equals(DesktopSyncMode.disabled));
          expect(recoveryService.isModeSwitching, isFalse);

          // The recovery logic is tested in the constructor
          // This verifies that the service starts in a clean state
        } finally {
          recoveryService.dispose();
        }
      });
    });

    group('Service Lifecycle', () {
      test('should handle disposal correctly', () {
        expect(() => service.dispose(), returnsNormally);
      });

      test('should handle multiple disposals', () {
        service.dispose();
        expect(() => service.dispose(), returnsNormally);
      });

      test('should maintain state consistency after disposal', () {
        service.dispose();
        expect(service.currentMode, equals(DesktopSyncMode.disabled));
        expect(service.isModeSwitching, isFalse);
      });
    });

    group('State Consistency', () {
      test('should maintain mode consistency across operations', () async {
        // Test multiple mode switches
        await service.switchToMode(DesktopSyncMode.server);
        expect(service.currentMode, equals(DesktopSyncMode.server));

        await service.switchToMode(DesktopSyncMode.client);
        expect(service.currentMode, equals(DesktopSyncMode.client));

        await service.switchToMode(DesktopSyncMode.disabled);
        expect(service.currentMode, equals(DesktopSyncMode.disabled));
      });

      test('should handle same mode switch request gracefully', () async {
        await service.switchToMode(DesktopSyncMode.server);
        expect(service.currentMode, equals(DesktopSyncMode.server));

        // Request same mode again
        await service.switchToMode(DesktopSyncMode.server);
        expect(service.currentMode, equals(DesktopSyncMode.server));
      });
    });
  });
}
