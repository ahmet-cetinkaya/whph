import 'package:drift/drift.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(TagTag)
class TagTagTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  IntColumn get primaryTagId => integer()();
  IntColumn get secondaryTagId => integer()();
}

class DriftTagTagRepository extends DriftBaseRepository<TagTag, int, TagTagTable> implements ITagTagRepository {
  DriftTagTagRepository() : super(AppDatabase.instance(), AppDatabase.instance().tagTagTable);

  @override
  Expression<int> getPrimaryKey(TagTagTable t) {
    return t.id;
  }

  @override
  Insertable<TagTag> toCompanion(TagTag entity) {
    return TagTagTableCompanion.insert(
      id: entity.id > 0 ? Value(entity.id) : const Value.absent(),
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      primaryTagId: entity.primaryTagId,
      secondaryTagId: entity.secondaryTagId,
    );
  }

  @override
  Future<PaginatedList<TagTag>> getListByPrimaryTagId(int id, int pageIndex, int pageSize) async {
    final query = database.select(table)
      ..where((t) => t.primaryTagId.equals(id))
      ..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await ((database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE primary_tag_id = $id',
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

  @override
  Future<bool> anyByPrimaryAndSecondaryId(int primaryTagId, int secondaryTagId) async {
    final query = database.select(table)
      ..where((t) => t.primaryTagId.equals(primaryTagId) & t.secondaryTagId.equals(secondaryTagId));
    final result = await query.get();

    return result.isNotEmpty;
  }
}
