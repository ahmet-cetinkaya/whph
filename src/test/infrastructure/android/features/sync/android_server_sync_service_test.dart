import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/infrastructure/android/features/sync/android_server_sync_service.dart';
import 'package:mediatr/mediatr.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/paginated_sync_command.dart';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;
import 'dart:io';

// --- Manual Mocks ---

class MockMediator extends Mock implements Mediator {
  @override
  Future<Response> send<Request extends IRequest<Response>, Response>(Request? request) {
    if (request is PaginatedSyncCommand) {
      final response = PaginatedSyncCommandResponse(
        isComplete: true,
        hasErrors: true,
        errorMessages: ['Version mismatch: local=1.0.0, remote=0.9.0'],
        paginatedSyncDataDto: null,
      );
      return Future.value(response as Response);
    }

    return super.noSuchMethod(
      Invocation.method(#send, [request]),
      returnValue: Future.error(UnimplementedError('Missing stub for send')),
      returnValueForMissingStub: Future.error(UnimplementedError('Missing stub for send')),
    ) as Future<Response>;
  }
}

class MockIDeviceIdService extends Mock implements IDeviceIdService {
  @override
  Future<String> getDeviceId() {
    return super.noSuchMethod(
      Invocation.method(#getDeviceId, []),
      returnValue: Future.value(''),
    );
  }
}

class MockDeviceInfoPlugin extends Mock implements DeviceInfoPlugin {
  @override
  Future<AndroidDeviceInfo> get androidInfo {
    return super.noSuchMethod(
      Invocation.getter(#androidInfo),
      returnValue: Future.value(MockAndroidDeviceInfo()),
    );
  }
}

class MockAndroidDeviceInfo extends Mock implements AndroidDeviceInfo {
  @override
  String get model => 'TestModel';
}

// --------------------

void main() {
  group('AndroidServerSyncService Reproduction', () {
    late AndroidServerSyncService service;
    late MockMediator mockMediator;
    late MockIDeviceIdService mockDeviceIdService;
    late MockDeviceInfoPlugin mockDeviceInfoPlugin;

    setUp(() {
      initializeJsonMapper();
      mockMediator = MockMediator();
      mockDeviceIdService = MockIDeviceIdService();
      mockDeviceInfoPlugin = MockDeviceInfoPlugin();

      service = AndroidServerSyncService(mockMediator, mockDeviceIdService, mockDeviceInfoPlugin);

      when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');
      when(mockDeviceInfoPlugin.androidInfo).thenAnswer((_) async => MockAndroidDeviceInfo());
    });

    tearDown(() {
      service.dispose();
    });

    test('should report failure when paginated sync command returns errors', () async {
      // 1. Start Server
      final started = await service.startAsServer();
      if (!started) {
        print('Skipping test: Could not bind to port 44040');
        return;
      }

      // 2. Mock mediator logic is handled in MockMediator.send manually for this specific test case.
      // No need for when(mockMediator.send...).

      // 3. Connect a real WebSocket client to the server
      final socket = await WebSocket.connect('ws://127.0.0.1:44040');

      // 4. Send a dummy paginated_sync message
      final dummyDto = PaginatedSyncDataDto(
        entityType: 'TestEntity',
        syncDevice: SyncDevice(
            id: 'remote-device',
            createdDate: DateTime.now(),
            fromIp: '127.0.0.1',
            toIp: '127.0.0.1',
            fromDeviceId: 'remote-device',
            toDeviceId: 'test-device-id',
            name: 'Remote'),
        appVersion: '0.9.0',
        pageIndex: 0,
        pageSize: 10,
        totalItems: 0,
        totalPages: 0,
        isDebugMode: false,
        isLastPage: true,
      );

      final message = WebSocketMessage(
        type: 'paginated_sync',
        data: dummyDto.toJson(),
      );

      // Serializing with known mapper
      socket.add(JsonMapper.serialize(message));

      // 5. Listen for response
      final completer = Completer<Map<String, dynamic>>();
      socket.listen((data) {
        // Deserializing with known mapper
        final respMsg = JsonMapper.deserialize<WebSocketMessage>(data.toString());
        if (respMsg?.type == 'paginated_sync_complete' || respMsg?.type == 'paginated_sync_error') {
          completer.complete(respMsg?.data as Map<String, dynamic>?);
        }
      });

      final responseData = await completer.future.timeout(Duration(seconds: 2));
      await socket.close();

      // 6. Assertions
      print('Response Data: $responseData');

      if (responseData['success'] == true) {
        // This is what we expect to happen BEFORE the fix
        fail('Bug Reproduced: Server reported success: true despite Mediator returning hasErrors: true');
      }

      expect(responseData['success'], isFalse, reason: 'Should return success: false when errors occur');
      final hasErrorMsg = (responseData['error'] as String?)?.contains('Version mismatch') ??
          (responseData['message'] as String?)?.contains('Version mismatch') ??
          (responseData['errorMessages'] as List?)?.toString().contains('Version mismatch') ??
          false;

      expect(hasErrorMsg, isTrue, reason: 'Should return the error message');
    });
  });
}
