import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';

class AppUsageTimeRecordWithDetails {
  final String id;
  final String name;
  final String? displayName;
  final String? color;
  final String? deviceName;
  final int duration;
  final List<AppUsageTagListItem> tags;

  AppUsageTimeRecordWithDetails({
    required this.id,
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
    required this.duration,
    this.tags = const [],
  });
}
