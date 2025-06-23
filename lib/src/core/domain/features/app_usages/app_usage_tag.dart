import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

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
