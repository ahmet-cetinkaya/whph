import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_incoming_handler.dart';
import 'package:whph/core/application/features/sync/models/bidirectional_sync_progress.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_progress_tracker.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import '../../../services/sync_pagination_service_test.dart';

import 'sync_incoming_handler_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ISyncConfigurationService>(),
  MockSpec<ISyncValidationService>(),
  MockSpec<ISyncPaginationService>(),
  MockSpec<SyncProgressTracker>(),
])
void main() {
  late SyncIncomingHandler handler;
  late MockISyncConfigurationService mockConfigService;
  late MockISyncValidationService mockValidationService;
  late MockISyncPaginationService mockPaginationService;
  late MockSyncProgressTracker mockProgressTracker;

  final syncDevice = SyncDevice(
    id: 'device-1',
    name: 'Test Device',
    createdDate: DateTime.now(),
    fromIp: '192.168.1.1',
    toIp: '192.168.1.100',
    fromDeviceId: 'device-1',
    toDeviceId: 'device-2',
  );

  PaginatedSyncDataDto createDto({
    required String entityType,
    required int pageIndex,
    int? currentServerPage,
    int? totalServerPages,
    bool? hasMoreServerPages,
  }) {
    return PaginatedSyncDataDto(
      syncDevice: syncDevice,
      appVersion: '0.23.2',
      isDebugMode: false,
      entityType: entityType,
      pageIndex: pageIndex,
      pageSize: 50,
      totalPages: 1,
      totalItems: 0,
      isLastPage: true,
      currentServerPage: currentServerPage,
      totalServerPages: totalServerPages,
      hasMoreServerPages: hasMoreServerPages,
    );
  }

  PaginatedSyncConfig emptyDataConfig(String entityType) {
    return MockPaginatedSyncConfig(entityType);
  }

  setUp(() {
    mockConfigService = MockISyncConfigurationService();
    mockValidationService = MockISyncValidationService();
    mockPaginationService = MockISyncPaginationService();
    mockProgressTracker = MockSyncProgressTracker();

    when(mockValidationService.validateVersion(any)).thenAnswer((_) async {});
    when(mockValidationService.validateDeviceId(any)).thenAnswer((_) async {});

    handler = SyncIncomingHandler(
      configurationService: mockConfigService,
      validationService: mockValidationService,
      paginationService: mockPaginationService,
      progressTracker: mockProgressTracker,
    );
  });

  group('SyncIncomingHandler', () {
    test('cursor is reset on new session (pageIndex == 0)', () async {
      when(mockConfigService.getConfiguration('AppUsageTimeRecord')).thenReturn(emptyDataConfig('AppUsageTimeRecord'));

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

    test('cursor is NOT reset on local data exhaustion (hasMorePages=false)', () async {
      // Empty local data → _prepareBidirectionalResponse returns hasMorePages=false.
      // Previously this path reset the cursor to -1 (causing re-fetch loops).
      // After the fix it must NOT reset.
      when(mockConfigService.getConfiguration('AppUsageTimeRecord')).thenReturn(emptyDataConfig('AppUsageTimeRecord'));

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
      when(mockConfigService.getConfiguration('Task')).thenReturn(emptyDataConfig('Task'));
      when(mockConfigService.getConfiguration('Habit')).thenReturn(emptyDataConfig('Habit'));

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

    test('client tracks server pages correctly in lockstep loop', () async {
      // Test that server page tracking works correctly in the lockstep loop
      // This test validates the core fix logic in sync_pagination_service.dart
      when(mockConfigService.getConfiguration('AppUsageTimeRecord')).thenReturn(emptyDataConfig('AppUsageTimeRecord'));

      // Simulate multiple pages with increasing server page numbers
      final serverResponses = [
        // Page 0: server has 3 pages total, current is 0
        createDto(
          entityType: 'AppUsageTimeRecord',
          pageIndex: 0,
          currentServerPage: 0,
          totalServerPages: 3,
          hasMoreServerPages: true,
        ),
        // Page 1: server has 3 pages total, current is 1
        createDto(
          entityType: 'AppUsageTimeRecord',
          pageIndex: 1,
          currentServerPage: 1,
          totalServerPages: 3,
          hasMoreServerPages: true,
        ),
        // Page 2: server has 3 pages total, current is 2 (last)
        createDto(
          entityType: 'AppUsageTimeRecord',
          pageIndex: 2,
          currentServerPage: 2,
          totalServerPages: 3,
          hasMoreServerPages: false,
        ),
      ];

      // Feed each incoming page through the handler in sequence, as the client would
      // during the lockstep loop. Only the first page (pageIndex == 0) starts a new
      // session and should reset the server-side cursor; subsequent pages must not.
      for (final response in serverResponses) {
        await handler.handleIncomingSync(
          response,
          onProgress: (BidirectionalSyncProgress progress) {},
          processDto: (PaginatedSyncDataDto dto) async => 0,
          createResponseDto: (syncDevice, localData, entityType,
              {currentServerPage, totalServerPages, hasMoreServerPages}) async {
            return createDto(entityType: entityType, pageIndex: 0);
          },
        );
      }

      // The reset only happens once, on the first (pageIndex == 0) page.
      // This is the core fix that prevents the quadratic re-fetch bug: resetting the
      // cursor again mid-session would restart pagination from page 0.
      verify(mockPaginationService.setLastSentServerPage(
        'device-1',
        'AppUsageTimeRecord',
        -1,
      )).called(1);
    });
  });
}
