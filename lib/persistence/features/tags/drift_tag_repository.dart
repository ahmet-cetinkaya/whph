import 'package:drift/drift.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Tag)
class TagTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  TextColumn get name => text()();
}

class DriftTagRepository extends DriftBaseRepository<Tag, int, TagTable> implements ITagRepository {
  DriftTagRepository() : super(AppDatabase.instance(), AppDatabase.instance().tagTable);

  @override
  Expression<int> getPrimaryKey(TagTable t) {
    return t.id;
  }

  @override
  Insertable<Tag> toCompanion(Tag entity) {
    return TagTableCompanion.insert(
      id: entity.id > 0 ? Value(entity.id) : const Value.absent(),
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      name: entity.name,
    );
  }

  @override
  Future<PaginatedList<Tag>> getListBySearch(String? search, int pageIndex, int pageSize) async {
    if (search == null || search.isEmpty) {
      return getList(pageIndex, pageSize);
    }

    final query = database.select(table)
      ..where((t) => t.name.like('%$search%'))
      ..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await ((database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE name LIKE \'%$search%\'',
    )).getSingleOrNull());
    final totalCount = count?.data['count'] as int? ?? 0;

    return PaginatedList(
      items: result,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
      totalPageCount: (totalCount / pageSize).ceil(),
    );
  }
}
