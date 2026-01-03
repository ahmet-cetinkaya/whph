import 'package:whph/core/application/features/app_usages/models/app_usage_list_item.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_sort_fields.dart';
import 'package:whph/core/application/shared/utils/grouping_utils.dart';

enum AppUsageGroupType { unknownDevice }

class AppUsageGroupInfo {
  final String name;
  final bool isTranslatable;
  final AppUsageGroupType? type;

  const AppUsageGroupInfo({
    required this.name,
    required this.isTranslatable,
    this.type,
  });

  const AppUsageGroupInfo.translatable(this.name)
      : isTranslatable = true,
        type = null;

  const AppUsageGroupInfo.raw(this.name)
      : isTranslatable = false,
        type = null;

  AppUsageGroupInfo.type(AppUsageGroupType groupType)
      : name = groupType == AppUsageGroupType.unknownDevice ? 'app_usages.details.device.unknown' : '',
        isTranslatable = true,
        type = groupType;
}

class AppUsageGroupingHelper {
  static AppUsageGroupInfo? getGroupInfo(AppUsageListItem item, AppUsageSortFields? sortField) {
    if (sortField == null) return null;

    switch (sortField) {
      case AppUsageSortFields.name:
        final name = GroupingUtils.getTitleGroup(item.displayName ?? item.name);
        return AppUsageGroupInfo.raw(name);
      case AppUsageSortFields.duration:
        // Duration is in seconds, convert to minutes
        final keys = (item.duration / 60).round();
        final name = GroupingUtils.getDurationGroup(keys);
        return AppUsageGroupInfo.translatable(name);
      case AppUsageSortFields.device:
        if (item.deviceName == null || item.deviceName!.isEmpty) {
          return AppUsageGroupInfo.type(AppUsageGroupType.unknownDevice);
        }
        return AppUsageGroupInfo.raw(item.deviceName!);
    }
  }
}
