import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/application/features/tags/models/tag_time_data.dart';

abstract class IAppUsageTagRepository extends app.IRepository<AppUsageTag, String> {
  Future<PaginatedList<AppUsageTag>> getListByAppUsageId(String appUsageId, int pageIndex, int pageSize);

  Future<bool> anyByAppUsageIdAndTagId(String appUsageId, String tagId);

  Future<List<TagTimeData>> getTopTagsByDuration(
    DateTime startDate,
    DateTime endDate, {
    int? limit,
    List<String>? filterByTags,
    bool filterByIsArchived = false,
  });

  Future<void> updateTagOrders(String appUsageId, Map<String, int> tagOrders);
}
