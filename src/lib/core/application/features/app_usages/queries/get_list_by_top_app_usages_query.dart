import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_sort_fields.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_list_item.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/core/application/features/app_usages/utils/app_usage_grouping_helper.dart';

class GetListByTopAppUsagesQuery implements IRequest<GetListByTopAppUsagesQueryResponse> {
  late int pageIndex;
  late int pageSize;
  List<String>? filterByTags;
  bool showNoTagsFilter;
  DateTime? startDate;
  DateTime? endDate;
  DateTime? compareStartDate;
  DateTime? compareEndDate;
  String? searchByProcessName;
  List<String>? filterByDevices;
  List<SortOptionWithTranslationKey<AppUsageSortFields>>? sortBy;
  bool sortByCustomOrder;
  SortOptionWithTranslationKey<AppUsageSortFields>? groupBy;
  bool enableGrouping;

  GetListByTopAppUsagesQuery({
    required this.pageIndex,
    required this.pageSize,
    this.filterByTags,
    this.showNoTagsFilter = false,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? compareStartDate,
    DateTime? compareEndDate,
    this.searchByProcessName,
    this.filterByDevices,
    this.sortBy,
    this.groupBy,
    this.sortByCustomOrder = false,
    this.enableGrouping = false,
  })  : startDate = startDate != null ? DateTimeHelper.toUtcDateTime(startDate) : null,
        endDate = endDate != null ? DateTimeHelper.toUtcDateTime(endDate) : null,
        compareStartDate = compareStartDate != null ? DateTimeHelper.toUtcDateTime(compareStartDate) : null,
        compareEndDate = compareEndDate != null ? DateTimeHelper.toUtcDateTime(compareEndDate) : null;
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
      compareStartDate: request.compareStartDate,
      compareEndDate: request.compareEndDate,
      searchByProcessName: request.searchByProcessName,
      filterByDevices: request.filterByDevices,
      sortBy: request.sortBy,
      groupBy: request.enableGrouping ? request.groupBy : null,
      sortByCustomOrder: request.sortByCustomOrder,
    );

    final items = results.items.map((record) {
      final item = AppUsageListItem(
        id: record.id,
        name: record.name,
        displayName: record.displayName,
        color: record.color,
        deviceName: record.deviceName,
        duration: record.duration,
        compareDuration: record.compareDuration,
        tags: record.tags,
      );

      final groupField = request.enableGrouping ? request.groupBy?.field ?? request.sortBy?.firstOrNull?.field : null;
      final groupInfo = AppUsageGroupingHelper.getGroupInfo(item, groupField);
      if (groupInfo != null) {
        item.groupName = groupInfo.name;
        item.isGroupNameTranslatable = groupInfo.isTranslatable;
      }

      return item;
    }).toList();

    return GetListByTopAppUsagesQueryResponse(
      items: items,
      totalItemCount: results.totalItemCount,
      pageIndex: results.pageIndex,
      pageSize: results.pageSize,
    );
  }
}
