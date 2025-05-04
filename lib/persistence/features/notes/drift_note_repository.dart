import 'package:drift/drift.dart';
import 'package:whph/domain/features/notes/note.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';

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
    await database.transaction(() async {
      for (var i = 0; i < noteIds.length; i++) {
        await database.customUpdate(
          'UPDATE note_table SET "order" = ? WHERE id = ?',
          variables: [
            Variable<double>(orders[i]),
            Variable<String>(noteIds[i]),
          ],
          updates: {table},
        );
      }
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
        totalPageCount: 0,
        pageIndex: pageIndex,
        pageSize: pageSize,
      );
    }

    // Get all tags for these notes in a single query
    final tagsQuery = '''
      SELECT t.*, nt.note_id
      FROM note_tag_table nt
      JOIN tag_table t ON t.id = nt.tag_id
      WHERE nt.note_id IN (${paginatedNotes.items.map((_) => '?').join(',')})
        AND nt.deleted_date IS NULL
        AND t.deleted_date IS NULL
    ''';

    final variables = paginatedNotes.items.map((note) => Variable<String>(note.id)).toList();
    final tagRows = await database
        .customSelect(
          tagsQuery,
          variables: variables,
        )
        .get();

    // Group tags by note ID
    final noteTagsMap = <String, List<Tag>>{};
    for (final row in tagRows) {
      final tag = Tag(
        id: row.read<String>('id'),
        name: row.read<String>('name'),
        color: row.readNullable<String>('color'),
        isArchived: row.read<bool>('is_archived'),
        createdDate: row.read<DateTime>('created_date'),
        modifiedDate: row.readNullable<DateTime>('modified_date'),
        deletedDate: row.readNullable<DateTime>('deleted_date'),
      );

      final noteId = row.read<String>('note_id');
      noteTagsMap.putIfAbsent(noteId, () => []).add(tag);
    }

    // Assign tags to notes
    final notesWithTags = paginatedNotes.items.map((note) {
      note.tags = noteTagsMap[note.id] ?? [];
      return note;
    }).toList();

    return PaginatedList<Note>(
      items: notesWithTags,
      totalItemCount: paginatedNotes.totalItemCount,
      totalPageCount: paginatedNotes.totalPageCount,
      pageIndex: paginatedNotes.pageIndex,
      pageSize: paginatedNotes.pageSize,
    );
  }

  @override
  Future<Note?> getById(String id) async {
    final note = await super.getById(id);
    if (note == null) return null;

    // Get tags for this note
    final tagsQuery = '''
      SELECT t.*
      FROM tag_table t
      JOIN note_tag_table nt ON t.id = nt.tag_id
      WHERE nt.note_id = ?
        AND nt.deleted_date IS NULL
        AND t.deleted_date IS NULL
    ''';

    final tagRows = await database.customSelect(
      tagsQuery,
      variables: [Variable<String>(id)],
    ).get();

    note.tags = tagRows
        .map((row) => Tag(
              id: row.read<String>('id'),
              name: row.read<String>('name'),
              color: row.readNullable<String>('color'),
              isArchived: row.read<bool>('is_archived'),
              createdDate: row.read<DateTime>('created_date'),
              modifiedDate: row.readNullable<DateTime>('modified_date'),
              deletedDate: row.readNullable<DateTime>('deleted_date'),
            ))
        .toList();

    return note;
  }
}
