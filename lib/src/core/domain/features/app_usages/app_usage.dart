import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class AppUsage extends BaseEntity<String> {
  String name;
  String? displayName;
  String? color;
  String? deviceName;

  AppUsage({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
  });
}
