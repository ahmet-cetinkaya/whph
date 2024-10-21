import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class Tag extends BaseEntity<String> {
  String name;

  Tag({required super.id, required super.createdDate, super.modifiedDate, required this.name});

  void mapFromInstance(Tag instance) {
    name = instance.name;
  }
}
