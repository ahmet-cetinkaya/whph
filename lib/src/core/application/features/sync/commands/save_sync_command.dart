import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/sync/sync_device.dart';
import 'package:whph/src/core/application/features/sync/constants/sync_translation_keys.dart';

class SaveSyncDeviceCommand implements IRequest<SaveSyncDeviceCommandResponse> {
  final String? id;
  final String fromIP;
  final String toIP;
  final String fromDeviceId;
  final String toDeviceId;
  final String? name;
  final DateTime? lastSyncDate;

  SaveSyncDeviceCommand({
    this.id,
    required this.fromIP,
    required this.toIP,
    required this.fromDeviceId,
    required this.toDeviceId,
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

  SaveSyncDeviceCommandHandler({
    required ISyncDeviceRepository syncDeviceRepository,
  }) : _syncDeviceRepository = syncDeviceRepository;

  @override
  Future<SaveSyncDeviceCommandResponse> call(SaveSyncDeviceCommand request) async {
    SyncDevice? syncDevice;

    if (request.id != null) {
      syncDevice = await _syncDeviceRepository.getById(request.id!);
      if (syncDevice == null) {
        throw BusinessException('Sync device not found', SyncTranslationKeys.syncDeviceNotFoundError);
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
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now().toUtc(),
      fromIp: request.fromIP,
      toIp: request.toIP,
      fromDeviceId: request.fromDeviceId,
      toDeviceId: request.toDeviceId,
      name: request.name,
      lastSyncDate: request.lastSyncDate != null ? DateTimeHelper.toUtcDateTime(request.lastSyncDate!) : null,
    );
    await _syncDeviceRepository.add(syncDevice);
    return syncDevice;
  }

  Future<SyncDevice> _update(SyncDevice syncDevice, SaveSyncDeviceCommand request) async {
    syncDevice.fromIp = request.fromIP;
    syncDevice.toIp = request.toIP;
    syncDevice.name = request.name;
    syncDevice.lastSyncDate = request.lastSyncDate != null ? DateTimeHelper.toUtcDateTime(request.lastSyncDate!) : null;
    syncDevice.fromDeviceId = request.fromDeviceId;
    syncDevice.toDeviceId = request.toDeviceId;
    await _syncDeviceRepository.update(syncDevice);
    return syncDevice;
  }
}
