import 'package:application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:domain/features/app_usages/app_usage.dart';

abstract class IAppUsageRepository extends app.IRepository<AppUsage, String> {
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
