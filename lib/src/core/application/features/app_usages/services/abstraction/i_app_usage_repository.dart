import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/corePackages/acore/repository/models/paginated_list.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage.dart';

abstract class IAppUsageRepository extends IRepository<AppUsage, String> {
  Future<AppUsage?> getByDateAndHour({
    required String name,
    required int year,
    required int month,
    required int day,
    required int hour,
  });

  Future<PaginatedList<AppUsage>> getListByTopAppUsages({
    required int pageIndex,
    required int pageSize,
    List<String>? filterByTags,
    DateTime? startDate,
    DateTime? endDate,
  });
}
