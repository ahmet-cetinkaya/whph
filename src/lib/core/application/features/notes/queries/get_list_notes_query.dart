import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/notes/models/note_sort_fields.dart';
import 'package:whph/core/application/features/notes/models/note_list_item.dart';
import 'package:whph/core/application/features/notes/utils/note_grouping_helper.dart';

export 'package:whph/core/application/features/notes/models/note_sort_fields.dart';
export 'package:whph/core/application/features/notes/models/note_list_item.dart';

class GetListNotesQuery implements IRequest<GetListNotesQueryResponse> {
  final int pageIndex;
  final int pageSize;
  final List<String>? filterByTags;
  final bool filterNoTags;
  final String? search;
  final List<SortOption<NoteSortFields>>? sortBy;
  final bool sortByCustomOrder;
  final bool ignoreArchivedTagVisibility;
  final DateTime? now;
  final SortOption<NoteSortFields>? groupBy;

  GetListNotesQuery({
    required this.pageIndex,
    required this.pageSize,
    this.filterByTags,
    this.filterNoTags = false,
    this.search,
    this.sortBy,
    this.groupBy,
    this.sortByCustomOrder = false,
    this.ignoreArchivedTagVisibility = false,
    this.now,
  });
}

class GetListNotesQueryResponse extends PaginatedList<NoteListItem> {
  GetListNotesQueryResponse({
    required super.items,
    required super.totalItemCount,
    required super.pageIndex,
    required super.pageSize,
  });
}

class GetListNotesQueryHandler implements IRequestHandler<GetListNotesQuery, GetListNotesQueryResponse> {
  final INoteRepository _noteRepository;

  GetListNotesQueryHandler({
    required INoteRepository noteRepository,
  }) : _noteRepository = noteRepository;

  @override
  Future<GetListNotesQueryResponse> call(GetListNotesQuery request) async {
    CustomWhereFilter? filter;

    // Combine search and tag filters
    List<String> conditions = [];
    List<Object> variables = [];

    // Add search condition
    if (request.search?.isNotEmpty ?? false) {
      conditions.add('(title LIKE ? OR content LIKE ?)');
      variables.addAll(['%${request.search}%', '%${request.search}%']);
    }

    // Add tag filter conditions
    if (request.filterByTags?.isNotEmpty ?? false) {
      conditions.add('''
        id IN (
          SELECT note_id 
          FROM note_tag_table 
          WHERE tag_id IN (${request.filterByTags!.map((_) => '?').join(',')})
            AND deleted_date IS NULL
        )
      ''');
      variables.addAll(request.filterByTags!);
    } else if (request.filterNoTags) {
      conditions.add('''
        id NOT IN (
          SELECT note_id 
          FROM note_tag_table 
          WHERE deleted_date IS NULL
        )
      ''');
    }

    // Exclude notes only if ALL their tags are archived (show if at least one tag is not archived)
    if (!request.ignoreArchivedTagVisibility) {
      conditions.add('''
        id NOT IN (
          SELECT DISTINCT nt1.note_id 
          FROM note_tag_table nt1
          WHERE nt1.deleted_date IS NULL
          AND NOT EXISTS (
            SELECT 1 
            FROM note_tag_table nt2
            INNER JOIN tag_table t ON nt2.tag_id = t.id
            WHERE nt2.note_id = nt1.note_id 
            AND nt2.deleted_date IS NULL
            AND (t.is_archived = 0 OR t.is_archived IS NULL)
          )
        )
      ''');
    }

    // Combine all conditions
    if (conditions.isNotEmpty) {
      filter = CustomWhereFilter(
        conditions.join(' AND '),
        variables,
      );
    }

    // Get paginated notes with sorting and filtering
    final notesPaginated = await _noteRepository.getList(
      request.pageIndex,
      request.pageSize,
      customOrder: _getCustomOrders(request),
      customWhereFilter: filter,
    );

    final now = request.now ?? DateTime.now();

    // Map notes to list items with their tags
    final items = notesPaginated.items.map((note) {
      final noteItem = NoteListItem(
        id: note.id,
        title: note.title,
        content: note.content,
        tags: note.tags
            .map((noteTag) => TagListItem(
                  tagId: noteTag.tagId,
                  tagName: noteTag.tag?.name ?? '',
                  tagColor: noteTag.tag?.color,
                ))
            .toList(),
        createdDate: note.createdDate,
        modifiedDate: note.modifiedDate,
      );

      return noteItem;
    }).toList();

    // Populate group name if sorting is applied
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final groupField = request.groupBy?.field ?? request.sortBy?.firstOrNull?.field;
      final groupInfo = NoteGroupingHelper.getGroupInfo(item, groupField, now: now);
      items[i] = item.copyWith(
        groupName: groupInfo?.name,
        isGroupNameTranslatable: groupInfo?.isTranslatable ?? true,
      );
    }

    return GetListNotesQueryResponse(
      items: items,
      totalItemCount: notesPaginated.totalItemCount,
      pageIndex: notesPaginated.pageIndex,
      pageSize: notesPaginated.pageSize,
    );
  }

  List<CustomOrder> _getCustomOrders(GetListNotesQuery request) {
    List<CustomOrder> customOrders = [];

    // Prioritize grouping field if exists
    if (request.groupBy != null) {
      _addCustomOrder(customOrders, request.groupBy!);
    }

    if (request.sortByCustomOrder) {
      customOrders.add(CustomOrder(field: "order"));
      return customOrders;
    }

    if (request.sortBy == null || request.sortBy!.isEmpty) {
      // If no sort is specified, return default sort unless grouping is active.
      if (customOrders.isEmpty) {
        return [
          CustomOrder(
            field: 'created_date',
            direction: SortDirection.desc,
          ),
        ];
      }
      // If only grouping is specified, just use that.
      return customOrders;
    }

    // Add other sort options, avoiding duplicates
    for (var option in request.sortBy!) {
      if (request.groupBy != null && option.field == request.groupBy!.field) {
        continue;
      }
      _addCustomOrder(customOrders, option);
    }

    return customOrders;
  }

  void _addCustomOrder(List<CustomOrder> orders, SortOption<NoteSortFields> option) {
    if (option.field == NoteSortFields.title) {
      orders.add(CustomOrder(field: "title", direction: option.direction));
    } else if (option.field == NoteSortFields.createdDate) {
      orders.add(CustomOrder(field: "created_date", direction: option.direction));
    } else if (option.field == NoteSortFields.modifiedDate) {
      orders.add(CustomOrder(field: "modified_date", direction: option.direction));
    }
  }
}
