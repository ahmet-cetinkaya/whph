import 'package:acore/acore.dart' hide IRepository;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_device_coordinator.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/services/sync_outgoing_handler.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// A timestamp far enough in the past that no local clock could produce it,
/// so a test that passes cannot be passing on `DateTime.now()`.
final DateTime _serverCompletedAt = DateTime.utc(2020, 1, 1, 12, 30);

void main() {
  group('SyncOutgoingHandler lastSyncDate', () {
    late FakeSyncDeviceRepository repository;
    late RecordingLogger logger;

    setUp(() {
      repository = FakeSyncDeviceRepository([_device()]);
      logger = RecordingLogger();
      Logger.initialize(FakeContainer(logger));
    });

    test('stores the completion timestamp returned by the server', () async {
      final paginationService = FakeSyncPaginationService(serverSyncCompletedAt: _serverCompletedAt);

      await _runSync(repository: repository, paginationService: paginationService);

      expect(repository.devices.single.lastSyncDate, _serverCompletedAt);
      expect(logger.warnings, isNot(contains(contains('did not return a sync completion timestamp'))));
    });

    test('falls back to a local timestamp and warns when the server omits the timestamp', () async {
      final paginationService = FakeSyncPaginationService(serverSyncCompletedAt: null);
      final before = DateTime.now().toUtc();

      await _runSync(repository: repository, paginationService: paginationService);

      final storedDate = repository.devices.single.lastSyncDate;
      expect(storedDate, isNotNull);
      expect(storedDate!.isUtc, isTrue);
      expect(storedDate.isBefore(before), isFalse);
      expect(logger.warnings, contains(contains('did not return a sync completion timestamp')));
    });
  });
}

Future<void> _runSync({
  required FakeSyncDeviceRepository repository,
  required FakeSyncPaginationService paginationService,
}) async {
  final handler = SyncOutgoingHandler(
    syncDeviceRepository: repository,
    paginationService: paginationService,
    deviceCoordinator: SyncDeviceCoordinator(
      configurationService: FakeSyncConfigurationService(),
      communicationService: FakeSyncCommunicationService(),
      syncDeviceRepository: repository,
    ),
  );

  final result = await handler.initiateOutgoingSync(
    syncWithDevice: (_) async => true,
    createResponseDto: (_, __, ___, {currentServerPage, totalServerPages, hasMoreServerPages}) async =>
        throw UnimplementedError('createResponseDto is not reached in this test'),
    resetProgressTracking: () {},
  );

  expect(result.isComplete, isTrue);
  expect(result.syncedDeviceCount, 1);
}

SyncDevice _device() => SyncDevice(
      id: 'sync-device-1',
      createdDate: DateTime.utc(2019),
      fromIp: '192.168.1.10',
      toIp: '192.168.1.20',
      fromDeviceId: 'client-device-id',
      toDeviceId: 'server-device-id',
      name: 'Server Device',
    );

class FakeSyncDeviceRepository extends Fake implements ISyncDeviceRepository {
  FakeSyncDeviceRepository(this.devices);

  final List<SyncDevice> devices;

  @override
  Future<List<SyncDevice>> getAll({
    bool includeDeleted = false,
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
  }) async =>
      devices;

  @override
  Future<SyncDevice?> getById(String id, {bool includeDeleted = false}) async =>
      devices.where((device) => device.id == id).firstOrNull;

  @override
  Future<void> update(SyncDevice item) async {}
}

class FakeSyncPaginationService extends Fake implements ISyncPaginationService {
  FakeSyncPaginationService({required this.serverSyncCompletedAt});

  final DateTime? serverSyncCompletedAt;

  @override
  void resetProgress() {}

  @override
  DateTime? getServerSyncCompletedAt(String deviceId) => serverSyncCompletedAt;
}

/// The coordinator is only exercised for its logging/consistency passes here;
/// no configuration means it short-circuits without touching the network.
class FakeSyncConfigurationService extends Fake implements ISyncConfigurationService {
  @override
  List<PaginatedSyncConfig> getAllConfigurations() => const [];

  @override
  PaginatedSyncConfig? getConfiguration(String entityType) => null;
}

class FakeSyncCommunicationService extends Fake implements ISyncCommunicationService {
  @override
  Future<SyncCommunicationResponse> sendPaginatedDataToDevice(String ipAddress, PaginatedSyncDataDto dto) async =>
      SyncCommunicationResponse(success: true, isComplete: true);
}

class RecordingLogger implements ILogger {
  final List<String> warnings = [];

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    warnings.add(message);
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
}

class FakeContainer implements IContainer {
  FakeContainer(this._logger);

  final ILogger _logger;

  @override
  IContainer get instance => this;

  @override
  T resolve<T>() {
    if (T == ILogger) return _logger as T;
    throw UnimplementedError('FakeContainer: unexpected resolve of $T');
  }

  @override
  void registerSingleton<T>(T Function(IContainer) factory) => throw UnimplementedError();

  @override
  bool isRegistered<T>() => T == ILogger;

  @override
  void clear() {}
}
