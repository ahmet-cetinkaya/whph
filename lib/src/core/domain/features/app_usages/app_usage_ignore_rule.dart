import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/corePackages/acore/repository/models/base_entity.dart';

@jsonSerializable
class AppUsageIgnoreRule extends BaseEntity<String> {
  String pattern;
  String? description;

  AppUsageIgnoreRule({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.pattern,
    this.description,
  });
}
