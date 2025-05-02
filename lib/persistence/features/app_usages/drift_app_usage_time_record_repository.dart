import 'package:drift/drift.dart';
import 'package:whph/application/features/app_usages/models/app_usage_time_record_with_details.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(AppUsageTimeRecord)
class AppUsageTimeRecordTable extends Table {
  TextColumn get id => text()();
  TextColumn get appUsageId => text()();
  IntColumn get duration => integer()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftAppUsageTimeRecordRepository extends DriftBaseRepository<AppUsageTimeRecord, String, AppUsageTimeRecordTable>
    implements IAppUsageTimeRecordRepository {
  DriftAppUsageTimeRecordRepository() : super(AppDatabase.instance(), AppDatabase.instance().appUsageTimeRecordTable);

  @override
  Expression<String> getPrimaryKey(AppUsageTimeRecordTable t) {
    return t.id;
  }

  @override
  Insertable<AppUsageTimeRecord> toCompanion(AppUsageTimeRecord entity) {
    return AppUsageTimeRecordTableCompanion.insert(
      id: entity.id,
      appUsageId: entity.appUsageId,
      duration: entity.duration,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
    );
  }

  @override
  Future<Map<String, int>> getAppUsageDurations({
    required List<String> appUsageIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (appUsageIds.isEmpty) return {};

    final query = database.customSelect(
      '''
      SELECT 
        app_usage_id,
        COALESCE(SUM(duration), 0) as total_duration
      FROM app_usage_time_record_table
      WHERE app_usage_id IN (${appUsageIds.map((_) => '?').join(', ')})
        AND deleted_date IS NULL
        ${startDate != null ? 'AND created_date >= ?' : ''}
        ${endDate != null ? 'AND created_date < ?' : ''}
      GROUP BY app_usage_id
      ''',
      variables: [
        ...appUsageIds.map((id) => Variable<String>(id)),
        if (startDate != null) Variable<DateTime>(startDate),
        if (endDate != null) Variable<DateTime>(endDate),
      ],
      readsFrom: {table},
    );

    final results = await query.get();

    return {for (final row in results) row.read<String>('app_usage_id'): row.read<int>('total_duration')};
  }

  @override
  Future<PaginatedList<AppUsageTimeRecordWithDetails>> getTopAppUsagesWithDetails({
    int pageIndex = 0,
    int pageSize = 10,
    List<String>? filterByTags,
    bool showNoTagsFilter = false,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final countQuery = database.customSelect(
      '''
      WITH app_durations AS (
        SELECT 
          t.app_usage_id,
          COALESCE(SUM(t.duration), 0) as total_duration
        FROM app_usage_time_record_table t
        WHERE t.deleted_date IS NULL
        ${startDate != null ? 'AND t.created_date >= ?' : ''}
        ${endDate != null ? 'AND t.created_date < ?' : ''}
        GROUP BY t.app_usage_id
        HAVING total_duration > 0
      )
      SELECT COUNT(*) as total_count
      FROM app_durations ad
      INNER JOIN app_usage_table au ON ad.app_usage_id = au.id
      WHERE au.deleted_date IS NULL
      ${filterByTags != null && filterByTags.isNotEmpty ? '''
      AND EXISTS (
        SELECT 1 
        FROM app_usage_tag_table aut 
        WHERE aut.app_usage_id = au.id
          AND aut.tag_id IN (${filterByTags.map((_) => '?').join(', ')})
          AND aut.deleted_date IS NULL
        GROUP BY aut.app_usage_id
        HAVING COUNT(DISTINCT aut.tag_id) = ?
      )
      ''' : showNoTagsFilter ? '''
      AND NOT EXISTS (
        SELECT 1 
        FROM app_usage_tag_table aut 
        WHERE aut.app_usage_id = au.id
          AND aut.deleted_date IS NULL
      )
      ''' : ''}
      ''',
      variables: [
        if (startDate != null) Variable<DateTime>(startDate),
        if (endDate != null) Variable<DateTime>(endDate),
        if (filterByTags != null && filterByTags.isNotEmpty) ...[
          ...filterByTags.map((tag) => Variable<String>(tag)),
          Variable<int>(filterByTags.length)
        ],
      ],
      readsFrom: {table},
    );

    final countResult = await countQuery.getSingle();
    final totalCount = countResult.read<int>('total_count');

    final dataQuery = database.customSelect(
      '''
      WITH app_durations AS (
        SELECT 
          t.app_usage_id,
          COALESCE(SUM(t.duration), 0) as total_duration
        FROM app_usage_time_record_table t
        WHERE t.deleted_date IS NULL
        ${startDate != null ? 'AND t.created_date >= ?' : ''}
        ${endDate != null ? 'AND t.created_date < ?' : ''}
        GROUP BY t.app_usage_id
        HAVING total_duration > 0
      )
      SELECT 
        au.id,
        au.name,
        au.display_name,
        au.color,
        au.device_name,
        ad.total_duration as duration
      FROM app_durations ad
      INNER JOIN app_usage_table au ON ad.app_usage_id = au.id
      WHERE au.deleted_date IS NULL
      ${filterByTags != null && filterByTags.isNotEmpty ? '''
      AND EXISTS (
        SELECT 1 
        FROM app_usage_tag_table aut 
        WHERE aut.app_usage_id = au.id
          AND aut.tag_id IN (${filterByTags.map((_) => '?').join(', ')})
          AND aut.deleted_date IS NULL
        GROUP BY aut.app_usage_id
        HAVING COUNT(DISTINCT aut.tag_id) = ?
      )
      ''' : showNoTagsFilter ? '''
      AND NOT EXISTS (
        SELECT 1 
        FROM app_usage_tag_table aut 
        WHERE aut.app_usage_id = au.id
          AND aut.deleted_date IS NULL
      )
      ''' : ''}
      ORDER BY ad.total_duration DESC
      LIMIT ? OFFSET ?
      ''',
      variables: [
        if (startDate != null) Variable<DateTime>(startDate),
        if (endDate != null) Variable<DateTime>(endDate),
        if (filterByTags != null && filterByTags.isNotEmpty) ...[
          ...filterByTags.map((tag) => Variable<String>(tag)),
          Variable<int>(filterByTags.length)
        ],
        Variable<int>(pageSize),
        Variable<int>(pageIndex * pageSize),
      ],
      readsFrom: {table},
    );

    final results = await dataQuery.get();
    final items = results
        .map((row) => AppUsageTimeRecordWithDetails(
              id: row.read<String>('id'),
              name: row.read<String>('name'),
              displayName: row.readNullable<String>('display_name'),
              color: row.readNullable<String>('color'),
              deviceName: row.readNullable<String>('device_name'),
              duration: row.read<int>('duration'),
            ))
        .toList();

    return PaginatedList<AppUsageTimeRecordWithDetails>(
      items: items,
      totalItemCount: totalCount,
      totalPageCount: (totalCount / pageSize).ceil(),
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }
}
