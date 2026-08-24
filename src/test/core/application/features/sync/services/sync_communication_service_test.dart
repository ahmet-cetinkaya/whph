import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/sync_communication_service/sync_communication_service.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';

void main() {
  group('SyncCommunicationService', () {
    test('retries before a timed-out socket finishes closing', () async {
      var connectionCount = 0;
      final secondConnection = Completer<void>();
      final firstSocketClosed = Completer<void>();
      final secondConnectionArrivedBeforeFirstClosed = Completer<bool>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((request) async {
        connectionCount++;
        final socket = await WebSocketTransformer.upgrade(request);
        if (connectionCount == 1) {
          socket.done.then<void>(
            (_) => firstSocketClosed.complete(),
            onError: firstSocketClosed.completeError,
          );
          socket.listen((_) {}).pause();
        } else if (connectionCount == 2) {
          secondConnectionArrivedBeforeFirstClosed.complete(!firstSocketClosed.isCompleted);
          secondConnection.complete();
          socket.listen((_) {});
        }
      });

      final response = await SyncCommunicationService(
        websocketPort: server.port,
        maxRetries: 2,
        baseTimeout: const Duration(milliseconds: 50),
        retryBackoff: (_) => const Duration(milliseconds: 1),
      ).sendPaginatedDataToDevice(InternetAddress.loopbackIPv4.address, _syncData());

      await secondConnection.future;
      expect(connectionCount, 2);
      expect(await secondConnectionArrivedBeforeFirstClosed.future, isTrue);
      expect(response.success, isFalse);
    });

    test('closes the socket after a successful paginated sync response', () async {
      final clientClosed = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen(
          (_) {
            socket.add(jsonEncode(WebSocketMessage(
              type: 'paginated_sync_complete',
              data: <String, dynamic>{
                'success': true,
                'isComplete': true,
                'paginatedSyncDataDto': _syncData().toJson(),
              },
            ).toJson()));
          },
          onDone: () async {
            await socket.close();
            clientClosed.complete();
          },
          onError: clientClosed.completeError,
        );
      });

      final response = await SyncCommunicationService(websocketPort: server.port).sendPaginatedDataToDevice(
        InternetAddress.loopbackIPv4.address,
        _syncData(),
      );

      await clientClosed.future;
      expect(response.success, isTrue);
      expect(response.isComplete, isTrue);
    });
  });
}

PaginatedSyncDataDto _syncData() {
  return PaginatedSyncDataDto(
    appVersion: '1.0.0',
    syncDevice: SyncDevice(
      id: 'device-id',
      createdDate: DateTime.utc(2026),
      fromIp: InternetAddress.loopbackIPv4.address,
      toIp: InternetAddress.loopbackIPv4.address,
      fromDeviceId: 'device-id',
      toDeviceId: 'remote-device-id',
      name: 'Test device',
    ),
    isDebugMode: false,
    entityType: 'tasks',
    pageIndex: 0,
    pageSize: 1,
    totalPages: 1,
    totalItems: 0,
    isLastPage: true,
  );
}
