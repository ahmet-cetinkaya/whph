import 'package:mediatr/mediatr.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';

class GetListByTopAppUsagesQuery implements IRequest<GetListByTopAppUsagesQueryResponse> {
  late int pageIndex;
  late int pageSize;
  int? year;
  int? month;
  int? day;
  int? hour;
  List<String>? filterByTags;

  GetListByTopAppUsagesQuery(
      {required this.pageIndex, required this.pageSize, this.year, this.month, this.day, this.hour, this.filterByTags});
}

class AppUsageListItem {
  String id;
  String name;
  String? displayName;
  int duration;
  String? color;

  AppUsageListItem({required this.id, required this.name, this.displayName, required this.duration, this.color});
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
  late final IAppUsageRepository _appUsageRepository;

  GetListByTopAppUsagesQueryHandler({required IAppUsageRepository appUsageRepository})
      : _appUsageRepository = appUsageRepository;

  @override
  Future<GetListByTopAppUsagesQueryResponse> call(GetListByTopAppUsagesQuery request) async {
    PaginatedList<AppUsage> appUsages = await _appUsageRepository.getListByTopAppUsages(
      pageIndex: request.pageIndex,
      pageSize: request.pageSize,
      year: request.year,
      month: request.month,
      day: request.day,
      hour: request.hour,
      filterByTags: request.filterByTags,
    );

    return GetListByTopAppUsagesQueryResponse(
      items: appUsages.items
          .map((e) => AppUsageListItem(
              id: e.id, name: e.name, displayName: e.displayName, duration: e.duration, color: e.color))
          .toList(),
      totalItemCount: appUsages.totalItemCount,
      totalPageCount: appUsages.totalPageCount,
      pageIndex: appUsages.pageIndex,
      pageSize: appUsages.pageSize,
    );
  }
}
