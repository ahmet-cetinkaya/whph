import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class AppUsage extends BaseEntity<String> {
  String name;
  String? displayName;
  int duration;
  String? color;

  AppUsage(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required this.name,
      this.displayName,
      required this.duration,
      this.color});

  void mapFromInstance(AppUsage instance) {
    name = instance.name;
    displayName = instance.displayName;
    duration = instance.duration;
    color = instance.color;
  }
}
