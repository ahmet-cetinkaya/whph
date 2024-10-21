import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/domain/features/sync/sync_device.dart';

class DeleteSyncDeviceCommand implements IRequest<DeleteSyncDeviceCommandResponse> {
  final String id;

  DeleteSyncDeviceCommand({required this.id});
}

class DeleteSyncDeviceCommandResponse {}

class DeleteSyncDeviceCommandHandler
    implements IRequestHandler<DeleteSyncDeviceCommand, DeleteSyncDeviceCommandResponse> {
  final ISyncDeviceRepository _syncDeviceRepository;

  DeleteSyncDeviceCommandHandler({required ISyncDeviceRepository syncDeviceRepository})
      : _syncDeviceRepository = syncDeviceRepository;

  @override
  Future<DeleteSyncDeviceCommandResponse> call(DeleteSyncDeviceCommand request) async {
    SyncDevice? syncDevice = await _syncDeviceRepository.getById(request.id);
    if (syncDevice == null) {
      throw Exception('SyncDevice with id ${request.id} not found');
    }

    await _syncDeviceRepository.delete(syncDevice);

    return DeleteSyncDeviceCommandResponse();
  }
}
