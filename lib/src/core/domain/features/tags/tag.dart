import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

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
