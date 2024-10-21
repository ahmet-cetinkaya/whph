import 'package:drift/drift.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(AppUsageTag)
class AppUsageTagTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get appUsageId => text()();
  TextColumn get tagId => text()();
}

class DriftAppUsageTagRepository extends DriftBaseRepository<AppUsageTag, String, AppUsageTagTable>
    implements IAppUsageTagRepository {
  DriftAppUsageTagRepository() : super(AppDatabase.instance(), AppDatabase.instance().appUsageTagTable);

  @override
  Expression<String> getPrimaryKey(AppUsageTagTable t) {
    return t.id;
  }

  @override
  Insertable<AppUsageTag> toCompanion(AppUsageTag entity) {
    return AppUsageTagTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      appUsageId: entity.appUsageId,
      tagId: entity.tagId,
    );
  }

  @override
  Future<PaginatedList<AppUsageTag>> getListByAppUsageId(String appUsageId, int pageIndex, int pageSize) async {
    final query = database.select(table)
      ..where((t) => t.appUsageId.equals(appUsageId))
      ..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await ((database.customSelect(
      "SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE app_usage_id = ?",
      variables: [Variable<String>(appUsageId)],
      readsFrom: {table},
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
  Future<bool> anyByAppUsageIdAndTagId(String appUsageId, String tagId) async {
    final query = database.select(table)..where((t) => t.appUsageId.equals(appUsageId) & t.tagId.equals(tagId));
    final result = await query.get();

    return result.isNotEmpty;
  }
}
