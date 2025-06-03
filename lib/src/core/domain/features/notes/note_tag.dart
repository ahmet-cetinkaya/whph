import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/corePackages/acore/repository/models/base_entity.dart';
import 'package:whph/src/core/domain/features/tags/tag.dart';

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
}
