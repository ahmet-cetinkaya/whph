import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class TaskTag extends BaseEntity<String> {
  String taskId;
  String tagId;

  TaskTag(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required this.taskId,
      required this.tagId});

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'taskId': taskId,
        'tagId': tagId,
      };

  factory TaskTag.fromJson(Map<String, dynamic> json) {
    return TaskTag(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      taskId: json['taskId'] as String,
      tagId: json['tagId'] as String,
    );
  }
}
