import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
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

  void mapFromInstance(AppUsage instance) {
    title = instance.title;
    processName = instance.processName;
    duration = instance.duration;
  }
}
