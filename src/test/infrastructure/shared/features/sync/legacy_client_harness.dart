// Drives the in-tree legacy sync clients (identical to v0.24.3, D10) for the
// T22 legacy tests and the fixture recording. The legacy domain `SyncDevice`
// is used here; the engine package is not imported to avoid the name clash.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/paginated_sync_command.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/models/sync_data.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_data_processing_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:whph/core/application/features/sync/services/sync_validation_service.dart';
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_client_sync_service.dart';

const String legacyDeviceId = 'legacy-device-1';

/// Answers the device-info plugin the legacy client asks for its name.
void mockDeviceInfoChannel() {
  const channel = MethodChannel('dev.fluttercommunity.plus/device_info');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async => {
      'name': 'Test Linux',
      'version': '1',
      'id': 'test',
      'idLike': <String>[],
      'versionCodename': 'test',
      'versionId': '1',
      'prettyName': 'Test Linux',
      'buildId': 'test',
      'variant': 'test',
      'variantId': 'test',
      'machineId': 'test',
    },
  );
}

class FixedDeviceIdService implements IDeviceIdService {
  @override
  Future<String> getDeviceId() async => legacyDeviceId;
}

/// The real legacy validation, recording what it throws.
class RecordingValidationService implements ISyncValidationService {
  final SyncValidationService _inner = SyncValidationService(deviceIdService: FixedDeviceIdService());
  final List<SyncValidationException> thrown = [];

  @override
  Future<void> validateVersion(String remoteVersion) async {
    try {
      await _inner.validateVersion(remoteVersion);
    } on SyncValidationException catch (error) {
      thrown.add(error);
      rethrow;
    }
  }

  @override
  Future<void> validateDeviceId(SyncDevice remoteDevice) => _inner.validateDeviceId(remoteDevice);

  @override
  void validateEnvironmentMode(PaginatedSyncDataDto dto) => _inner.validateEnvironmentMode(dto);

  @override
  bool validateSyncDataIntegrity(PaginatedSyncDataDto dto) => _inner.validateSyncDataIntegrity(dto);

  @override
  Future<void> validateSyncPrerequisites() => _inner.validateSyncPrerequisites();
}

/// Counts the items the legacy code would have written to its database.
class CountingDataProcessing implements ISyncDataProcessingService {
  int calls = 0;

  @override
  Future<int> processSyncDataBatchDynamic(SyncData syncData, dynamic repository) async {
    calls++;
    return syncData.getTotalItemCount();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// Services the legacy command handler builds but must not reach before the
/// version check fails: any call fails the test.
class _UnreachedDevices implements ISyncDeviceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _UnreachedConfiguration implements ISyncConfigurationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _UnreachedCommunication implements ISyncCommunicationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _UnreachedPagination implements ISyncPaginationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// The legacy client side with a real command handler behind its mediator.
class LegacyClientSide {
  final RecordingValidationService validation = RecordingValidationService();
  final CountingDataProcessing processing = CountingDataProcessing();
  late final Mediator mediator;

  LegacyClientSide() {
    mediator = Mediator(Pipeline())
      ..registerHandler<PaginatedSyncCommand, PaginatedSyncCommandResponse, PaginatedSyncCommandHandler>(
        () => PaginatedSyncCommandHandler(
          syncDeviceRepository: _UnreachedDevices(),
          configurationService: _UnreachedConfiguration(),
          validationService: validation,
          communicationService: _UnreachedCommunication(),
          dataProcessingService: processing,
          paginationService: _UnreachedPagination(),
          restoreBarrier: McpRestoreBarrier(),
        ),
      );
  }

  DesktopClientSyncService desktopClient() =>
      DesktopClientSyncService(mediator, FixedDeviceIdService(), restoreBarrier: McpRestoreBarrier());

  /// Runs [dto] through the legacy command like a received page.
  Future<PaginatedSyncCommandResponse> receive(PaginatedSyncDataDto dto) => mediator
      .send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(PaginatedSyncCommand(paginatedSyncDataDto: dto));
}

/// A legacy push page of tasks with [markers] as titles.
PaginatedSyncDataDto syntheticPushDto(List<String> markers) {
  final created = DateTime.utc(2026);
  final tasks = [
    for (var i = 0; i < markers.length; i++) Task(id: 'task-$i', createdDate: created, title: markers[i]),
  ];
  return PaginatedSyncDataDto(
    appVersion: AppInfo.version,
    syncDevice: SyncDevice(
      id: 'sync-device-1',
      createdDate: created,
      fromIp: '192.168.1.5',
      toIp: '192.168.1.9',
      fromDeviceId: legacyDeviceId,
      toDeviceId: 'new-device',
      name: 'Legacy Phone',
    ),
    isDebugMode: false,
    entityType: 'Task',
    pageIndex: 0,
    pageSize: 50,
    totalPages: 1,
    totalItems: markers.length,
    isLastPage: true,
    tasksSyncData: PaginatedSyncData<Task>(
      data: SyncData<Task>(createSync: tasks, updateSync: [], deleteSync: []),
      pageIndex: 0,
      pageSize: 50,
      totalPages: 1,
      totalItems: markers.length,
      isLastPage: true,
      entityType: 'Task',
    ),
  );
}

/// A test-only legacy server: records every text message and answers like
/// the v0.24.3 server did, so the legacy clients run to the end.
class LegacyCaptureStub {
  final List<Map<String, dynamic>> requests = [];
  late final HttpServer _server;

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_server.forEach((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((raw) {
        final message = jsonDecode(raw as String) as Map<String, dynamic>;
        requests.add(message);
        final reply = _scripted(message['type'] as String);
        if (reply != null) socket.add(jsonEncode(reply));
      });
    }));
  }

  Future<void> stop() => _server.close(force: true);

  Map<String, dynamic>? _scripted(String type) {
    switch (type) {
      case 'device_info':
        return {
          'type': 'device_info_response',
          'data': {'success': true, 'deviceId': 'stub', 'deviceName': 'Stub', 'appName': 'WHPH', 'platform': 'linux'},
        };
      case 'client_connect':
        return {
          'type': 'client_connected',
          'data': {'success': true, 'serverId': 'stub', 'serverName': 'Stub'},
        };
      case 'paginated_sync_start':
        return {
          'type': 'paginated_sync_started',
          'data': {'success': true},
        };
      case 'paginated_sync_request':
      case 'paginated_sync':
        return {
          'type': 'paginated_sync_complete',
          'data': {'success': true, 'isComplete': true},
        };
    }
    return null;
  }
}
