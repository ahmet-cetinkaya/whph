import 'package:whph/core/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';

// Re-export the tag list item for convenience
export 'package:whph/core/application/features/app_usages/queries/get_list_app_usage_tags_query.dart'
    show AppUsageTagListItem;

class AppUsageListItem {
  String id;
  String name;
  String? displayName;
  String? color;
  String? deviceName;
  int duration;
  int? compareDuration;
  List<AppUsageTagListItem> tags;
  String? groupName;
  bool isGroupNameTranslatable;

  AppUsageListItem({
    required this.id,
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
    required this.duration,
    this.compareDuration,
    this.tags = const [],
    this.groupName,
    this.isGroupNameTranslatable = false,
  });
}
