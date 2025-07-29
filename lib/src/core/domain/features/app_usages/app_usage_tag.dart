import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class AppUsageTag extends BaseEntity<String> {
  String appUsageId;
  String tagId;

  AppUsageTag(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required this.appUsageId,
      required this.tagId});

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'appUsageId': appUsageId,
        'tagId': tagId,
      };

  factory AppUsageTag.fromJson(Map<String, dynamic> json) {
    return AppUsageTag(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      appUsageId: json['appUsageId'] as String,
      tagId: json['tagId'] as String,
    );
  }
}
