import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class TagTag extends BaseEntity<String> {
  String primaryTagId;
  String secondaryTagId;

  TagTag(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required this.primaryTagId,
      required this.secondaryTagId});

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'primaryTagId': primaryTagId,
        'secondaryTagId': secondaryTagId,
      };

  factory TagTag.fromJson(Map<String, dynamic> json) {
    return TagTag(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      primaryTagId: json['primaryTagId'] as String,
      secondaryTagId: json['secondaryTagId'] as String,
    );
  }
}
