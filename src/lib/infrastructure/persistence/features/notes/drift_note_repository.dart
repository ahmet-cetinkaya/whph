import 'package:drift/drift.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/notes/note_tag.dart';
import 'package:whph/infrastructure/persistence/shared/services/database_connection_manager.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:acore/acore.dart';

@UseRowClass(Note)
class NoteTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text().nullable()();
  RealColumn get order => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftNoteRepository extends DriftBaseRepository<Note, String, NoteTable> implements INoteRepository {
  DriftNoteRepository() : super(AppDatabase.instance(), AppDatabase.instance().noteTable);

  @override
  Expression<String> getPrimaryKey(NoteTable t) {
    return t.id;
  }

  @override
  Insertable<Note> toCompanion(Note entity) {
    return NoteTableCompanion.insert(
      id: entity.id,
      title: entity.title,
      content: Value(entity.content),
      order: Value(entity.order),
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
    );
  }

  @override
  Future<void> updateNoteOrder(List<String> noteIds, List<double> orders) async {
    return DatabaseConnectionManager.instance.executeWithRetry(() async {
      final currentDatabase = AppDatabase.instance();
      await currentDatabase.transaction(() async {
        for (var i = 0; i < noteIds.length; i++) {
          await currentDatabase.customUpdate(
            'UPDATE note_table SET "order" = ? WHERE id = ?',
            variables: [
              Variable<double>(orders[i]),
              Variable<String>(noteIds[i]),
            ],
            updates: {table},
          );
        }
      });
    });
  }

  @override
  Future<PaginatedList<Note>> getList(
    int pageIndex,
    int pageSize, {
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
    bool includeDeleted = false,
  }) async {
    return DatabaseConnectionManager.instance.executeWithRetry(() async {
      // Get notes with pagination
      final paginatedNotes = await super.getList(
        pageIndex,
        pageSize,
        customWhereFilter: customWhereFilter,
        customOrder: customOrder,
        includeDeleted: includeDeleted,
      );

      if (paginatedNotes.items.isEmpty) {
        return PaginatedList<Note>(
          items: [],
          totalItemCount: 0,
          pageIndex: pageIndex,
          pageSize: pageSize,
        );
      }

      // Get note_tags with their associated tags for this page of notes
      final noteIds = paginatedNotes.items.map((n) => n.id).join("','");
      final tagQuery = '''
        SELECT nt.*, t.name as tag_name, t.color as tag_color, t.created_date as tag_created_date
        FROM note_tag_table nt
        LEFT JOIN tag_table t ON t.id = nt.tag_id AND t.deleted_date IS NULL
        WHERE nt.deleted_date IS NULL 
        AND nt.note_id IN ('$noteIds')
      ''';

      final currentDatabase = AppDatabase.instance();
      final tagRows = await currentDatabase.customSelect(tagQuery).get();

      // Group note_tags by note_id
      final noteTagsMap = <String, List<NoteTag>>{};
      for (final row in tagRows) {
        final noteTag = NoteTag(
          id: row.read<String>('id'),
          noteId: row.read<String>('note_id'),
          tagId: row.read<String>('tag_id'),
          createdDate: row.read<DateTime>('created_date'),
          modifiedDate: row.readNullable<DateTime>('modified_date'),
          deletedDate: row.readNullable<DateTime>('deleted_date'),
        );

        // Add tag information
        noteTag.tag = Tag(
          id: row.read<String>('tag_id'),
          name: row.read<String>('tag_name'),
          color: row.readNullable<String>('tag_color'),
          createdDate: row.read<DateTime>('tag_created_date'),
        );

        noteTagsMap.putIfAbsent(noteTag.noteId, () => []).add(noteTag);
      }

      // Assign note_tags to notes
      final notesWithTags = paginatedNotes.items.map((note) {
        note.tags = noteTagsMap[note.id] ?? [];
        return note;
      }).toList();

      return PaginatedList<Note>(
        items: notesWithTags,
        totalItemCount: paginatedNotes.totalItemCount,
        pageIndex: paginatedNotes.pageIndex,
        pageSize: paginatedNotes.pageSize,
      );
    });
  }

  @override
  Future<Note?> getById(String id, {bool includeDeleted = false}) async {
    return DatabaseConnectionManager.instance.executeWithRetry(() async {
      final note = await super.getById(id, includeDeleted: includeDeleted);
      if (note == null) return null;

      // Get note_tags and their associated tags for this note
      final query = '''
        SELECT nt.*, t.name as tag_name, t.color as tag_color
        FROM note_tag_table nt
        LEFT JOIN tag_table t ON t.id = nt.tag_id AND t.deleted_date IS NULL
        WHERE nt.deleted_date IS NULL AND nt.note_id = ?
      ''';

      final currentDatabase = AppDatabase.instance();
      final rows = await currentDatabase.customSelect(query, variables: [Variable<String>(id)]).get();

      note.tags = rows.map((row) {
        final noteTag = NoteTag(
          id: row.read<String>('id'),
          noteId: row.read<String>('note_id'),
          tagId: row.read<String>('tag_id'),
          createdDate: row.read<DateTime>('created_date'),
          modifiedDate: row.readNullable<DateTime>('modified_date'),
          deletedDate: row.readNullable<DateTime>('deleted_date'),
        );

        // Add tag information
        noteTag.tag = Tag(
          id: row.read<String>('tag_id'),
          name: row.read<String>('tag_name'),
          color: row.readNullable<String>('tag_color'),
          createdDate: row.read<DateTime>('created_date'),
        );

        return noteTag;
      }).toList();

      return note;
    });
  }
}
