import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/application/features/sync/constants/sync_translation_keys.dart';

class UpdateSyncDeviceIpCommand implements IRequest<UpdateSyncDeviceIpCommandResponse> {
  final String deviceId;
  final String newIpAddress;
  final bool isFromIp; // true if updating fromIp, false if updating toIp

  UpdateSyncDeviceIpCommand({
    required this.deviceId,
    required this.newIpAddress,
    required this.isFromIp,
  });
}

class UpdateSyncDeviceIpCommandResponse {
  final bool success;
  final String message;
  final String? oldIpAddress;

  UpdateSyncDeviceIpCommandResponse({
    required this.success,
    required this.message,
    this.oldIpAddress,
  });
}

class UpdateSyncDeviceIpCommandHandler
    implements IRequestHandler<UpdateSyncDeviceIpCommand, UpdateSyncDeviceIpCommandResponse> {
  final ISyncDeviceRepository _syncDeviceRepository;

  UpdateSyncDeviceIpCommandHandler({
    required ISyncDeviceRepository syncDeviceRepository,
  }) : _syncDeviceRepository = syncDeviceRepository;

  @override
  Future<UpdateSyncDeviceIpCommandResponse> call(UpdateSyncDeviceIpCommand request) async {
    try {
      final syncDevice = await _syncDeviceRepository.getById(request.deviceId);
      if (syncDevice == null) {
        throw BusinessException('Sync device not found', SyncTranslationKeys.syncDeviceNotFoundError);
      }

      final oldIpAddress = request.isFromIp ? syncDevice.fromIp : syncDevice.toIp;

      if (request.isFromIp) {
        syncDevice.fromIp = request.newIpAddress;
      } else {
        syncDevice.toIp = request.newIpAddress;
      }

      await _syncDeviceRepository.update(syncDevice);

      Logger.info('✅ Updated sync device ${request.deviceId} IP address from $oldIpAddress to ${request.newIpAddress}');

      return UpdateSyncDeviceIpCommandResponse(
        success: true,
        message: 'IP address updated successfully',
        oldIpAddress: oldIpAddress,
      );
    } catch (e) {
      Logger.error('❌ Failed to update sync device IP: $e');
      return UpdateSyncDeviceIpCommandResponse(
        success: false,
        message: e.toString(),
      );
    }
  }
}
