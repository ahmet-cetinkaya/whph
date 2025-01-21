import 'package:whph/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/application/shared/services/i_repository.dart';

abstract class IAppUsageTimeRecordRepository extends IRepository<AppUsageTimeRecord, String> {
  Future<Map<String, int>> getAppUsageDurations({
    required List<String> appUsageIds,
    DateTime? startDate,
    DateTime? endDate,
  });
}
