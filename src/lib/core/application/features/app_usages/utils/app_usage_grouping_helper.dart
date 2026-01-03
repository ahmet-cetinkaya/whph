import 'package:whph/core/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_sort_fields.dart';
import 'package:whph/core/application/shared/utils/grouping_utils.dart';

class AppUsageGroupInfo {
  final String name;
  final bool isTranslatable;

  const AppUsageGroupInfo({required this.name, required this.isTranslatable});
}

class AppUsageGroupingHelper {
  static AppUsageGroupInfo? getGroupInfo(AppUsageListItem item, AppUsageSortFields? sortField) {
    if (sortField == null) return null;

    switch (sortField) {
      case AppUsageSortFields.name:
        final name = GroupingUtils.getTitleGroup(item.displayName ?? item.name);
        return AppUsageGroupInfo(name: name, isTranslatable: false);
      case AppUsageSortFields.duration:
        // Duration is in seconds, convert to minutes
        final keys = (item.duration / 60).round();
        final name = GroupingUtils.getDurationGroup(keys);
        return AppUsageGroupInfo(name: name, isTranslatable: true);
      case AppUsageSortFields.device:
        if (item.deviceName == null || item.deviceName!.isEmpty) {
          return const AppUsageGroupInfo(name: 'app_usages.details.device.unknown', isTranslatable: true);
        }
        return AppUsageGroupInfo(name: item.deviceName!, isTranslatable: false);
    }
  }
}
