import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class AppUsageTag extends BaseEntity<String> {
  String appUsageId;
  String tagId;
  int tagOrder;

  AppUsageTag(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required this.appUsageId,
      required this.tagId,
      this.tagOrder = 0});

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'appUsageId': appUsageId,
        'tagId': tagId,
        'tagOrder': tagOrder,
      };

  factory AppUsageTag.fromJson(Map<String, dynamic> json) {
    return AppUsageTag(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      appUsageId: json['appUsageId'] as String,
      tagId: json['tagId'] as String,
      tagOrder: json['tagOrder'] as int? ?? 0,
    );
  }
}
