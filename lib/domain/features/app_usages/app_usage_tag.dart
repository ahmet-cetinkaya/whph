import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class AppUsageTag extends BaseEntity<String> {
  String appUsageId;
  String tagId;

  AppUsageTag(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required this.appUsageId,
      required this.tagId});
}
