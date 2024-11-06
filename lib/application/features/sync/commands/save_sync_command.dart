import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/sync/sync_device.dart';

class SaveSyncDeviceCommand implements IRequest<SaveSyncDeviceCommandResponse> {
  final String? id;
  final String fromIp;
  final String toIp;
  final String? name;
  final DateTime? lastSyncDate;

  SaveSyncDeviceCommand({
    this.id,
    required this.fromIp,
    required this.toIp,
    this.name,
    this.lastSyncDate,
  });
}

class SaveSyncDeviceCommandResponse {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;

  SaveSyncDeviceCommandResponse({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
  });
}

class SaveSyncDeviceCommandHandler implements IRequestHandler<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse> {
  final ISyncDeviceRepository _syncDeviceRepository;

  SaveSyncDeviceCommandHandler({required ISyncDeviceRepository syncDeviceRepository})
      : _syncDeviceRepository = syncDeviceRepository;

  @override
  Future<SaveSyncDeviceCommandResponse> call(SaveSyncDeviceCommand request) async {
    SyncDevice? syncDevice;

    if (request.id != null) {
      syncDevice = await _syncDeviceRepository.getById(request.id!);
      if (syncDevice == null) {
        throw BusinessException('SyncDevice with id ${request.id} not found');
      }

      await _update(syncDevice, request);
    } else {
      syncDevice = await _add(syncDevice, request);
    }

    return SaveSyncDeviceCommandResponse(
      id: syncDevice.id,
      createdDate: syncDevice.createdDate,
      modifiedDate: syncDevice.modifiedDate,
    );
  }

  Future<SyncDevice> _add(SyncDevice? syncDevice, SaveSyncDeviceCommand request) async {
    syncDevice = SyncDevice(
      id: nanoid(),
      createdDate: DateTime(0),
      fromIp: request.fromIp,
      toIp: request.toIp,
      name: request.name,
      lastSyncDate: request.lastSyncDate,
    );
    await _syncDeviceRepository.add(syncDevice);
    return syncDevice;
  }

  Future<SyncDevice> _update(SyncDevice syncDevice, SaveSyncDeviceCommand request) async {
    syncDevice.fromIp = request.fromIp;
    syncDevice.toIp = request.toIp;
    syncDevice.name = request.name;
    syncDevice.lastSyncDate = request.lastSyncDate;
    await _syncDeviceRepository.update(syncDevice);
    return syncDevice;
  }
}
