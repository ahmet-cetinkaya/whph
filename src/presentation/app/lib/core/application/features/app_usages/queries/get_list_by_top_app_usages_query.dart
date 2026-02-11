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
  List<String>? customTagSortOrder;

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
    this.customTagSortOrder,
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
      customTagSortOrder: request.customTagSortOrder,
    );

    final items = results.items.map((record) {
      // Sort tags of the app usage based on the same criteria as sorting/grouping
      List<AppUsageTagListItem> tags = List<AppUsageTagListItem>.from(record.tags);
      if (tags.isNotEmpty) {
        if (request.customTagSortOrder != null && request.customTagSortOrder!.isNotEmpty) {
          final orderMap = {
            for (var i = 0; i < request.customTagSortOrder!.length; i++) request.customTagSortOrder![i]: i
          };
          tags.sort((a, b) {
            final indexA = orderMap[a.tagId] ?? 999;
            final indexB = orderMap[b.tagId] ?? 999;
            if (indexA != indexB) return indexA.compareTo(indexB);
            return a.tagOrder.compareTo(b.tagOrder);
          });
        } else {
          // Default sort by tagOrder ASC, then tagName
          tags.sort((a, b) {
            final orderCompare = a.tagOrder.compareTo(b.tagOrder);
            if (orderCompare != 0) return orderCompare;
            return a.tagName.toLowerCase().compareTo(b.tagName.toLowerCase());
          });
        }
      }

      final item = AppUsageListItem(
        id: record.id,
        name: record.name,
        displayName: record.displayName,
        color: record.color,
        deviceName: record.deviceName,
        duration: record.duration,
        compareDuration: record.compareDuration,
        tags: tags,
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
