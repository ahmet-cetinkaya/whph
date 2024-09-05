import 'package:whph/core/acore/repository/models/base_entity.dart';

class AppUsageTag extends BaseEntity<String> {
  String appUsageId;
  int tagId;

  AppUsageTag(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      required this.appUsageId,
      required this.tagId});
}
