import 'package:drift/drift.dart';
import 'package:domain/features/notes/note.dart';
import 'package:domain/features/notes/note_tag.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:domain/features/tags/tag.dart';
import 'package:acore/acore.dart';
import 'package:whph/infrastructure/persistence/shared/utils/persistence_utils.dart';

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
    // Build SQL query manually to support COLLATE NOCASE for title sorting
    List<String> whereClauses = [
      if (customWhereFilter != null) "(${customWhereFilter.query})",
      if (!includeDeleted) 'deleted_date IS NULL',
    ];
    String? whereClause = whereClauses.isNotEmpty ? " WHERE ${whereClauses.join(' AND ')} " : null;

    String? orderByClause;
    String? outerOrderByClause;

    if (customOrder?.isNotEmpty == true) {
      final orderClauses = customOrder!.map((order) {
        if (order.field == 'title') {
          return "title COLLATE NOCASE ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}";
        } else if (order.field.trim().startsWith('(')) {
          return "${order.field} IS NULL, ${order.field} ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}";
        }
        return "`${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}";
      }).join(', ');

      final outerOrderClauses = customOrder.map((order) {
        if (order.field == 'title') {
          return "n.title COLLATE NOCASE ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}";
        } else if (order.field.trim().startsWith('(')) {
          // Replace table name with alias 'n' for the outer query
          // and ensure NULLs (items with no tags) come last
          final field = order.field.replaceAll('note_table.', 'n.');
          return "$field IS NULL, $field ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}";
        }
        return "n.`${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}";
      }).join(', ');

      orderByClause = ' ORDER BY $orderClauses ';
      outerOrderByClause = ' ORDER BY $outerOrderClauses ';
    }

    final countResult = await database.customSelect(
      'SELECT COUNT(*) AS count FROM note_table${whereClause ?? ''}',
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => convertToQueryVariable(e)),
      ],
    ).getSingleOrNull();

    final totalCount = countResult?.data['count'] as int? ?? 0;

    if (totalCount == 0) {
      return PaginatedList<Note>(
        items: [],
        totalItemCount: 0,
        pageIndex: pageIndex,
        pageSize: pageSize,
      );
    }

    // Consolidated Query:
    // 1. Fetch IDs of the paginated notes using subquery
    // 2. Join Note, NoteTag, and Tag tables
    // 3. Select all necessary columns with aliases to avoid collision

    final query = '''
      SELECT 
        n.*,
        nt.id as nt_id, nt.note_id as nt_note_id, nt.tag_id as nt_tag_id, 
        nt.created_date as nt_created_date, nt.modified_date as nt_modified_date, nt.deleted_date as nt_deleted_date,
        nt.tag_order as nt_tag_order,
        t.id as t_id, t.name as t_name, t.color as t_color, t.created_date as t_created_date, t.type as t_type
      FROM (
        SELECT id 
        FROM note_table
        ${whereClause ?? ''}
        ${orderByClause ?? ''}
        LIMIT ? OFFSET ?
      ) as limited_notes
      JOIN note_table n ON n.id = limited_notes.id
      LEFT JOIN note_tag_table nt ON nt.note_id = n.id AND nt.deleted_date IS NULL
      LEFT JOIN tag_table t ON t.id = nt.tag_id AND t.deleted_date IS NULL
      ${outerOrderByClause ?? ''}
      ${outerOrderByClause != null ? ', nt.tag_order ASC' : 'ORDER BY nt.tag_order ASC'}
    ''';

    final List<Variable<Object>> variables = [
      if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => convertToQueryVariable(e)),
      Variable.withInt(pageSize),
      Variable.withInt(pageIndex * pageSize)
    ];

    final rows = await database.customSelect(
      query,
      variables: variables,
      readsFrom: {table, database.noteTagTable, database.tagTable},
    ).get();

    // Grouping Logic
    final Map<String, Note> noteMap = {};

    for (final row in rows) {
      // 1. Map Note (if not already mapped)
      // NoteTable columns are selected as raw (n.*), so we can use table.map
      // We rely on the fact that Drift ignores extra aliased columns when mapping to NoteTable
      final noteId = row.read<String>('id');
      if (!noteMap.containsKey(noteId)) {
        final mapped = table.map(row.data);
        noteMap[noteId] = mapped is Future<Note> ? await mapped : mapped;
        noteMap[noteId]!.tags = [];
      }

      final note = noteMap[noteId]!;

      // 2. Map NoteTag & Tag if present
      final noteTagId = row.readNullable<String>('nt_id');
      if (noteTagId != null) {
        final noteTag = NoteTag(
          id: noteTagId,
          noteId: row.read<String>('nt_note_id'),
          tagId: row.read<String>('nt_tag_id'),
          tagOrder: row.read<int>('nt_tag_order'),
          createdDate: row.read<DateTime>('nt_created_date'),
          modifiedDate: row.readNullable<DateTime>('nt_modified_date'),
          deletedDate: row.readNullable<DateTime>('nt_deleted_date'),
        );

        final tagId = row.readNullable<String>('t_id');
        if (tagId != null) {
          noteTag.tag = Tag(
            id: tagId,
            name: row.read<String>('t_name'),
            color: row.readNullable<String>('t_color'),
            createdDate: row.read<DateTime>('t_created_date'),
            type: parseTagType(row.read<int?>('t_type')),
          );
        }

        note.tags.add(noteTag);
      }
    }

    return PaginatedList<Note>(
      items: noteMap.values.toList(),
      totalItemCount: totalCount,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<Note?> getById(String id, {bool includeDeleted = false}) async {
    final query = '''
      SELECT 
        n.*,
        nt.id as nt_id, nt.note_id as nt_note_id, nt.tag_id as nt_tag_id, 
        nt.created_date as nt_created_date, nt.modified_date as nt_modified_date, nt.deleted_date as nt_deleted_date,
        nt.tag_order as nt_tag_order,
        t.id as t_id, t.name as t_name, t.color as t_color, t.created_date as t_created_date, t.type as t_type
      FROM note_table n
      LEFT JOIN note_tag_table nt ON nt.note_id = n.id AND nt.deleted_date IS NULL
      LEFT JOIN tag_table t ON t.id = nt.tag_id AND t.deleted_date IS NULL
      WHERE n.id = ? ${includeDeleted ? '' : 'AND n.deleted_date IS NULL'}
      ORDER BY nt.tag_order ASC
    ''';

    final rows = await database.customSelect(
      query,
      variables: [Variable<String>(id)],
      readsFrom: {table, database.noteTagTable, database.tagTable},
    ).get();

    if (rows.isEmpty) return null;

    Note? note;
    for (final row in rows) {
      if (note == null) {
        final mapped = table.map(row.data);
        note = mapped is Future<Note> ? await mapped : mapped;
        note.tags = [];
      }

      final noteTagId = row.readNullable<String>('nt_id');
      if (noteTagId != null) {
        final noteTag = NoteTag(
          id: noteTagId,
          noteId: row.read<String>('nt_note_id'),
          tagId: row.read<String>('nt_tag_id'),
          tagOrder: row.read<int>('nt_tag_order'),
          createdDate: row.read<DateTime>('nt_created_date'),
          modifiedDate: row.readNullable<DateTime>('nt_modified_date'),
          deletedDate: row.readNullable<DateTime>('nt_deleted_date'),
        );

        final tagId = row.readNullable<String>('t_id');
        if (tagId != null) {
          noteTag.tag = Tag(
            id: tagId,
            name: row.read<String>('t_name'),
            color: row.readNullable<String>('t_color'),
            createdDate: row.read<DateTime>('t_created_date'),
            type: parseTagType(row.read<int?>('t_type')),
          );
        }
        note.tags.add(noteTag);
      }
    }

    return note;
  }
}
