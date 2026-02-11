import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:acore/acore.dart';
import 'package:domain/features/sync/sync_device.dart';

class GetListSyncDevicesQuery implements IRequest<GetListSyncDevicesQueryResponse> {
  late int pageIndex;
  late int pageSize;

  GetListSyncDevicesQuery({required this.pageIndex, required this.pageSize});
}

class SyncDeviceListItem {
  final String id;
  final String fromIP;
  final String fromDeviceID;
  final String toIP;
  final String toDeviceID;

  final String? name;
  final DateTime? lastSyncDate;

  SyncDeviceListItem({
    required this.id,
    required this.fromIP,
    required this.toIP,
    required this.fromDeviceID,
    required this.toDeviceID,
    this.name,
    this.lastSyncDate,
  });
}

class GetListSyncDevicesQueryResponse extends PaginatedList<SyncDeviceListItem> {
  GetListSyncDevicesQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
}

class GetListSyncDevicesQueryHandler
    implements IRequestHandler<GetListSyncDevicesQuery, GetListSyncDevicesQueryResponse> {
  late final ISyncDeviceRepository _syncDeviceRepository;

  GetListSyncDevicesQueryHandler({required ISyncDeviceRepository syncDeviceRepository})
      : _syncDeviceRepository = syncDeviceRepository;

  @override
  Future<GetListSyncDevicesQueryResponse> call(GetListSyncDevicesQuery request) async {
    PaginatedList<SyncDevice> list = await _syncDeviceRepository.getList(
      request.pageIndex,
      request.pageSize,
    );

    return GetListSyncDevicesQueryResponse(
      items: list.items
          .map((e) => SyncDeviceListItem(
                id: e.id,
                fromIP: e.fromIp,
                fromDeviceID: e.fromDeviceId,
                toIP: e.toIp,
                toDeviceID: e.toDeviceId,
                name: e.name,
                lastSyncDate: e.lastSyncDate != null ? DateTimeHelper.toUtcDateTime(e.lastSyncDate!) : null,
              ))
          .toList(),
      totalItemCount: list.totalItemCount,
      pageIndex: list.pageIndex,
      pageSize: list.pageSize,
    );
  }
}
