import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

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

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'pattern': pattern,
        'description': description,
      };

  factory AppUsageIgnoreRule.fromJson(Map<String, dynamic> json) {
    return AppUsageIgnoreRule(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      pattern: json['pattern'] as String,
      description: json['description'] as String?,
    );
  }
}
