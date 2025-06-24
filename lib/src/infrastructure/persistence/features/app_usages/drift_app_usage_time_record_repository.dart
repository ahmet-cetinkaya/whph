import 'package:drift/drift.dart';
import 'package:whph/src/core/application/features/app_usages/models/app_usage_time_record_with_details.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/src/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/src/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(AppUsageTimeRecord)
class AppUsageTimeRecordTable extends Table {
  TextColumn get id => text()();
  TextColumn get appUsageId => text()();
  IntColumn get duration => integer()();
  DateTimeColumn get usageDate => dateTime()();
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
      usageDate: entity.usageDate,
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
        ${startDate != null ? 'AND usage_date >= ?' : ''}
        ${endDate != null ? 'AND usage_date < ?' : ''}
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
    String? searchByProcessName,
  }) async {
    final countQuery = database.customSelect(
      '''
      WITH app_usages_data AS (
        SELECT 
          au.id,
          au.name,
          au.display_name,
          au.color,
          au.device_name,
          COALESCE(SUM(autr.duration), 0) as total_duration
        FROM app_usage_table au
        LEFT JOIN app_usage_time_record_table autr ON au.id = autr.app_usage_id AND autr.deleted_date IS NULL
        ${startDate != null ? 'AND autr.usage_date >= ?' : ''}
        ${endDate != null ? 'AND autr.usage_date <= ?' : ''}
        WHERE au.deleted_date IS NULL
        ${searchByProcessName != null ? 'AND au.name = ?' : ''}
        GROUP BY au.id, au.name, au.display_name, au.color, au.device_name
      )
      SELECT COUNT(*) as total_count
      FROM app_usages_data ad
      ${filterByTags != null && filterByTags.isNotEmpty ? '''
      WHERE EXISTS (
        SELECT 1 
        FROM app_usage_tag_table aut 
        WHERE aut.app_usage_id = ad.id 
          AND aut.tag_id IN (${filterByTags.map((_) => '?').join(', ')})
          AND aut.deleted_date IS NULL
        GROUP BY aut.app_usage_id
        HAVING COUNT(DISTINCT aut.tag_id) = ?
      )
      ''' : showNoTagsFilter ? '''
      WHERE NOT EXISTS (
        SELECT 1 
        FROM app_usage_tag_table aut 
        WHERE aut.app_usage_id = ad.id
          AND aut.deleted_date IS NULL
      )
      ''' : ''}
      ''',
      variables: [
        if (startDate != null) Variable<DateTime>(startDate),
        if (endDate != null) Variable<DateTime>(endDate),
        if (searchByProcessName != null) Variable<String>(searchByProcessName),
        if (filterByTags != null && filterByTags.isNotEmpty) ...[
          ...filterByTags.map((tag) => Variable<String>(tag)),
          Variable<int>(filterByTags.length)
        ],
      ],
      readsFrom: {table},
    );

    final dataQuery = database.customSelect(
      '''
      WITH app_usages_data AS (
        SELECT 
          au.id,
          au.name,
          au.display_name,
          au.color,
          au.device_name,
          COALESCE(SUM(autr.duration), 0) as total_duration
        FROM app_usage_table au
        LEFT JOIN app_usage_time_record_table autr ON au.id = autr.app_usage_id AND autr.deleted_date IS NULL
        ${startDate != null ? 'AND autr.usage_date >= ?' : ''}
        ${endDate != null ? 'AND autr.usage_date <= ?' : ''}
        WHERE au.deleted_date IS NULL
        ${searchByProcessName != null ? 'AND au.name = ?' : ''}
        GROUP BY au.id, au.name, au.display_name, au.color, au.device_name
      )
      SELECT 
        ad.id,
        ad.name,
        ad.display_name,
        ad.color,
        ad.device_name,
        ad.total_duration as duration,
        aut.id as tag_app_usage_tag_id,
        aut.tag_id,
        t.name as tag_name,
        t.color as tag_color
      FROM app_usages_data ad
      ${filterByTags != null && filterByTags.isNotEmpty ? '''
      INNER JOIN (
        SELECT DISTINCT app_usage_id 
        FROM app_usage_tag_table 
        WHERE tag_id IN (${filterByTags.map((_) => '?').join(', ')})
          AND deleted_date IS NULL
        GROUP BY app_usage_id
        HAVING COUNT(DISTINCT tag_id) = ?
      ) filter_aut ON ad.id = filter_aut.app_usage_id
      ''' : showNoTagsFilter ? '''
      WHERE NOT EXISTS (
        SELECT 1 
        FROM app_usage_tag_table aut_filter 
        WHERE aut_filter.app_usage_id = ad.id
          AND aut_filter.deleted_date IS NULL
      )
      ''' : ''}
      LEFT JOIN app_usage_tag_table aut ON ad.id = aut.app_usage_id AND aut.deleted_date IS NULL
      LEFT JOIN tag_table t ON aut.tag_id = t.id AND t.deleted_date IS NULL
      ORDER BY ad.total_duration DESC, ad.id, aut.id
      LIMIT ? OFFSET ?
      ''',
      variables: [
        if (startDate != null) Variable<DateTime>(startDate),
        if (endDate != null) Variable<DateTime>(endDate),
        if (searchByProcessName != null) Variable<String>(searchByProcessName),
        if (filterByTags != null && filterByTags.isNotEmpty) ...[
          ...filterByTags.map((tag) => Variable<String>(tag)),
          Variable<int>(filterByTags.length)
        ],
        Variable<int>(pageSize * 100), // Get more rows to handle tag denormalization
        Variable<int>(pageIndex * pageSize),
      ],
      readsFrom: {table},
    );

    final rows = await dataQuery.get();

    // Group rows by app usage and collect tags
    final Map<String, AppUsageTimeRecordWithDetails> appUsageMap = {};

    for (final row in rows) {
      final id = row.read<String>('id');

      if (!appUsageMap.containsKey(id)) {
        appUsageMap[id] = AppUsageTimeRecordWithDetails(
          id: id,
          name: row.read<String>('name'),
          displayName: row.read<String?>('display_name'),
          color: row.read<String?>('color'),
          deviceName: row.read<String?>('device_name'),
          duration: row.read<int>('duration'),
          tags: [],
        );
      }

      // Add tag if it exists
      final tagAppUsageTagId = row.read<String?>('tag_app_usage_tag_id');
      if (tagAppUsageTagId != null) {
        final tagId = row.read<String?>('tag_id');
        final tagName = row.read<String?>('tag_name');

        // Only add the tag if we have valid tag data
        if (tagId != null && tagName != null) {
          appUsageMap[id]!.tags.add(AppUsageTagListItem(
                id: tagAppUsageTagId,
                appUsageId: id,
                tagId: tagId,
                tagName: tagName,
                tagColor: row.read<String?>('tag_color'),
              ));
        }
      }
    }

    // Convert to list and apply pagination
    final allResults = appUsageMap.values.toList();
    final startIndex = pageIndex * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, allResults.length);
    final pagedResults = allResults.sublist(startIndex, endIndex);

    int totalCount = await countQuery.map((row) => row.read<int>('total_count')).getSingle();
    return PaginatedList<AppUsageTimeRecordWithDetails>(
      items: pagedResults,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
    );
  }
}
