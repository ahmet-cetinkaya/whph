import 'package:mediatr/mediatr.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/app_usage/app_usage.dart';
import 'package:whph/application/features/app_usage/services/abstraction/i_app_usage_repository.dart';

class GetListByTopAppUsagesQuery implements IRequest<GetListByTopAppUsagesQueryResponse> {
  late int pageIndex;
  late int pageSize;
  int? year;
  int? month;
  int? day;
  int? hour;

  GetListByTopAppUsagesQuery({required this.pageIndex, required this.pageSize});
}

class GetListByTopAppUsagesQueryResponse extends PaginatedList<AppUsage> {
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
    );

    return GetListByTopAppUsagesQueryResponse(
      items: appUsages.items,
      totalItemCount: appUsages.totalItemCount,
      totalPageCount: appUsages.totalPageCount,
      pageIndex: appUsages.pageIndex,
      pageSize: appUsages.pageSize,
    );
  }
}
