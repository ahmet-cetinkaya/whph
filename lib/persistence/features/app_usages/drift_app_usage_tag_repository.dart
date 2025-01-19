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
      ..where((t) => t.appUsageId.equals(appUsageId) & t.deletedDate.isNull())
      ..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await ((database.customSelect(
      "SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE app_usage_id = ? AND deleted_date IS NULL",
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
    final query = database.select(table)
      ..where((t) => t.appUsageId.equals(appUsageId) & t.tagId.equals(tagId) & t.deletedDate.isNull());
    final result = await query.get();

    return result.isNotEmpty;
  }

  @override
  Future<List<TagTimeData>> getTopTagsByDuration(
    DateTime startDate,
    DateTime endDate, {
    int? limit,
    List<String>? filterByTags,
  }) async {
    final query = database.customSelect(
      '''
      WITH tag_durations AS (
        -- App Usage durations
        SELECT 
          t.id as tag_id,
          t.name as tag_name,
          t.color as tag_color,
          COALESCE(SUM(aur.duration), 0) as total_duration
        FROM tag_table t
        LEFT JOIN app_usage_tag_table aut ON t.id = aut.tag_id 
          AND aut.deleted_date IS NULL
        LEFT JOIN app_usage_time_record_table aur ON aut.app_usage_id = aur.app_usage_id 
          AND aur.created_date BETWEEN ? AND ?
          AND aur.deleted_date IS NULL
        WHERE t.deleted_date IS NULL
        ${filterByTags != null && filterByTags.isNotEmpty ? 'AND t.id IN (${filterByTags.map((_) => '?').join(',')})' : ''}
        GROUP BY t.id, t.name, t.color

        UNION ALL

        -- Task durations
        SELECT 
          t.id as tag_id,
          t.name as tag_name,
          t.color as tag_color,
          COALESCE(SUM(tr.duration), 0) as total_duration
        FROM tag_table t
        LEFT JOIN task_tag_table tt ON t.id = tt.tag_id 
          AND tt.deleted_date IS NULL
        LEFT JOIN task_time_record_table tr ON tt.task_id = tr.task_id 
          AND tr.created_date BETWEEN ? AND ?
          AND tr.deleted_date IS NULL
        WHERE t.deleted_date IS NULL
        ${filterByTags != null && filterByTags.isNotEmpty ? 'AND t.id IN (${filterByTags.map((_) => '?').join(',')})' : ''}
        GROUP BY t.id, t.name, t.color
      )
      SELECT 
        tag_id,
        tag_name,
        tag_color,
        SUM(total_duration) as total_duration
      FROM tag_durations
      GROUP BY tag_id, tag_name, tag_color
      HAVING total_duration > 0
      ORDER BY total_duration DESC
      ${limit != null ? 'LIMIT ?' : ''}
      ''',
      variables: [
        Variable<DateTime>(startDate),
        Variable<DateTime>(endDate),
        if (filterByTags != null && filterByTags.isNotEmpty) ...filterByTags.map((id) => Variable<String>(id)),
        Variable<DateTime>(startDate),
        Variable<DateTime>(endDate),
        if (filterByTags != null && filterByTags.isNotEmpty) ...filterByTags.map((id) => Variable<String>(id)),
        if (limit != null) Variable<int>(limit),
      ],
      readsFrom: {
        database.tagTable,
        database.appUsageTagTable,
        database.appUsageTimeRecordTable,
        database.taskTagTable,
        database.taskTimeRecordTable,
      },
    );

    final results = await query.get();
    return results.map((row) {
      return TagTimeData(
        tagId: row.read<String>('tag_id'),
        tagName: row.read<String>('tag_name'),
        tagColor: row.read<String?>('tag_color'),
        duration: row.read<int>('total_duration'),
      );
    }).toList();
  }
}
