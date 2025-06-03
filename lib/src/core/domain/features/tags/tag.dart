import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/corePackages/acore/repository/models/base_entity.dart';

@jsonSerializable
class Tag extends BaseEntity<String> {
  String name;
  bool isArchived;
  String? color;

  Tag({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.name,
    this.isArchived = false,
    this.color,
  });
}
