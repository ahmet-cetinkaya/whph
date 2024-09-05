import 'package:whph/core/acore/repository/models/base_entity.dart';

class AppUsage extends BaseEntity<String> {
  String title;
  String? processName;
  int duration;

  AppUsage({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    required this.title,
    this.processName,
    required this.duration,
  });
}
