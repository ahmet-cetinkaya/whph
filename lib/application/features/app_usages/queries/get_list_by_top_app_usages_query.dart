import 'package:mediatr/mediatr.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';

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
  final IAppUsageRepository _appUsageRepository;
  final IAppUsageTimeRecordRepository _timeRecordRepository;

  GetListByTopAppUsagesQueryHandler({
    required IAppUsageRepository appUsageRepository,
    required IAppUsageTimeRecordRepository timeRecordRepository,
  })  : _appUsageRepository = appUsageRepository,
        _timeRecordRepository = timeRecordRepository;

  @override
  Future<GetListByTopAppUsagesQueryResponse> call(GetListByTopAppUsagesQuery request) async {
    CustomWhereFilter? customWhereFilter;

    if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
      customWhereFilter = CustomWhereFilter(
        '''EXISTS (
          SELECT 1 
          FROM app_usage_tag_table aut 
          WHERE aut.app_usage_id = app_usage_table.id 
            AND aut.tag_id IN (${request.filterByTags!.map((_) => '?').join(', ')})
            AND aut.deleted_date IS NULL
        )''',
        request.filterByTags!,
      );
    }

    final appUsages = await _appUsageRepository.getList(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: customWhereFilter,
    );

    final appUsageTimeData = await _timeRecordRepository.getAppUsageDurations(
      appUsageIds: appUsages.items.map((e) => e.id).toList(),
      startDate: request.startDate,
      endDate: request.endDate,
    );

    final items = appUsages.items.map((appUsage) {
      final duration = appUsageTimeData[appUsage.id] ?? 0;
      return AppUsageListItem(
        id: appUsage.id,
        name: appUsage.name,
        displayName: appUsage.displayName,
        color: appUsage.color,
        deviceName: appUsage.deviceName,
        duration: duration,
      );
    }).toList();

    items.sort((a, b) => b.duration.compareTo(a.duration));

    return GetListByTopAppUsagesQueryResponse(
      items: items,
      totalItemCount: appUsages.totalItemCount,
      totalPageCount: appUsages.totalPageCount,
      pageIndex: appUsages.pageIndex,
      pageSize: appUsages.pageSize,
    );
  }
}
