import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:application/features/sync/services/sync_device_processing_handler.dart';
import 'package:application/shared/services/abstraction/i_repository.dart';
import 'package:domain/features/sync/sync_device.dart';

import 'sync_device_processing_handler_test.mocks.dart';

@GenerateMocks([IRepository])
void main() {
  group('SyncDeviceProcessingHandler Tests', () {
    late MockIRepository<SyncDevice, String> mockRepository;
    late SyncDeviceProcessingHandler handler;
    late int yieldCallCount;

    setUp(() {
      mockRepository = MockIRepository<SyncDevice, String>();
      handler = SyncDeviceProcessingHandler(
        onYieldToUI: () async {
          yieldCallCount++;
        },
      );
      yieldCallCount = 0;
    });

    group('includeDeleted flag usage', () {
      test('should call getById with includeDeleted: true in _handleUpdate', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        final existingDevice = SyncDevice(
          id: 'device-1',
          createdDate: now.subtract(const Duration(days: 1)),
          modifiedDate: now.subtract(const Duration(days: 1)),
          deletedDate: now.subtract(const Duration(hours: 1)), // Soft-deleted
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Old Name',
          lastSyncDate: null,
        );

        // Mock to return null without includeDeleted, but the device with includeDeleted
        when(mockRepository.getById('device-1', includeDeleted: true)).thenAnswer((_) async => existingDevice);
        when(mockRepository.getById('device-1', includeDeleted: false)).thenAnswer((_) async => null);
        when(mockRepository.update(any)).thenAnswer((_) async {});
        when(mockRepository.getAll()).thenAnswer((_) async => []);

        // Act
        await handler.processSyncDeviceItem(syncDevice, mockRepository, 'update');

        // Assert - Should have called getById with includeDeleted: true
        // Called twice: once in _handleUpdate, once in _verifyUpdate
        verify(mockRepository.getById('device-1', includeDeleted: true)).called(2);
        verifyNever(mockRepository.getById('device-1', includeDeleted: false));
      });

      test('should revive soft-deleted device when updating with deletedDate null', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null, // Not deleted on remote
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        final existingDevice = SyncDevice(
          id: 'device-1',
          createdDate: now.subtract(const Duration(days: 1)),
          modifiedDate: now.subtract(const Duration(days: 1)),
          deletedDate: now.subtract(const Duration(hours: 1)), // Soft-deleted locally
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Old Name',
          lastSyncDate: now, // Set to match to avoid verification retry
        );

        when(mockRepository.getById('device-1', includeDeleted: true)).thenAnswer((_) async => existingDevice);
        when(mockRepository.update(any)).thenAnswer((_) async {});
        when(mockRepository.getAll()).thenAnswer((_) async => []);

        // Act
        final result = await handler.processSyncDeviceItem(syncDevice, mockRepository, 'update');

        // Assert - Should have updated (revived) the device
        expect(result, equals(1));
        verify(mockRepository.update(argThat(
          isA<SyncDevice>()
              .having((d) => d.id, 'id', 'device-1')
              .having((d) => d.deletedDate, 'deletedDate', null), // Revived (deletedDate is now null)
        )));
      });

      test('should call getById with includeDeleted: true in _handleCreate', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        when(mockRepository.getById('device-1', includeDeleted: true)).thenAnswer((_) async => null);
        when(mockRepository.getAll()).thenAnswer((_) async => []);
        when(mockRepository.add(any)).thenAnswer((_) async {});

        // Act
        await handler.processSyncDeviceItem(syncDevice, mockRepository, 'create');

        // Assert - Should have called getById with includeDeleted: true at least once
        verify(mockRepository.getById('device-1', includeDeleted: true)).called(1);
      });

      test('should update existing soft-deleted device instead of creating duplicate', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        final existingDeletedDevice = SyncDevice(
          id: 'device-1',
          createdDate: now.subtract(const Duration(days: 1)),
          modifiedDate: now.subtract(const Duration(days: 1)),
          deletedDate: now.subtract(const Duration(hours: 1)),
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Old Name',
          lastSyncDate: now, // Set to match to avoid verification retry
        );

        when(mockRepository.getById('device-1', includeDeleted: true)).thenAnswer((_) async => existingDeletedDevice);
        when(mockRepository.update(any)).thenAnswer((_) async {});
        when(mockRepository.getAll()).thenAnswer((_) async => []);

        // Act
        final result = await handler.processSyncDeviceItem(syncDevice, mockRepository, 'create');

        // Assert - Should update existing device, not add a new one
        expect(result, equals(1));
        verify(mockRepository.update(any)).called(1);
        verifyNever(mockRepository.add(any));
      });

      test('should call getById with includeDeleted: true in _handleDelete', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: now,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        final existingDevice = SyncDevice(
          id: 'device-1',
          createdDate: now.subtract(const Duration(days: 1)),
          modifiedDate: now.subtract(const Duration(days: 1)),
          deletedDate: now.subtract(const Duration(hours: 1)),
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        when(mockRepository.getById('device-1', includeDeleted: true)).thenAnswer((_) async => existingDevice);
        when(mockRepository.delete(any)).thenAnswer((_) async {});

        // Act
        await handler.processSyncDeviceItem(syncDevice, mockRepository, 'delete');

        // Assert
        verify(mockRepository.getById('device-1', includeDeleted: true)).called(1);
      });

      test('should call getById with includeDeleted: true in _verifyUpdate', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        final existingDevice = SyncDevice(
          id: 'device-1',
          createdDate: now.subtract(const Duration(days: 1)),
          modifiedDate: now.subtract(const Duration(days: 1)),
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        when(mockRepository.getById('device-1', includeDeleted: true)).thenAnswer((_) async => existingDevice);
        when(mockRepository.update(any)).thenAnswer((_) async {});
        when(mockRepository.getAll()).thenAnswer((_) async => []);

        // Act
        await handler.processSyncDeviceItem(syncDevice, mockRepository, 'update');

        // Assert - _verifyUpdate should also use includeDeleted: true
        // getById is called twice: once in _handleUpdate, once in _verifyUpdate
        verify(mockRepository.getById('device-1', includeDeleted: true)).called(2);
      });

      test('should call getById with includeDeleted: true in _verifyCreate', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        when(mockRepository.getById('device-1', includeDeleted: true)).thenAnswer((_) async => null);
        when(mockRepository.getAll()).thenAnswer((_) async => []);
        when(mockRepository.add(any)).thenAnswer((_) async {});

        // Act
        await handler.processSyncDeviceItem(syncDevice, mockRepository, 'create');

        // Assert - _verifyCreate should use includeDeleted: true at least once
        verify(mockRepository.getById('device-1', includeDeleted: true)).called(1);
      });
    });

    group('CRUD Operations', () {
      test('should create new device when none exists', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-new',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'New Device',
          lastSyncDate: now,
        );

        when(mockRepository.getById('device-new', includeDeleted: true)).thenAnswer((_) async => null);
        when(mockRepository.getAll()).thenAnswer((_) async => []);
        when(mockRepository.add(any)).thenAnswer((_) async {});

        // Act
        final result = await handler.processSyncDeviceItem(syncDevice, mockRepository, 'create');

        // Assert
        expect(result, equals(1));
        verify(mockRepository.add(syncDevice)).called(1);
        verifyNever(mockRepository.update(any));
      });

      test('should update existing device during update operation', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Updated Device',
          lastSyncDate: now,
        );

        final existingDevice = SyncDevice(
          id: 'device-1',
          createdDate: now.subtract(const Duration(days: 1)),
          modifiedDate: now.subtract(const Duration(days: 1)),
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Old Device',
          lastSyncDate: now, // Set to match to avoid verification retry
        );

        when(mockRepository.getById('device-1', includeDeleted: true)).thenAnswer((_) async => existingDevice);
        when(mockRepository.update(any)).thenAnswer((_) async {});

        // Act
        final result = await handler.processSyncDeviceItem(syncDevice, mockRepository, 'update');

        // Assert
        expect(result, equals(1));
        verify(mockRepository.update(syncDevice)).called(1);
        verifyNever(mockRepository.add(any));
      });

      test('should create device during update operation if device does not exist', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'New Device',
          lastSyncDate: now,
        );

        when(mockRepository.getById('device-1', includeDeleted: true)).thenAnswer((_) async => null);
        when(mockRepository.add(any)).thenAnswer((_) async {});

        // Act
        final result = await handler.processSyncDeviceItem(syncDevice, mockRepository, 'update');

        // Assert
        expect(result, equals(1));
        verify(mockRepository.add(syncDevice)).called(1);
        verifyNever(mockRepository.update(any));
      });

      test('should handle unknown operation type gracefully', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        // Act
        final result = await handler.processSyncDeviceItem(syncDevice, mockRepository, 'unknown');

        // Assert
        expect(result, equals(0));
        verifyNever(mockRepository.add(any));
        verifyNever(mockRepository.update(any));
        verifyNever(mockRepository.delete(any));
      });
    });

    group('Yield to UI', () {
      test('should yield to UI during create operation', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final syncDevice = SyncDevice(
          id: 'device-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          fromIp: '192.168.1.1',
          toIp: '192.168.1.2',
          fromDeviceId: 'from-dev',
          toDeviceId: 'to-dev',
          name: 'Test Device',
          lastSyncDate: now,
        );

        when(mockRepository.getById('device-1', includeDeleted: true)).thenAnswer((_) async => null);
        when(mockRepository.getAll()).thenAnswer((_) async => []);
        when(mockRepository.add(any)).thenAnswer((_) async {});

        yieldCallCount = 0;

        // Act
        await handler.processSyncDeviceItem(syncDevice, mockRepository, 'create');

        // Assert - Should have yielded at least once
        expect(yieldCallCount, greaterThan(0));
      });
    });
  });
}
