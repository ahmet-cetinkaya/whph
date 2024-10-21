import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/sync/sync_device.dart';

class GetListSyncDevicesQuery implements IRequest<GetListSyncDevicesQueryResponse> {
  late int pageIndex;
  late int pageSize;

  GetListSyncDevicesQuery({required this.pageIndex, required this.pageSize});
}

class SyncDeviceListItem {
  final String id;
  final String fromIp;
  final String toIp;
  final String? name;
  final DateTime? lastSyncDate;

  SyncDeviceListItem({
    required this.id,
    required this.fromIp,
    required this.toIp,
    this.name,
    this.lastSyncDate,
  });
}

class GetListSyncDevicesQueryResponse extends PaginatedList<SyncDeviceListItem> {
  GetListSyncDevicesQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
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
                fromIp: e.fromIp,
                toIp: e.toIp,
                name: e.name,
                lastSyncDate: e.lastSyncDate,
              ))
          .toList(),
      totalItemCount: list.totalItemCount,
      totalPageCount: list.totalPageCount,
      pageIndex: list.pageIndex,
      pageSize: list.pageSize,
    );
  }
}
