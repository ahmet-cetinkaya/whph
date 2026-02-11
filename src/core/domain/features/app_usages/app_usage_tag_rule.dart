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

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'pattern': pattern,
        'tagId': tagId,
        'description': description,
      };

  factory AppUsageTagRule.fromJson(Map<String, dynamic> json) {
    return AppUsageTagRule(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      pattern: json['pattern'] as String,
      tagId: json['tagId'] as String,
      description: json['description'] as String?,
    );
  }
}
