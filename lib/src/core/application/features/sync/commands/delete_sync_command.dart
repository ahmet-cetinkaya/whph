import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/sync/sync_device.dart';
import 'package:whph/src/core/application/features/sync/constants/sync_translation_keys.dart';

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
      throw BusinessException('Sync device not found', SyncTranslationKeys.syncDeviceNotFoundError);
    }

    await _syncDeviceRepository.delete(syncDevice);

    return DeleteSyncDeviceCommandResponse();
  }
}
