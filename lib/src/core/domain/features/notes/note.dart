import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/corePackages/acore/repository/models/base_entity.dart';
import 'package:whph/src/core/domain/features/notes/note_tag.dart';

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
}
