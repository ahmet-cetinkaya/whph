import 'package:application/shared/services/abstraction/i_repository.dart' as app;
import 'package:domain/features/notes/note_tag.dart';

abstract class INoteTagRepository extends app.IRepository<NoteTag, String> {
  Future<List<NoteTag>> getByNoteId(String noteId);
  Future<NoteTag?> getByNoteIdAndTagId(String noteId, String tagId);
  Future<List<NoteTag>> getByTagId(String tagId);
  Future<void> updateTagOrders(String noteId, Map<String, int> tagOrders);
}
