import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/sync/sync_device.dart';

class GetSyncDeviceQuery implements IRequest<GetSyncDeviceQueryResponse> {
  late String? id;
  late String? fromIP;
  late String? toIP;

  GetSyncDeviceQuery({this.id, this.fromIP, this.toIP});
}

class GetSyncDeviceQueryResponse extends SyncDevice {
  GetSyncDeviceQueryResponse({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required super.fromIp,
    required super.toIp,
    super.name,
    super.lastSyncDate,
  });
}

class GetSyncDeviceQueryHandler implements IRequestHandler<GetSyncDeviceQuery, GetSyncDeviceQueryResponse> {
  late final ISyncDeviceRepository _syncDeviceRepository;

  GetSyncDeviceQueryHandler({required ISyncDeviceRepository syncDeviceRepository})
      : _syncDeviceRepository = syncDeviceRepository;

  @override
  Future<GetSyncDeviceQueryResponse> call(GetSyncDeviceQuery request) async {
    SyncDevice? syncDevices;

    if (request.id != null) {
      syncDevices = await _syncDeviceRepository.getById(
        request.id!,
      );
    } else if (request.fromIP != null && request.toIP != null) {
      syncDevices = await _syncDeviceRepository.getByFromToIp(
        request.fromIP!,
        request.toIP!,
      );
    }

    if (syncDevices == null) {
      throw BusinessException('SyncDevice with id ${request.id} not found');
    }

    return GetSyncDeviceQueryResponse(
      id: syncDevices.id,
      createdDate: syncDevices.createdDate,
      modifiedDate: syncDevices.modifiedDate,
      fromIp: syncDevices.fromIp,
      toIp: syncDevices.toIp,
      name: syncDevices.name,
      lastSyncDate: syncDevices.lastSyncDate,
    );
  }
}
