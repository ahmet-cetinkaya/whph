import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';
import 'package:domain/features/notes/note_tag.dart';

@jsonSerializable
class Note extends BaseEntity<String> {
  String title;
  String? content;
  double order = 0;

  List<NoteTag> tags = [];

  Note({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.title,
    this.content,
    this.order = 0.0,
    this.tags = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'title': title,
        'content': content,
        'order': order,
        'tags': tags.map((e) => e.toJson()).toList(),
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      title: json['title'] as String,
      content: json['content'] as String?,
      order: (json['order'] as num?)?.toDouble() ?? 0.0,
      tags: (json['tags'] as List?)?.map((e) => NoteTag.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
