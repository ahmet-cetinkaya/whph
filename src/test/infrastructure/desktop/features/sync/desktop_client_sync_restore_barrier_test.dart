import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_client_sync_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeJsonMapper();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const deviceInfoChannel = MethodChannel('dev.fluttercommunity.plus/device_info');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      deviceInfoChannel,
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
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(deviceInfoChannel, null);
  });

  test('persistent client session drains before restore and admits its response work', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final barrier = McpRestoreBarrier();
    final database = AppDatabase.forTesting(restoreBarrier: barrier);
    final deviceIds = _PausedDatabaseReadingDeviceIdService(database);
    final client = DesktopClientSyncService(
      Mediator(Pipeline()),
      deviceIds,
      restoreBarrier: barrier,
    );
    final syncStarted = Completer<void>();
    final nextPageRequested = Completer<void>();
    final restoreEntered = Completer<void>();
    final releaseRestore = Completer<void>();
    var pageRequestCount = 0;
    late WebSocket socket;

    server.listen((request) async {
      socket = await WebSocketTransformer.upgrade(request);
      socket.listen((rawMessage) {
        final message = jsonDecode(rawMessage as String) as Map<String, dynamic>;
        switch (message['type']) {
          case 'client_connect':
            socket.add(jsonEncode({
              'type': 'client_connected',
              'data': {'success': true, 'serverId': 'server', 'serverName': 'Test server'},
            }));
          case 'paginated_sync_start':
            if (!syncStarted.isCompleted) syncStarted.complete();
          case 'paginated_sync_request':
            pageRequestCount++;
            if (!nextPageRequested.isCompleted) nextPageRequested.complete();
        }
      });
    });

    addTearDown(() async {
      if (!deviceIds.releaseDatabaseRead.isCompleted) deviceIds.releaseDatabaseRead.complete();
      if (!releaseRestore.isCompleted) releaseRestore.complete();
      await client.disconnectFromServer();
      await socket.close();
      await server.close(force: true);
      await database.close();
    });

    final connection = client.connectToServer('127.0.0.1', server.port);
    await syncStarted.future.timeout(const Duration(seconds: 2));

    final restore = barrier.runExclusive(() async {
      restoreEntered.complete();
      await releaseRestore.future;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(restoreEntered.isCompleted, isFalse);

    socket.add(jsonEncode({
      'type': 'paginated_sync_started',
      'data': {'success': true},
    }));
    await deviceIds.databaseReadStarted.future.timeout(const Duration(seconds: 2));
    socket.add(jsonEncode({
      'type': 'paginated_sync_complete',
      'data': {'success': true, 'isComplete': true},
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(restoreEntered.isCompleted, isFalse, reason: 'restore must wait for the already-admitted response callback');

    deviceIds.releaseDatabaseRead.complete();
    await nextPageRequested.future.timeout(const Duration(seconds: 2));
    await deviceIds.databaseRead.future.timeout(const Duration(seconds: 2));

    await restoreEntered.future.timeout(const Duration(seconds: 2));
    socket.add(jsonEncode({
      'type': 'paginated_sync_started',
      'data': {'success': true},
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(pageRequestCount, 1);
    releaseRestore.complete();

    expect(await connection, isTrue);
    await restore;
  });

  for (final termination in ['socket-close', 'protocol-error', 'disconnect']) {
    test('$termination releases the persistent client session lease', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final barrier = McpRestoreBarrier();
      final database = AppDatabase.forTesting(restoreBarrier: barrier);
      final deviceIds = _PausedDatabaseReadingDeviceIdService(database);
      final client = DesktopClientSyncService(
        Mediator(Pipeline()),
        deviceIds,
        restoreBarrier: barrier,
      );
      final syncStarted = Completer<void>();
      final restoreEntered = Completer<void>();
      final releaseRestore = Completer<void>();
      late WebSocket socket;

      server.listen((request) async {
        socket = await WebSocketTransformer.upgrade(request);
        socket.listen((rawMessage) {
          final message = jsonDecode(rawMessage as String) as Map<String, dynamic>;
          if (message['type'] == 'client_connect') {
            socket.add(jsonEncode({
              'type': 'client_connected',
              'data': {'success': true, 'serverId': 'server', 'serverName': 'Test server'},
            }));
          } else if (message['type'] == 'paginated_sync_start' && !syncStarted.isCompleted) {
            syncStarted.complete();
          }
        });
      });

      final connection = client.connectToServer('127.0.0.1', server.port);
      await syncStarted.future.timeout(const Duration(seconds: 2));
      socket.add(jsonEncode({
        'type': 'paginated_sync_started',
        'data': {'success': true},
      }));
      await deviceIds.databaseReadStarted.future.timeout(const Duration(seconds: 2));

      final restore = barrier.runExclusive(() async {
        restoreEntered.complete();
        await releaseRestore.future;
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(restoreEntered.isCompleted, isFalse);

      Future<void>? terminationFuture;
      if (termination == 'socket-close') {
        terminationFuture = socket.close();
      } else if (termination == 'protocol-error') {
        socket.add(jsonEncode({
          'type': 'error',
          'data': {'message': 'forced failure'},
        }));
      } else {
        terminationFuture = client.disconnectFromServer();
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(restoreEntered.isCompleted, isFalse, reason: '$termination must drain the admitted callback');

      deviceIds.releaseDatabaseRead.complete();
      await deviceIds.databaseRead.future.timeout(const Duration(seconds: 2));
      await restoreEntered.future.timeout(const Duration(seconds: 2));
      releaseRestore.complete();
      await restore;
      await terminationFuture;

      expect(await connection.timeout(const Duration(seconds: 2)), isFalse);
      await barrier.runExclusive(() async {});

      await client.disconnectFromServer();
      await socket.close();
      await server.close(force: true);
      await database.close();
    });
  }
}

final class _PausedDatabaseReadingDeviceIdService implements IDeviceIdService {
  _PausedDatabaseReadingDeviceIdService(this.database);

  final AppDatabase database;
  final Completer<void> databaseReadStarted = Completer<void>();
  final Completer<void> releaseDatabaseRead = Completer<void>();
  final Completer<void> databaseRead = Completer<void>();
  var calls = 0;

  @override
  Future<String> getDeviceId() async {
    calls++;
    if (calls >= 3) {
      if (!databaseReadStarted.isCompleted) databaseReadStarted.complete();
      await releaseDatabaseRead.future;
      await database.customSelect('SELECT 1').get();
      if (!databaseRead.isCompleted) databaseRead.complete();
    }
    return 'test-client';
  }
}
