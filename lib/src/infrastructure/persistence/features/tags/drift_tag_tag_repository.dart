import 'package:drift/drift.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/tags/tag_tag.dart';
import 'package:whph/src/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/src/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(TagTag)
class TagTagTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get primaryTagId => text()();
  TextColumn get secondaryTagId => text()();
}

class DriftTagTagRepository extends DriftBaseRepository<TagTag, String, TagTagTable> implements ITagTagRepository {
  DriftTagTagRepository() : super(AppDatabase.instance(), AppDatabase.instance().tagTagTable);

  @override
  Expression<String> getPrimaryKey(TagTagTable t) {
    return t.id;
  }

  @override
  Insertable<TagTag> toCompanion(TagTag entity) {
    return TagTagTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      primaryTagId: entity.primaryTagId,
      secondaryTagId: entity.secondaryTagId,
    );
  }

  @override
  Future<PaginatedList<TagTag>> getListByPrimaryTagId(String id, int pageIndex, int pageSize) async {
    final query = database.select(table)
      ..where((t) => t.primaryTagId.equals(id) & t.deletedDate.isNull())
      ..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await (database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE primary_tag_id = ? AND deleted_date IS NULL',
      variables: [Variable.withString(id)],
      readsFrom: {table},
    ).getSingleOrNull());
    final totalCount = count?.data['count'] as int? ?? 0;

    return PaginatedList(
      items: result,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
    );
  }

  @override
  Future<bool> anyByPrimaryAndSecondaryId(String primaryTagId, String secondaryTagId) async {
    final query = database.select(table)
      ..where((t) =>
          t.primaryTagId.equals(primaryTagId) & t.secondaryTagId.equals(secondaryTagId) & t.deletedDate.isNull());
    final result = await query.get();

    return result.isNotEmpty;
  }
}
