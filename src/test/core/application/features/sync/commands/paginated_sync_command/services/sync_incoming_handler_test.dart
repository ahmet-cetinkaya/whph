import 'package:acore/acore.dart' hide IRepository;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_incoming_handler.dart';
import 'package:whph/core/application/features/sync/models/bidirectional_sync_progress.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/models/sync_data.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_progress_tracker.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart'
    as whph_repo;
import 'package:whph/core/domain/features/sync/sync_device.dart';

import 'sync_incoming_handler_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ISyncConfigurationService>(),
  MockSpec<ISyncPaginationService>(),
  MockSpec<ISyncValidationService>(),
])
class MockRepository extends Mock
    implements whph_repo.IRepository<BaseEntity<String>, String> {}

PaginatedSyncData<BaseEntity<String>> emptySyncData(String name) {
  return PaginatedSyncData<BaseEntity<String>>(
    data: SyncData<BaseEntity<String>>(
      createSync: [],
      updateSync: [],
      deleteSync: [],
    ),
    pageIndex: 0,
    pageSize: 50,
    totalPages: 1,
    totalItems: 0,
    isLastPage: true,
    entityType: name,
  );
}

// Config whose getPaginatedSyncData returns EMPTY local data, so the
// bidirectional response takes the "no data to send back" path. This still
// exercises the pageIndex==0 cursor reset that runs before the data fetch.
PaginatedSyncConfig emptyDataConfig(String name) {
  return PaginatedSyncConfig<BaseEntity<String>>(
    name: name,
    repository: MockRepository(),
    getPaginatedSyncData: (_, __, ___, ____) async => emptySyncData(name),
    getPaginatedSyncDataFromDto: (_) => null,
  );
}

void main() {
  group('SyncIncomingHandler Cursor Reset Tests', () {
    late SyncIncomingHandler handler;
    late MockISyncConfigurationService mockConfigService;
    late MockISyncPaginationService mockPaginationService;
    late MockISyncValidationService mockValidationService;

    late SyncDevice testDevice;

    setUp(() {
      mockConfigService = MockISyncConfigurationService();
      mockPaginationService = MockISyncPaginationService();
      mockValidationService = MockISyncValidationService();

      testDevice = SyncDevice(
        id: 'device-1',
        createdDate: DateTime(2026),
        fromIp: '192.168.1.10',
        toIp: '192.168.1.20',
        fromDeviceId: 'from-device',
        toDeviceId: 'to-device',
        name: 'Test Device',
      );

      // NiceMocks return defaults for un-stubbed methods, so validation passes
      // without explicit stubs.

      handler = SyncIncomingHandler(
        configurationService: mockConfigService,
        validationService: mockValidationService,
        paginationService: mockPaginationService,
        progressTracker: SyncProgressTracker(),
      );
    });

    PaginatedSyncDataDto createDto({
      required String entityType,
      required int pageIndex,
    }) {
      return PaginatedSyncDataDto(
        appVersion: '1.0.0',
        syncDevice: testDevice,
        isDebugMode: false,
        entityType: entityType,
        pageIndex: pageIndex,
        pageSize: 50,
        totalPages: 1,
        totalItems: 0,
        isLastPage: true,
      );
    }

    test('resets cursor to -1 when pageIndex is 0 (new session)', () async {
      when(mockConfigService.getConfiguration('AppUsageTimeRecord'))
          .thenReturn(emptyDataConfig('AppUsageTimeRecord'));

      await handler.handleIncomingSync(
        createDto(entityType: 'AppUsageTimeRecord', pageIndex: 0),
        onProgress: (BidirectionalSyncProgress progress) {},
        processDto: (PaginatedSyncDataDto dto) async => 0,
        createResponseDto: (syncDevice, localData, entityType,
            {currentServerPage, totalServerPages, hasMoreServerPages}) async {
          return createDto(entityType: entityType, pageIndex: 0);
        },
      );

      verify(mockPaginationService.setLastSentServerPage(
        'device-1',
        'AppUsageTimeRecord',
        -1,
      )).called(1);
    });

    test('does NOT reset cursor when pageIndex is > 0 (mid-session)', () async {
      when(mockConfigService.getConfiguration('AppUsageTimeRecord'))
          .thenReturn(emptyDataConfig('AppUsageTimeRecord'));

      await handler.handleIncomingSync(
        createDto(entityType: 'AppUsageTimeRecord', pageIndex: 5),
        onProgress: (BidirectionalSyncProgress progress) {},
        processDto: (PaginatedSyncDataDto dto) async => 0,
        createResponseDto: (syncDevice, localData, entityType,
            {currentServerPage, totalServerPages, hasMoreServerPages}) async {
          return createDto(entityType: entityType, pageIndex: 0);
        },
      );

      verifyNever(mockPaginationService.setLastSentServerPage(
        'device-1',
        'AppUsageTimeRecord',
        -1,
      ));
    });

    test('cursor is NOT reset on local data exhaustion (hasMorePages=false)',
        () async {
      // Empty local data → _prepareBidirectionalResponse returns hasMorePages=false.
      // Previously this path reset the cursor to -1 (causing re-fetch loops).
      // After the fix it must NOT reset.
      when(mockConfigService.getConfiguration('AppUsageTimeRecord'))
          .thenReturn(emptyDataConfig('AppUsageTimeRecord'));

      await handler.handleIncomingSync(
        createDto(entityType: 'AppUsageTimeRecord', pageIndex: 1),
        onProgress: (BidirectionalSyncProgress progress) {},
        processDto: (PaginatedSyncDataDto dto) async => 0,
        createResponseDto: (syncDevice, localData, entityType,
            {currentServerPage, totalServerPages, hasMoreServerPages}) async {
          return createDto(entityType: entityType, pageIndex: 0);
        },
      );

      verifyNever(mockPaginationService.setLastSentServerPage(
        'device-1',
        'AppUsageTimeRecord',
        -1,
      ));
    });

    test('cursor reset is isolated per entity type', () async {
      when(mockConfigService.getConfiguration('Task'))
          .thenReturn(emptyDataConfig('Task'));
      when(mockConfigService.getConfiguration('Habit'))
          .thenReturn(emptyDataConfig('Habit'));

      await handler.handleIncomingSync(
        createDto(entityType: 'Task', pageIndex: 0),
        onProgress: (BidirectionalSyncProgress progress) {},
        processDto: (PaginatedSyncDataDto dto) async => 0,
        createResponseDto: (syncDevice, localData, entityType,
            {currentServerPage, totalServerPages, hasMoreServerPages}) async {
          return createDto(entityType: entityType, pageIndex: 0);
        },
      );

      await handler.handleIncomingSync(
        createDto(entityType: 'Habit', pageIndex: 0),
        onProgress: (BidirectionalSyncProgress progress) {},
        processDto: (PaginatedSyncDataDto dto) async => 0,
        createResponseDto: (syncDevice, localData, entityType,
            {currentServerPage, totalServerPages, hasMoreServerPages}) async {
          return createDto(entityType: entityType, pageIndex: 0);
        },
      );

      verify(mockPaginationService.setLastSentServerPage(
        'device-1',
        'Task',
        -1,
      )).called(1);

      verify(mockPaginationService.setLastSentServerPage(
        'device-1',
        'Habit',
        -1,
      )).called(1);
    });
  });
}
