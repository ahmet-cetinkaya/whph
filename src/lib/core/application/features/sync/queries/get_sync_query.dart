import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';

class GetSyncDeviceQuery implements IRequest<GetSyncDeviceQueryResponse> {
  late String? id;
  late String? fromIP;
  late String? toIP;
  late String? fromDeviceId;
  late String? toDeviceId;

  GetSyncDeviceQuery({this.id, this.fromIP, this.toIP, this.fromDeviceId, this.toDeviceId});
}

class GetSyncDeviceQueryResponse extends SyncDevice {
  GetSyncDeviceQueryResponse({
    required super.id,
    required super.fromIp,
    required super.toIp,
    required super.fromDeviceId,
    required super.toDeviceId,
    super.name,
    super.lastSyncDate,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
  });
}

class GetSyncDeviceQueryHandler implements IRequestHandler<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?> {
  late final ISyncDeviceRepository _syncDeviceRepository;

  GetSyncDeviceQueryHandler({required ISyncDeviceRepository syncDeviceRepository})
      : _syncDeviceRepository = syncDeviceRepository;

  @override
  Future<GetSyncDeviceQueryResponse?> call(GetSyncDeviceQuery request) async {
    SyncDevice? syncDevice;

    syncDevice = await _syncDeviceRepository.getFirst(_getFilters(request));

    if (syncDevice == null) {
      return null; // Return null instead of throwing exception
    }

    return GetSyncDeviceQueryResponse(
      id: syncDevice.id,
      fromIp: syncDevice.fromIp,
      fromDeviceId: syncDevice.fromDeviceId,
      toIp: syncDevice.toIp,
      toDeviceId: syncDevice.toDeviceId,
      name: syncDevice.name,
      lastSyncDate: syncDevice.lastSyncDate != null ? DateTimeHelper.toUtcDateTime(syncDevice.lastSyncDate!) : null,
      createdDate: DateTimeHelper.toUtcDateTime(syncDevice.createdDate),
      modifiedDate: syncDevice.modifiedDate != null ? DateTimeHelper.toUtcDateTime(syncDevice.modifiedDate!) : null,
      deletedDate: syncDevice.deletedDate != null ? DateTimeHelper.toUtcDateTime(syncDevice.deletedDate!) : null,
    );
  }

  CustomWhereFilter _getFilters(GetSyncDeviceQuery request) {
    final where = CustomWhereFilter.empty();

    if (request.id != null) {
      where.query = 'id = ?';
      where.variables.add(request.id!);
    }

    if (request.fromIP != null) {
      if (where.query.isNotEmpty) {
        where.query += ' AND ';
      }
      where.query += 'from_ip = ?';
      where.variables.add(request.fromIP!);
    }

    if (request.toIP != null) {
      if (where.query.isNotEmpty) {
        where.query += ' AND ';
      }
      where.query += 'to_ip = ?';
      where.variables.add(request.toIP!);
    }

    if (request.fromDeviceId != null) {
      if (where.query.isNotEmpty) {
        where.query += ' AND ';
      }
      where.query += 'from_device_id = ?';
      where.variables.add(request.fromDeviceId!);
    }

    if (request.toDeviceId != null) {
      if (where.query.isNotEmpty) {
        where.query += ' AND ';
      }
      where.query += 'to_device_id = ?';
      where.variables.add(request.toDeviceId!);
    }

    return where;
  }
}
