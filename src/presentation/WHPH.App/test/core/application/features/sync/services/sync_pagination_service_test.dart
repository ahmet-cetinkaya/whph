import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/models/sync_data.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/sync_pagination_service/sync_pagination_service.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as whph_repo;

import 'sync_pagination_service_test.mocks.dart';

@GenerateMocks([
  ISyncCommunicationService,
  ISyncConfigurationService,
])
// Custom implementation that avoids mock setup issues completely
class MockPaginatedSyncConfig extends PaginatedSyncConfig<HabitRecord> {
  final Future<PaginatedSyncData<HabitRecord>> Function(DateTime, int, int, String?)? _mockGetPaginatedSyncData;

  MockPaginatedSyncConfig(String name,
      {Future<PaginatedSyncData<HabitRecord>> Function(DateTime, int, int, String?)? mockGetPaginatedSyncData})
      : _mockGetPaginatedSyncData = mockGetPaginatedSyncData,
        super(
          name: name,
          repository: MockRepository(),
          getPaginatedSyncData: mockGetPaginatedSyncData ?? (_, __, ___, ____) async => throw UnimplementedError(),
          getPaginatedSyncDataFromDto: (_) => null,
        );

  @override
  Future<PaginatedSyncData<HabitRecord>> Function(DateTime, int, int, String?) get getPaginatedSyncData =>
      _mockGetPaginatedSyncData ?? super.getPaginatedSyncData;
}

// Use a mock for the repository that implements the whph version of IRepository
class MockRepository extends Mock implements whph_repo.IRepository<HabitRecord, String> {}

void main() {
  group('SyncPaginationService Tests', () {
    late SyncPaginationService service;
    late MockISyncCommunicationService mockCommunicationService;
    late MockISyncConfigurationService mockConfigurationService;
    late MockPaginatedSyncConfig mockSyncConfig;

    setUp(() {
      mockCommunicationService = MockISyncCommunicationService();
      mockConfigurationService = MockISyncConfigurationService();
      // Create a default mock with empty data - individual tests can override this
      mockSyncConfig = MockPaginatedSyncConfig('HabitRecord',
          mockGetPaginatedSyncData: (DateTime lastSync, int pageIndex, int pageSize, String? entityType) async {
        return PaginatedSyncData<HabitRecord>(
          data: SyncData<HabitRecord>(createSync: [], updateSync: [], deleteSync: []),
          pageIndex: pageIndex,
          pageSize: pageSize,
          totalPages: 1,
          totalItems: 0,
          isLastPage: true,
          entityType: 'HabitRecord',
        );
      });

      service = SyncPaginationService(
        communicationService: mockCommunicationService,
        configurationService: mockConfigurationService,
      );

      // Set up default server pagination metadata to prevent infinite loops
      service.updateServerPaginationMetadata('HabitRecord', 1, 0);
    });

    group('syncEntityWithPagination', () {
      late SyncDevice testDevice;
      late DateTime lastSyncDate;

      setUp(() {
        testDevice = SyncDevice(
          id: 'test-device',
          fromIp: '192.168.1.100',
          toIp: '192.168.1.200',
          createdDate: DateTime.now(),
          fromDeviceId: 'from-device',
          toDeviceId: 'to-device',
        );
        lastSyncDate = DateTime(2023, 1, 1);

        when(mockConfigurationService.getAllConfigurations()).thenReturn([mockSyncConfig]);
      });

      testWidgets('should process single page successfully', (tester) async {
        // Arrange
        final habitRecords = List.generate(
            25,
            (index) => HabitRecord(
                  id: 'habit-record-$index',
                  createdDate: DateTime.now(),
                  habitId: 'habit-1',
                  occurredAt: DateTime.now(),
                ));

        final singlePageData = PaginatedSyncData<HabitRecord>(
          data: SyncData<HabitRecord>(
            createSync: habitRecords,
            updateSync: [],
            deleteSync: [],
          ),
          pageIndex: 0,
          pageSize: 50,
          totalPages: 1,
          totalItems: 25,
          isLastPage: true,
          entityType: 'HabitRecord',
        );

        // Create a new mock with the specific function
        mockSyncConfig = MockPaginatedSyncConfig('HabitRecord',
            mockGetPaginatedSyncData: (DateTime lastSync, int pageIndex, int pageSize, String? entityType) async =>
                singlePageData);
        when(mockConfigurationService.getAllConfigurations()).thenReturn([mockSyncConfig]);

        when(mockCommunicationService.sendPaginatedDataToDevice(any, any))
            .thenAnswer((_) async => SyncCommunicationResponse(
                  success: true,
                  isComplete: true,
                ));

        // Set up server pagination metadata to prevent infinite loop
        service.updateServerPaginationMetadata('HabitRecord', 1, 25);

        // Act
        final result = await service.syncEntityWithPagination(
          mockSyncConfig,
          testDevice,
          lastSyncDate,
        );

        // Assert
        expect(result, isTrue);
        verify(mockCommunicationService.sendPaginatedDataToDevice(any, any)).called(1);
      });

      testWidgets('should handle pagination boundary conditions', (tester) async {
        // Test a simple case where local data indicates isLastPage correctly
        final habitRecords = List.generate(
            25,
            (index) => HabitRecord(
                  id: 'habit-record-$index',
                  createdDate: DateTime.now(),
                  habitId: 'habit-1',
                  occurredAt: DateTime.now(),
                ));

        final paginatedData = PaginatedSyncData<HabitRecord>(
          data: SyncData<HabitRecord>(
            createSync: habitRecords,
            updateSync: [],
            deleteSync: [],
          ),
          pageIndex: 0,
          pageSize: 50,
          totalPages: 1,
          totalItems: 25,
          isLastPage: true, // Properly indicates single page
          entityType: 'HabitRecord',
        );

        mockSyncConfig = MockPaginatedSyncConfig('HabitRecord',
            mockGetPaginatedSyncData: (DateTime lastSync, int pageIndex, int pageSize, String? entityType) async =>
                paginatedData);
        when(mockConfigurationService.getAllConfigurations()).thenReturn([mockSyncConfig]);

        when(mockCommunicationService.sendPaginatedDataToDevice(any, any))
            .thenAnswer((_) async => SyncCommunicationResponse(
                  success: true,
                  isComplete: true,
                ));

        // Act
        final result = await service.syncEntityWithPagination(
          mockSyncConfig,
          testDevice,
          lastSyncDate,
        );

        // Assert
        expect(result, isTrue);
        verify(mockCommunicationService.sendPaginatedDataToDevice(any, any)).called(1);
      });

      testWidgets('should stop pagination when server indicates completion (isComplete: true)', (tester) async {
        // Arrange
        final singlePageData = PaginatedSyncData<HabitRecord>(
          data: SyncData<HabitRecord>(
            createSync: [],
            updateSync: [],
            deleteSync: [],
          ),
          pageIndex: 0,
          pageSize: 50,
          totalPages: 1,
          totalItems: 0,
          isLastPage: true,
          entityType: 'HabitRecord',
        );

        // Create a new mock with single page data
        mockSyncConfig = MockPaginatedSyncConfig('HabitRecord',
            mockGetPaginatedSyncData: (DateTime lastSync, int pageIndex, int pageSize, String? entityType) async =>
                singlePageData);
        when(mockConfigurationService.getAllConfigurations()).thenReturn([mockSyncConfig]);

        when(mockCommunicationService.sendPaginatedDataToDevice(any, any))
            .thenAnswer((_) async => SyncCommunicationResponse(
                  success: true,
                  isComplete: true, // Server indicates completion immediately
                ));

        // Act
        final result = await service.syncEntityWithPagination(
          mockSyncConfig,
          testDevice,
          lastSyncDate,
        );

        // Assert
        expect(result, isTrue);

        // Should only make 1 request since server indicates completion
        verify(mockCommunicationService.sendPaginatedDataToDevice(any, any)).called(1);
      });

      testWidgets('should handle communication failure', (tester) async {
        // Arrange
        final pageData = PaginatedSyncData<HabitRecord>(
          data: SyncData<HabitRecord>(
            createSync: [],
            updateSync: [],
            deleteSync: [],
          ),
          pageIndex: 0,
          pageSize: 50,
          totalPages: 1,
          totalItems: 0,
          isLastPage: true,
          entityType: 'HabitRecord',
        );

        mockSyncConfig = MockPaginatedSyncConfig('HabitRecord',
            mockGetPaginatedSyncData: (DateTime lastSync, int pageIndex, int pageSize, String? entityType) async =>
                pageData);
        when(mockConfigurationService.getAllConfigurations()).thenReturn([mockSyncConfig]);

        when(mockCommunicationService.sendPaginatedDataToDevice(any, any))
            .thenAnswer((_) async => SyncCommunicationResponse(
                  success: false, // Communication failure
                  isComplete: false,
                  error: 'Network error',
                ));

        // Act
        final result = await service.syncEntityWithPagination(
          mockSyncConfig,
          testDevice,
          lastSyncDate,
        );

        // Assert
        expect(result, isFalse); // Should return false due to communication failure
        verify(mockCommunicationService.sendPaginatedDataToDevice(any, any)).called(1);
      });

      testWidgets('should handle empty target IP', (tester) async {
        // Arrange
        final invalidDevice = SyncDevice(
          id: 'test-device',
          fromIp: '', // Empty IP
          toIp: '', // Empty IP
          createdDate: DateTime.now(),
          fromDeviceId: 'from-device',
          toDeviceId: 'to-device',
        );

        // Act
        final result = await service.syncEntityWithPagination(
          mockSyncConfig,
          invalidDevice,
          lastSyncDate,
        );

        // Assert
        expect(result, isFalse);
        verifyNever(mockCommunicationService.sendPaginatedDataToDevice(any, any));
      });

      testWidgets('should store server response data when isComplete is false', (tester) async {
        // Arrange
        final pageData = PaginatedSyncData<HabitRecord>(
          data: SyncData<HabitRecord>(
            createSync: [],
            updateSync: [],
            deleteSync: [],
          ),
          pageIndex: 0,
          pageSize: 50,
          totalPages: 1,
          totalItems: 0,
          isLastPage: true,
          entityType: 'HabitRecord',
        );

        mockSyncConfig = MockPaginatedSyncConfig('HabitRecord',
            mockGetPaginatedSyncData: (DateTime lastSync, int pageIndex, int pageSize, String? entityType) async =>
                pageData);
        when(mockConfigurationService.getAllConfigurations()).thenReturn([mockSyncConfig]);

        final serverResponseData = PaginatedSyncDataDto(
          appVersion: '1.0.0',
          syncDevice: testDevice,
          isDebugMode: false,
          entityType: 'HabitRecord',
          pageIndex: 0,
          pageSize: 50,
          totalPages: 2,
          totalItems: 100,
          isLastPage: false,
        );

        when(mockCommunicationService.sendPaginatedDataToDevice(any, any))
            .thenAnswer((_) async => SyncCommunicationResponse(
                  success: true,
                  isComplete: false,
                  responseData: serverResponseData,
                ));

        // Act
        await service.syncEntityWithPagination(
          mockSyncConfig,
          testDevice,
          lastSyncDate,
        );

        // Assert
        final pendingData = service.getPendingResponseData();
        expect(pendingData, isNotEmpty);
        expect(pendingData.containsKey('HabitRecord'), isTrue);
        expect(pendingData['HabitRecord']!.entityType, equals('HabitRecord'));
      });
    });

    group('Progress Management', () {
      testWidgets('should update progress correctly', (tester) async {
        // Arrange
        bool progressReceived = false;
        SyncProgress? receivedProgress;

        service.progressStream.listen((progress) {
          progressReceived = true;
          receivedProgress = progress;
        });

        // Act
        service.updateProgress(
          currentEntity: 'TestEntity',
          currentPage: 2,
          totalPages: 5,
          progressPercentage: 60.0,
          entitiesCompleted: 1,
          totalEntities: 3,
          operation: 'syncing',
        );

        await tester.pump(); // Allow stream to emit

        // Assert
        expect(progressReceived, isTrue);
        expect(receivedProgress!.currentEntity, equals('TestEntity'));
        expect(receivedProgress!.currentPage, equals(2));
        expect(receivedProgress!.totalPages, equals(5));
        expect(receivedProgress!.progressPercentage, equals(60.0));
        expect(receivedProgress!.operation, equals('syncing'));
      });

      testWidgets('should clamp progress percentage between 0 and 100', (tester) async {
        // Arrange
        SyncProgress? receivedProgress;
        service.progressStream.listen((progress) {
          receivedProgress = progress;
        });

        // Act
        service.updateProgress(
          currentEntity: 'TestEntity',
          currentPage: 0,
          totalPages: 1,
          progressPercentage: 150.0, // Over 100%
          entitiesCompleted: 0,
          totalEntities: 1,
          operation: 'syncing',
        );

        await tester.pump();

        // Assert
        expect(receivedProgress!.progressPercentage, equals(100.0));
      });

      testWidgets('should reset progress correctly', (tester) async {
        // Arrange
        service.updateProgress(
          currentEntity: 'TestEntity',
          currentPage: 1,
          totalPages: 2,
          progressPercentage: 50.0,
          entitiesCompleted: 0,
          totalEntities: 1,
          operation: 'syncing',
        );

        // Act
        service.resetProgress();

        // Assert
        expect(service.getCurrentProgress('TestEntity'), isNull);
        expect(service.isSyncInProgress, isFalse);
        expect(service.activeEntityTypes, isEmpty);
      });

      testWidgets('should calculate overall progress correctly', (tester) async {
        // Arrange
        final mockConfig1 = MockPaginatedSyncConfig('Entity1');
        final mockConfig2 = MockPaginatedSyncConfig('Entity2');
        final mockConfig3 = MockPaginatedSyncConfig('Entity3');

        when(mockConfigurationService.getAllConfigurations()).thenReturn([
          mockConfig1,
          mockConfig2,
          mockConfig3,
        ]);

        service.updateProgress(
          currentEntity: 'Entity1',
          currentPage: 1,
          totalPages: 2,
          progressPercentage: 100.0, // Completed
          entitiesCompleted: 1,
          totalEntities: 3,
          operation: 'completed',
        );

        service.updateProgress(
          currentEntity: 'Entity2',
          currentPage: 1,
          totalPages: 2,
          progressPercentage: 50.0, // Half done
          entitiesCompleted: 1,
          totalEntities: 3,
          operation: 'syncing',
        );

        // Act
        final overallProgress = service.calculateOverallProgress();

        // Assert
        // 1 completed entity + 0.5 partial entity / 3 total entities * 100 = 50%
        expect(overallProgress, closeTo(50.0, 0.1));
      });
    });

    group('Server Pagination Metadata', () {
      testWidgets('should update and retrieve server pagination metadata', (tester) async {
        // Act
        service.updateServerPaginationMetadata('TestEntity', 5, 250);

        // Assert
        final metadata = service.getServerPaginationMetadata('TestEntity');
        expect(metadata['totalPages'], equals(5));
        expect(metadata['totalItems'], equals(250));
      });

      testWidgets('should return empty metadata for unknown entity', (tester) async {
        // Act
        final metadata = service.getServerPaginationMetadata('UnknownEntity');

        // Assert
        expect(metadata['totalPages'], equals(0));
        expect(metadata['totalItems'], equals(0));
      });
    });

    group('Pending Response Data Management', () {
      testWidgets('should manage pending response data correctly', (tester) async {
        // Arrange
        final responseDto = PaginatedSyncDataDto(
          appVersion: '1.0.0',
          syncDevice: SyncDevice(
            id: 'test-device',
            fromIp: '192.168.1.100',
            toIp: '192.168.1.200',
            createdDate: DateTime.now(),
            fromDeviceId: 'from-device',
            toDeviceId: 'to-device',
          ),
          isDebugMode: false,
          entityType: 'TestEntity',
          pageIndex: 0,
          pageSize: 50,
          totalPages: 1,
          totalItems: 25,
          isLastPage: true,
        );

        // Simulate storing response data (this would normally happen during sync)
        service.getPendingResponseData(); // Initialize internal map

        final pageData = PaginatedSyncData<HabitRecord>(
          data: SyncData<HabitRecord>(createSync: [], updateSync: [], deleteSync: []),
          pageIndex: 0,
          pageSize: 50,
          totalPages: 1,
          totalItems: 0,
          isLastPage: true,
          entityType: 'TestEntity',
        );

        mockSyncConfig = MockPaginatedSyncConfig('TestEntity',
            mockGetPaginatedSyncData: (DateTime lastSync, int pageIndex, int pageSize, String? entityType) async =>
                pageData);
        when(mockConfigurationService.getAllConfigurations()).thenReturn([mockSyncConfig]);

        when(mockCommunicationService.sendPaginatedDataToDevice(any, any))
            .thenAnswer((_) async => SyncCommunicationResponse(
                  success: true,
                  isComplete: false,
                  responseData: responseDto,
                ));

        final testDevice = SyncDevice(
          id: 'test-device',
          fromIp: '192.168.1.100',
          toIp: '192.168.1.200',
          createdDate: DateTime.now(),
          fromDeviceId: 'from-device',
          toDeviceId: 'to-device',
        );

        // Act
        await service.syncEntityWithPagination(
          mockSyncConfig,
          testDevice,
          DateTime.now(),
        );

        final pendingData = service.getPendingResponseData();

        // Assert
        expect(pendingData, isNotEmpty);
        expect(pendingData.containsKey('TestEntity'), isTrue);

        // Act - Clear pending data
        service.clearPendingResponseData();
        final clearedData = service.getPendingResponseData();

        // Assert
        expect(clearedData, isEmpty);
      });
    });

    group('Sync Cancellation', () {
      testWidgets('should cancel sync operations', (tester) async {
        // Arrange
        bool progressReceived = false;
        SyncProgress? receivedProgress;

        service.progressStream.listen((progress) {
          progressReceived = true;
          receivedProgress = progress;
        });

        // Act
        await service.cancelSync();
        await tester.pump(); // Allow stream to emit

        // Assert
        expect(progressReceived, isTrue);
        expect(receivedProgress!.operation, equals('cancelled'));
        expect(service.activeEntityTypes, isEmpty);
      });

      testWidgets('should return false when sync is cancelled', (tester) async {
        // Arrange
        final pageData = PaginatedSyncData<HabitRecord>(
          data: SyncData<HabitRecord>(createSync: [], updateSync: [], deleteSync: []),
          pageIndex: 0,
          pageSize: 50,
          totalPages: 1,
          totalItems: 0,
          isLastPage: true,
          entityType: 'HabitRecord',
        );

        mockSyncConfig = MockPaginatedSyncConfig('HabitRecord',
            mockGetPaginatedSyncData: (DateTime lastSync, int pageIndex, int pageSize, String? entityType) async =>
                pageData);
        when(mockConfigurationService.getAllConfigurations()).thenReturn([mockSyncConfig]);

        final testDevice = SyncDevice(
          id: 'test-device',
          fromIp: '192.168.1.100',
          toIp: '192.168.1.200',
          createdDate: DateTime.now(),
          fromDeviceId: 'from-device',
          toDeviceId: 'to-device',
        );

        // Act - Cancel before sync
        await service.cancelSync();

        final result = await service.syncEntityWithPagination(
          mockSyncConfig,
          testDevice,
          DateTime.now(),
        );

        // Assert
        expect(result, isFalse);
        verifyNever(mockCommunicationService.sendPaginatedDataToDevice(any, any));
      });
    });
  });
}
