import 'package:whph/persistence/shared/repositories/abstraction/i_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';

abstract class IAppUsageTagRepository extends IRepository<AppUsageTag, String> {
  Future<PaginatedList<AppUsageTag>> getListByAppUsageId(String appUsageId, int pageIndex, int pageSize);

  Future<bool> anyByAppUsageIdAndTagId(String appUsageId, String tagId);
}
