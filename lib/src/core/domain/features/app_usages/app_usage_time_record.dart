import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class AppUsageTimeRecord extends BaseEntity<String> {
  String appUsageId;
  int duration;
  DateTime usageDate;

  AppUsageTimeRecord({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.appUsageId,
    required this.duration,
    required this.usageDate,
  });
}
