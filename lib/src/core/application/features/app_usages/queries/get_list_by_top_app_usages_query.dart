import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';

class GetListByTopAppUsagesQuery implements IRequest<GetListByTopAppUsagesQueryResponse> {
  late int pageIndex;
  late int pageSize;
  List<String>? filterByTags;
  bool showNoTagsFilter;
  DateTime? startDate;
  DateTime? endDate;
  String? searchByProcessName;
  List<String>? filterByDevices;

  GetListByTopAppUsagesQuery({
    required this.pageIndex,
    required this.pageSize,
    this.filterByTags,
    this.showNoTagsFilter = false,
    DateTime? startDate,
    DateTime? endDate,
    this.searchByProcessName,
    this.filterByDevices,
  })  : startDate = startDate != null ? DateTimeHelper.toUtcDateTime(startDate) : null,
        endDate = endDate != null ? DateTimeHelper.toUtcDateTime(endDate) : null;
}

class AppUsageListItem {
  String id;
  String name;
  String? displayName;
  String? color;
  String? deviceName;
  int duration;
  List<AppUsageTagListItem> tags;

  AppUsageListItem({
    required this.id,
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
    required this.duration,
    this.tags = const [],
  });
}

class GetListByTopAppUsagesQueryResponse extends PaginatedList<AppUsageListItem> {
  GetListByTopAppUsagesQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
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
      showNoTagsFilter: request.showNoTagsFilter,
      startDate: request.startDate,
      endDate: request.endDate,
      searchByProcessName: request.searchByProcessName,
      filterByDevices: request.filterByDevices,
    );

    final items = results.items
        .map((record) => AppUsageListItem(
              id: record.id,
              name: record.name,
              displayName: record.displayName,
              color: record.color,
              deviceName: record.deviceName,
              duration: record.duration,
              tags: record.tags,
            ))
        .toList();

    return GetListByTopAppUsagesQueryResponse(
      items: items,
      totalItemCount: results.totalItemCount,
      pageIndex: results.pageIndex,
      pageSize: results.pageSize,
    );
  }
}
