import 'package:whph/src/core/application/features/app_usages/models/app_usage_time_record_with_details.dart';
import 'package:whph/corePackages/acore/repository/models/paginated_list.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart';

abstract class IAppUsageTimeRecordRepository extends IRepository<AppUsageTimeRecord, String> {
  Future<Map<String, int>> getAppUsageDurations({
    required List<String> appUsageIds,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<PaginatedList<AppUsageTimeRecordWithDetails>> getTopAppUsagesWithDetails({
    int pageIndex = 0,
    int pageSize = 10,
    List<String>? filterByTags,
    bool showNoTagsFilter = false,
    DateTime? startDate,
    DateTime? endDate,
    String? searchByProcessName,
  });
}
