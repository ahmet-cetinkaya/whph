import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class Habit extends BaseEntity<String> {
  String name;
  String description;
  int? estimatedTime;

  Habit({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.name,
    required this.description,
    this.estimatedTime,
  });
}
