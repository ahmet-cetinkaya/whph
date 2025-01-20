import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class AppUsageTimeRecord extends BaseEntity<String> {
  String appUsageId;
  int duration;

  AppUsageTimeRecord({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.appUsageId,
    required this.duration,
  });

  void mapFromInstance(AppUsageTimeRecord record) {
    super.id = record.id;
    super.createdDate = record.createdDate;
    super.modifiedDate = record.modifiedDate;
    super.deletedDate = record.deletedDate;
    appUsageId = record.appUsageId;
    duration = record.duration;
  }
}
