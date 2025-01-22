import 'package:mediatr/mediatr.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';

class GetListByTopAppUsagesQuery implements IRequest<GetListByTopAppUsagesQueryResponse> {
  late int pageIndex;
  late int pageSize;
  List<String>? filterByTags;
  DateTime? startDate;
  DateTime? endDate;

  GetListByTopAppUsagesQuery({
    required this.pageIndex,
    required this.pageSize,
    this.filterByTags,
    this.startDate,
    this.endDate,
  });
}

class AppUsageListItem {
  String id;
  String name;
  String? displayName;
  String? color;
  String? deviceName;
  int duration;

  AppUsageListItem({
    required this.id,
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
    required this.duration,
  });
}

class GetListByTopAppUsagesQueryResponse extends PaginatedList<AppUsageListItem> {
  GetListByTopAppUsagesQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
}

class GetListByTopAppUsagesQueryHandler
    implements IRequestHandler<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse> {
  final IAppUsageTimeRecordRepository _timeRecordRepository;

  GetListByTopAppUsagesQueryHandler({
    required IAppUsageTimeRecordRepository timeRecordRepository,
  }) : _timeRecordRepository = timeRecordRepository;

  @override
  Future<GetListByTopAppUsagesQueryResponse> call(GetListByTopAppUsagesQuery request) async {
    final results = await _timeRecordRepository.getTopAppUsagesWithDetails(
      pageIndex: request.pageIndex,
      pageSize: request.pageSize,
      filterByTags: request.filterByTags,
      startDate: request.startDate,
      endDate: request.endDate,
    );

    final items = results.items
        .map((record) => AppUsageListItem(
              id: record.id,
              name: record.name,
              displayName: record.displayName,
              color: record.color,
              deviceName: record.deviceName,
              duration: record.duration,
            ))
        .toList();

    return GetListByTopAppUsagesQueryResponse(
      items: items,
      totalItemCount: results.totalItemCount,
      totalPageCount: results.totalPageCount,
      pageIndex: results.pageIndex,
      pageSize: results.pageSize,
    );
  }
}
