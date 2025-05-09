import 'package:drift/drift.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Tag)
class TagTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

class DriftTagRepository extends DriftBaseRepository<Tag, String, TagTable> implements ITagRepository {
  DriftTagRepository() : super(AppDatabase.instance(), AppDatabase.instance().tagTable);

  @override
  Expression<String> getPrimaryKey(TagTable t) {
    return t.id;
  }

  @override
  Insertable<Tag> toCompanion(Tag entity) {
    return TagTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      name: entity.name,
      color: Value(entity.color),
      isArchived: Value(entity.isArchived),
    );
  }

  @override
  Future<PaginatedList<(Tag, List<Tag>)>> getListWithRelatedTags({
    required int pageIndex,
    required int pageSize,
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
  }) async {
    // First get paginated primary tags
    final tags = await getList(
      pageIndex,
      pageSize,
      customWhereFilter: customWhereFilter,
      customOrder: customOrder,
    );

    if (tags.items.isEmpty) {
      return PaginatedList<(Tag, List<Tag>)>(
        items: [],
        totalItemCount: 0,
        totalPageCount: 0,
        pageIndex: pageIndex,
        pageSize: pageSize,
      );
    }

    // For each primary tag, get its related tags in a single query
    final relatedTagsQuery = '''
      SELECT t.*, tt.primary_tag_id
      FROM tag_tag_table tt
      JOIN tag_table t ON t.id = tt.secondary_tag_id
      WHERE tt.primary_tag_id IN (${tags.items.map((_) => '?').join(',')})
        AND tt.deleted_date IS NULL
        AND t.deleted_date IS NULL
    ''';

    final variables = tags.items.map((tag) => Variable<String>(tag.id)).toList();
    final relatedTagRows = await (database.customSelect(
      relatedTagsQuery,
      variables: variables,
    )).get();

    // Convert rows to Tag objects and group by primary tag
    final relatedTagsMap = <String, List<Tag>>{};
    for (final row in relatedTagRows) {
      final tag = Tag(
        id: row.read<String>('id'),
        createdDate: row.read<DateTime>('created_date'),
        modifiedDate: row.read<DateTime?>('modified_date'),
        deletedDate: row.read<DateTime?>('deleted_date'),
        name: row.read<String>('name'),
        color: row.read<String?>('color'),
        isArchived: row.read<bool>('is_archived'),
      );

      // Get primary tag ID from the join
      final primaryTagId = row.read<String>('primary_tag_id');
      relatedTagsMap.putIfAbsent(primaryTagId, () => []).add(tag);
    }

    // Create result tuples with tags and their related tags
    final resultItems = tags.items
        .map(
          (tag) => (tag, relatedTagsMap[tag.id] ?? <Tag>[]),
        )
        .toList();

    return PaginatedList<(Tag, List<Tag>)>(
      items: resultItems,
      totalItemCount: tags.totalItemCount,
      totalPageCount: tags.totalPageCount,
      pageIndex: tags.pageIndex,
      pageSize: tags.pageSize,
    );
  }
}
