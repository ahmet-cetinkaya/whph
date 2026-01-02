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

// --- Improved Manual Fakes/Mocks ---

class FakeMediator extends Fake implements Mediator {
  PaginatedSyncCommandResponse? responseToReturn;

  @override
  Future<Response> send<Request extends IRequest<Response>, Response>(Request? request) {
    if (request is PaginatedSyncCommand) {
      final response = responseToReturn;
      if (response == null) {
        throw StateError('FakeMediator: responseToReturn not set for PaginatedSyncCommand');
      }
      return Future.value(response as Response);
    }
    throw UnimplementedError('FakeMediator: Unexpected request type: ${request.runtimeType}');
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
    late FakeMediator fakeMediator;
    late MockIDeviceIdService mockDeviceIdService;
    late MockDeviceInfoPlugin mockDeviceInfoPlugin;

    setUp(() {
      initializeJsonMapper();
      fakeMediator = FakeMediator();
      mockDeviceIdService = MockIDeviceIdService();
      mockDeviceInfoPlugin = MockDeviceInfoPlugin();

      service = AndroidServerSyncService(fakeMediator, mockDeviceIdService, mockDeviceInfoPlugin);

      when(mockDeviceIdService.getDeviceId()).thenAnswer((_) async => 'test-device-id');
      when(mockDeviceInfoPlugin.androidInfo).thenAnswer((_) async => MockAndroidDeviceInfo());
    });

    tearDown(() {
      service.dispose();
    });

    test('should report failure when paginated sync command returns errors', () async {
      // 1. Start Server on a dynamic port (0) to avoid collisions
      final started = await service.startAsServer(0);
      expect(started, isTrue, reason: 'Server should start on dynamic port');
      final actualPort = service.serverPort;

      // 2. Mock the mediator to return a response WITH ERRORS
      const errorMsg = 'Version mismatch: local=1.0.0, remote=0.9.0';
      fakeMediator.responseToReturn = PaginatedSyncCommandResponse(
        isComplete: true,
        hasErrors: true,
        errorMessages: [errorMsg],
        paginatedSyncDataDto: null,
      );

      // 3. Connect a real WebSocket client to the server using the dynamic port
      final socket = await WebSocket.connect('ws://127.0.0.1:$actualPort');

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

      socket.add(JsonMapper.serialize(message));

      // 5. Listen for response
      final completer = Completer<Map<String, dynamic>>();
      socket.listen((data) {
        final respMsg = JsonMapper.deserialize<WebSocketMessage>(data.toString());
        if (respMsg?.type == 'paginated_sync_complete' || respMsg?.type == 'paginated_sync_error') {
          completer.complete(respMsg?.data as Map<String, dynamic>?);
        }
      });

      final responseData = await completer.future.timeout(Duration(seconds: 5));
      await socket.close();

      expect(responseData['success'], isFalse, reason: 'Success flag should be false when errors exist');

      // Check for specific error message
      expect(responseData['error'], contains('Version mismatch'),
          reason: 'Error string should contain mismatch detail');

      // Verify errorMessages list presence and content
      expect(responseData['errorMessages'], isA<List>(), reason: 'Response should include errorMessages list');
      final errorMessages = responseData['errorMessages'] as List;
      expect(errorMessages, contains(errorMsg), reason: 'errorMessages list should contain the specific error');

      expect(responseData['server_type'], equals('mobile'));
      expect(responseData['isComplete'], isTrue);
    });
  });
}
