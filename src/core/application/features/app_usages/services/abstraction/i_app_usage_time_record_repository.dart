import 'package:application/features/app_usages/models/app_usage_time_record_with_details.dart';
import 'package:acore/acore.dart' hide IRepository;
import 'package:domain/features/app_usages/app_usage_time_record.dart';
import 'package:application/shared/services/abstraction/i_repository.dart' as app;
import 'package:application/features/app_usages/models/app_usage_sort_fields.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';

abstract class IAppUsageTimeRecordRepository extends app.IRepository<AppUsageTimeRecord, String> {
  Future<Map<String, int>> getAppUsageDurations({
    required List<String> appUsageIds,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<AppUsageTimeRecord>> getByAppUsageId(String appUsageId);

  Future<PaginatedList<AppUsageTimeRecordWithDetails>> getTopAppUsagesWithDetails({
    int pageIndex = 0,
    int pageSize = 10,
    List<String>? filterByTags,
    bool showNoTagsFilter = false,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? compareStartDate,
    DateTime? compareEndDate,
    String? searchByProcessName,
    List<String>? filterByDevices,
    List<SortOptionWithTranslationKey<AppUsageSortFields>>? sortBy,
    bool sortByCustomOrder = false,
    SortOptionWithTranslationKey<AppUsageSortFields>? groupBy,
    List<String>? customTagSortOrder,
  });

  Future<List<String>> getDistinctDeviceNames();
}
