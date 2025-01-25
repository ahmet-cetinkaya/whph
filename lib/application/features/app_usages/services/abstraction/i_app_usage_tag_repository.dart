import 'package:whph/application/shared/services/i_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';

abstract class IAppUsageTagRepository extends IRepository<AppUsageTag, String> {
  Future<PaginatedList<AppUsageTag>> getListByAppUsageId(String appUsageId, int pageIndex, int pageSize);

  Future<bool> anyByAppUsageIdAndTagId(String appUsageId, String tagId);

  Future<List<TagTimeData>> getTopTagsByDuration(
    DateTime startDate,
    DateTime endDate, {
    int? limit,
    List<String>? filterByTags,
  });
}

class TagTimeData {
  final String tagId;
  final String tagName;
  final String? tagColor;
  final int duration;

  TagTimeData({
    required this.tagId,
    required this.tagName,
    this.tagColor,
    required this.duration,
  });
}
