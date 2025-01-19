import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class AppUsageTagRule extends BaseEntity<String> {
  String pattern;
  String tagId;
  bool isActive;
  String? description;

  AppUsageTagRule({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.pattern,
    required this.tagId,
    this.isActive = true,
    this.description,
  });

  void mapFromInstance(AppUsageTagRule instance) {
    pattern = instance.pattern;
    tagId = instance.tagId;
    isActive = instance.isActive;
    description = instance.description;
  }
}
