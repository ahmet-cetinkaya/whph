import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class NoteTag extends BaseEntity<String> {
  String noteId;
  String tagId;

  NoteTag({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.noteId,
    required this.tagId,
  });
}
