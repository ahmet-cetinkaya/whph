import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class AppUsageTagRule extends BaseEntity<String> {
  String pattern;
  String tagId;
  String? description;

  AppUsageTagRule({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.pattern,
    required this.tagId,
    this.description,
  });
}
