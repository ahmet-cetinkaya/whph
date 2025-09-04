import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tags/tag.dart';

@jsonSerializable
class NoteTag extends BaseEntity<String> {
  String noteId;
  String tagId;
  Tag? tag; // Reference to the associated tag

  NoteTag({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.noteId,
    required this.tagId,
    this.tag,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'noteId': noteId,
        'tagId': tagId,
        'tag': tag?.toJson(),
      };

  factory NoteTag.fromJson(Map<String, dynamic> json) {
    return NoteTag(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      noteId: json['noteId'] as String,
      tagId: json['tagId'] as String,
      tag: json['tag'] != null ? Tag.fromJson(json['tag'] as Map<String, dynamic>) : null,
    );
  }
}
