import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/core/application/features/sync/services/sync_completion_service.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';

class FakeMediator extends Fake implements Mediator {
  FakeMediator({this.existingDevice});

  final GetSyncDeviceQueryResponse? existingDevice;
  final List<SaveSyncDeviceCommand> savedCommands = [];

  @override
  Future<Response> send<Request extends IRequest<Response>, Response>(Request? request) {
    if (request is GetSyncDeviceQuery) {
      return Future.value(existingDevice as Response);
    }
    if (request is SaveSyncDeviceCommand) {
      final command = request as SaveSyncDeviceCommand;
      savedCommands.add(command);
      return Future.value(SaveSyncDeviceCommandResponse(
        id: command.id ?? 'new-id',
        createdDate: DateTime.now().toUtc(),
      ) as Response);
    }
    throw UnimplementedError('FakeMediator: unexpected request ${request.runtimeType}');
  }
}

GetSyncDeviceQueryResponse _existingDevice({DateTime? lastSyncDate}) => GetSyncDeviceQueryResponse(
      id: 'sync-device-1',
      name: 'Client Device',
      fromIp: '192.168.1.10',
      toIp: '192.168.1.20',
      fromDeviceId: 'client-device-id',
      toDeviceId: 'server-device-id',
      createdDate: DateTime.now().toUtc(),
      lastSyncDate: lastSyncDate,
    );

/// Mirrors the `syncDevice` payload a client sends inside `paginated_sync`.
Map<String, dynamic> _clientSyncDeviceData({DateTime? lastSyncDate}) => SyncDevice(
      id: 'sync-device-1',
      createdDate: DateTime.now().toUtc(),
      fromIp: '192.168.1.10',
      toIp: '192.168.1.20',
      fromDeviceId: 'client-device-id',
      toDeviceId: 'server-device-id',
      name: 'Client Device',
      lastSyncDate: lastSyncDate,
    ).toJson();

void main() {
  group('SyncCompletionService', () {
    test('persists a completion timestamp even when the client sent no previous lastSyncDate', () async {
      final mediator = FakeMediator(existingDevice: _existingDevice());
      final service = SyncCompletionService(mediator);

      await service.recordCompletion(
        syncDeviceData: _clientSyncDeviceData(),
        isComplete: true,
        succeeded: true,
      );

      expect(mediator.savedCommands, hasLength(1));
      expect(mediator.savedCommands.single.lastSyncDate, isNotNull);
      expect(mediator.savedCommands.single.id, 'sync-device-1');
    });

    test('returns the persisted timestamp as the syncCompletedAt payload field', () async {
      final mediator = FakeMediator(existingDevice: _existingDevice());
      final service = SyncCompletionService(mediator);

      final payload = await service.recordCompletion(
        syncDeviceData: _clientSyncDeviceData(),
        isComplete: true,
        succeeded: true,
      );

      final persisted = mediator.savedCommands.single.lastSyncDate!;
      expect(payload['syncCompletedAt'], persisted.toIso8601String());
    });

    test('does not update lastSyncDate when the sync failed', () async {
      final mediator = FakeMediator(existingDevice: _existingDevice());
      final service = SyncCompletionService(mediator);

      final payload = await service.recordCompletion(
        syncDeviceData: _clientSyncDeviceData(),
        isComplete: true,
        succeeded: false,
      );

      expect(mediator.savedCommands, isEmpty);
      expect(payload, isEmpty);
    });

    test('does not update lastSyncDate for a partial sync', () async {
      final mediator = FakeMediator(existingDevice: _existingDevice());
      final service = SyncCompletionService(mediator);

      final payload = await service.recordCompletion(
        syncDeviceData: _clientSyncDeviceData(),
        isComplete: false,
        succeeded: true,
      );

      expect(mediator.savedCommands, isEmpty);
      expect(payload, isEmpty);
    });

    test('returns the timestamp without persisting when no local device record matches', () async {
      final mediator = FakeMediator();
      final service = SyncCompletionService(mediator);

      final payload = await service.recordCompletion(
        syncDeviceData: _clientSyncDeviceData(),
        isComplete: true,
        succeeded: true,
      );

      expect(mediator.savedCommands, isEmpty);
      expect(payload['syncCompletedAt'], isNotNull);
    });
  });
}
