import 'package:drift/drift.dart';
import 'package:whph/src/core/domain/features/notes/note_tag.dart';
import 'package:whph/src/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/src/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';

@UseRowClass(NoteTag)
class NoteTagTable extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get tagId => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftNoteTagRepository extends DriftBaseRepository<NoteTag, String, NoteTagTable> implements INoteTagRepository {
  DriftNoteTagRepository() : super(AppDatabase.instance(), AppDatabase.instance().noteTagTable);

  @override
  Expression<String> getPrimaryKey(NoteTagTable t) {
    return t.id;
  }

  @override
  Insertable<NoteTag> toCompanion(NoteTag entity) {
    return NoteTagTableCompanion.insert(
      id: entity.id,
      noteId: entity.noteId,
      tagId: entity.tagId,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
    );
  }

  @override
  Future<List<NoteTag>> getByNoteId(String noteId) async {
    return (database.select(table)..where((t) => t.noteId.equals(noteId) & t.deletedDate.isNull())).get();
  }

  @override
  Future<NoteTag?> getByNoteIdAndTagId(String noteId, String tagId) async {
    final query = database.select(table)
      ..where((t) => t.noteId.equals(noteId) & t.tagId.equals(tagId) & t.deletedDate.isNull());

    final results = await query.get();
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<List<NoteTag>> getByTagId(String tagId) async {
    return (database.select(table)..where((t) => t.tagId.equals(tagId) & t.deletedDate.isNull())).get();
  }
}
