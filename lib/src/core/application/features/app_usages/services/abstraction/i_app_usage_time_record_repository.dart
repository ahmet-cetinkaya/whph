import 'package:whph/src/core/application/features/app_usages/models/app_usage_time_record_with_details.dart';
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/src/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart' as app;

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
    String? searchByProcessName,
    List<String>? filterByDevices,
  });

  Future<List<String>> getDistinctDeviceNames();
}
