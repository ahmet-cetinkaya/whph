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
      WITH duration_calc AS (
        SELECT
          t.id as tag_id,
          t.name as tag_name,
          t.color as tag_color,
          (
            -- App Usages
            COALESCE((
              SELECT SUM(aur.duration)
              FROM app_usage_tag_table aut
              JOIN app_usage_time_record_table aur ON aur.app_usage_id = aut.app_usage_id
              WHERE aut.tag_id = t.id
              AND aut.deleted_date IS NULL
              AND aur.created_date BETWEEN ? AND ?
              AND aur.deleted_date IS NULL
            ), 0) +

            -- Tasks
            COALESCE((
              SELECT SUM(tr.duration)
              FROM task_tag_table tt
              JOIN task_time_record_table tr ON tr.task_id = tt.task_id
              WHERE tt.tag_id = t.id
              AND tt.deleted_date IS NULL
              AND tr.created_date BETWEEN ? AND ?
              AND tr.deleted_date IS NULL
            ), 0) +

            -- Habit Records
            COALESCE((
              SELECT SUM(h.estimated_time * 60 * (
                SELECT COUNT(*)
                FROM habit_record_table hr
                WHERE hr.habit_id = h.id
                AND hr.date BETWEEN ? AND ?
                AND hr.deleted_date IS NULL
              ))
              FROM habit_tag_table ht
              JOIN habit_table h ON h.id = ht.habit_id
              WHERE ht.tag_id = t.id
              AND ht.deleted_date IS NULL
              AND h.deleted_date IS NULL
              AND h.estimated_time IS NOT NULL
            ), 0)
          ) as total_duration
        FROM tag_table t
        WHERE t.deleted_date IS NULL
        ${filterByTags != null && filterByTags.isNotEmpty ? 'AND t.id IN (${filterByTags.map((_) => '?').join(',')})' : ''}
      )
      SELECT *
      FROM duration_calc
      WHERE total_duration > 0
      ORDER BY total_duration DESC
      ${limit != null ? 'LIMIT ?' : ''}
      ''',
      variables: [
        Variable<DateTime>(startDate),
        Variable<DateTime>(endDate),
        Variable<DateTime>(startDate),
        Variable<DateTime>(endDate),
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
        database.habitTable,
        database.habitTagTable,
        database.habitRecordTable,
      },
    );

    final results = await query.get();
    return results
        .map((row) => TagTimeData(
              tagId: row.read<String>('tag_id'),
              tagName: row.read<String>('tag_name'),
              tagColor: row.read<String?>('tag_color'),
              duration: row.read<int>('total_duration'),
            ))
        .toList();
  }
}
