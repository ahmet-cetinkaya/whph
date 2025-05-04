import 'package:whph/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/domain/features/notes/note_tag.dart';

abstract class INoteTagRepository extends IRepository<NoteTag, String> {
  Future<List<NoteTag>> getByNoteId(String noteId);
  Future<NoteTag?> getByNoteIdAndTagId(String noteId, String tagId);
}
