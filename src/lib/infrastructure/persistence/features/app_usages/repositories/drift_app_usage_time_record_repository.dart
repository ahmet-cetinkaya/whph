import 'package:drift/drift.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_time_record_with_details.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_sort_fields.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/core/domain/features/tags/tag.dart';

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
  Future<List<AppUsageTimeRecord>> getByAppUsageId(String appUsageId) async {
    return (database.select(table)..where((t) => t.appUsageId.equals(appUsageId) & t.deletedDate.isNull())).get();
  }

  @override
  Future<PaginatedList<AppUsageTimeRecordWithDetails>> getTopAppUsagesWithDetails({
    int pageIndex = 0,
    int pageSize = 10,
    List<String>? filterByTags,
    bool showNoTagsFilter = false,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? compareStartDate,
    DateTime? compareEndDate,
    String? searchByProcessName,
    List<String>? filterByDevices,
    List<SortOptionWithTranslationKey<AppUsageSortFields>>? sortBy,
    SortOptionWithTranslationKey<AppUsageSortFields>? groupBy,
    bool sortByCustomOrder = false,
    List<String>? customTagSortOrder,
  }) async {
    // Helper function to generate sort clause for a given table alias
    String getSortClauseForAlias(String alias) {
      final List<String> clauses = [];

      // Prioritize grouping field if exists
      if (groupBy != null) {
        final direction = groupBy.direction == SortDirection.desc ? 'DESC' : 'ASC';
        switch (groupBy.field) {
          case AppUsageSortFields.name:
            // Use only the first character for grouping to allow secondary sorting within the group
            clauses.add('SUBSTR(COALESCE($alias.display_name, $alias.name), 1, 1) COLLATE NOCASE $direction');
            break;
          case AppUsageSortFields.duration:
            clauses.add('$alias.total_duration $direction');
            break;
          case AppUsageSortFields.device:
            clauses.add('$alias.device_name $direction');
            break;
          case AppUsageSortFields.tag:
            // Grouping by tag roughly means sorting by first tag
            if (customTagSortOrder != null && customTagSortOrder.isNotEmpty) {
              final caseStatements = StringBuffer();
              for (int i = 0; i < customTagSortOrder.length; i++) {
                final safeId = customTagSortOrder[i].replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
                caseStatements.write("WHEN '$safeId' THEN $i ");
              }
              final tagSubquery =
                  "(SELECT MIN(CASE aut.tag_id $caseStatements ELSE 999 END) FROM app_usage_tag_table aut WHERE aut.app_usage_id = $alias.id AND aut.deleted_date IS NULL)";
              clauses.add("$tagSubquery IS NULL, $tagSubquery $direction");
            } else {
              final tagSubquery =
                  "(SELECT t.name FROM app_usage_tag_table aut JOIN tag_table t ON aut.tag_id = t.id WHERE aut.app_usage_id = $alias.id AND aut.deleted_date IS NULL AND t.deleted_date IS NULL ORDER BY aut.tag_order ASC, t.name COLLATE NOCASE ASC LIMIT 1)";
              clauses.add("$tagSubquery IS NULL, $tagSubquery $direction");
            }
            break;
        }
      }

      // Add other sort options
      if (sortBy != null) {
        for (final s in sortBy) {
          // Skip if it's the same as group field (already added)
          if (groupBy != null && s.field == groupBy.field) continue;

          final direction = s.direction == SortDirection.desc ? 'DESC' : 'ASC';
          switch (s.field) {
            case AppUsageSortFields.duration:
              clauses.add('$alias.total_duration $direction');
              break;
            case AppUsageSortFields.name:
              clauses.add('COALESCE($alias.display_name, $alias.name) COLLATE NOCASE $direction');
              break;
            case AppUsageSortFields.device:
              clauses.add('$alias.device_name $direction');
              break;
            case AppUsageSortFields.tag:
              if (customTagSortOrder != null && customTagSortOrder.isNotEmpty) {
                final caseStatements = StringBuffer();
                for (int i = 0; i < customTagSortOrder.length; i++) {
                  final safeId = customTagSortOrder[i].replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
                  caseStatements.write("WHEN '$safeId' THEN $i ");
                }
                final tagSubquery =
                    "(SELECT MIN(CASE aut.tag_id $caseStatements ELSE 999 END) FROM app_usage_tag_table aut WHERE aut.app_usage_id = $alias.id AND aut.deleted_date IS NULL)";
                clauses.add("$tagSubquery IS NULL, $tagSubquery $direction");
              } else {
                final tagSubquery =
                    "(SELECT t.name FROM app_usage_tag_table aut JOIN tag_table t ON aut.tag_id = t.id WHERE aut.app_usage_id = $alias.id AND aut.deleted_date IS NULL AND t.deleted_date IS NULL ORDER BY aut.tag_order ASC, t.name COLLATE NOCASE ASC LIMIT 1)";
                clauses.add("$tagSubquery IS NULL, $tagSubquery $direction");
              }
              break;
          }
        }
      }

      if (clauses.isEmpty) {
        return '$alias.total_duration DESC';
      }

      return clauses.join(', ');
    }

    final sortClause = getSortClauseForAlias('ad');

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
      WHERE 1=1
      ${filterByTags != null && filterByTags.isNotEmpty ? '''
      AND EXISTS (
        SELECT 1 
        FROM app_usage_tag_table aut 
        WHERE aut.app_usage_id = ad.id 
          AND aut.tag_id IN (${filterByTags.map((_) => '?').join(', ')})
          AND aut.deleted_date IS NULL
        GROUP BY aut.app_usage_id
        HAVING COUNT(DISTINCT aut.tag_id) = ?
      )
      ''' : showNoTagsFilter ? '''
      AND NOT EXISTS (
        SELECT 1 
        FROM app_usage_tag_table aut 
        WHERE aut.app_usage_id = ad.id
          AND aut.deleted_date IS NULL
      )
      ''' : ''}
      ${filterByDevices != null && filterByDevices.isNotEmpty ? '''
      AND ad.device_name IN (${filterByDevices.map((_) => '?').join(', ')})
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
        if (filterByDevices != null && filterByDevices.isNotEmpty) ...[
          ...filterByDevices.map((device) => Variable<String>(device)),
        ],
      ],
      readsFrom: {
        table,
        database.appUsageTable,
        database.appUsageTagTable,
      },
    );

    final totalCount = await countQuery.map((row) => row.read<int>('total_count')).getSingle();

    // Check if the requested page is beyond available data
    if (pageIndex * pageSize >= totalCount) {
      return PaginatedList<AppUsageTimeRecordWithDetails>(
        items: [],
        pageIndex: pageIndex,
        pageSize: pageSize,
        totalItemCount: totalCount,
      );
    }

    // Get paginated data with proper app usage-level pagination
    final outerSortClause = getSortClauseForAlias('fau');

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
      ),
      filtered_app_usages AS (
         SELECT ad.id, ad.name, ad.display_name, ad.color, ad.device_name, ad.total_duration
        FROM app_usages_data ad
        WHERE 1=1
        ${filterByTags != null && filterByTags.isNotEmpty ? '''
        AND EXISTS (
          SELECT 1 
          FROM app_usage_tag_table aut 
          WHERE aut.app_usage_id = ad.id 
            AND aut.tag_id IN (${filterByTags.map((_) => '?').join(', ')})
            AND aut.deleted_date IS NULL
          GROUP BY aut.app_usage_id
          HAVING COUNT(DISTINCT aut.tag_id) = ?
        )
        ''' : showNoTagsFilter ? '''
        AND NOT EXISTS (
          SELECT 1 
          FROM app_usage_tag_table aut 
          WHERE aut.app_usage_id = ad.id
            AND aut.deleted_date IS NULL
        )
        ''' : ''}
        ${filterByDevices != null && filterByDevices.isNotEmpty ? '''
        AND ad.device_name IN (${filterByDevices.map((_) => '?').join(', ')})
        ''' : ''}
        ORDER BY $sortClause
        LIMIT ? OFFSET ?
      )
      SELECT 
        fau.id,
        fau.name,
        fau.display_name,
        fau.color,
        fau.device_name,
        fau.total_duration as duration,
        aut.id as tag_app_usage_tag_id,
        aut.tag_id,
        aut.tag_order as ordering,
        t.name as tag_name,
        t.color as tag_color,
        t.type as tag_type
      FROM filtered_app_usages fau
      LEFT JOIN app_usage_tag_table aut ON fau.id = aut.app_usage_id AND aut.deleted_date IS NULL
      LEFT JOIN tag_table t ON aut.tag_id = t.id AND t.deleted_date IS NULL
      ORDER BY $outerSortClause, fau.id, ordering ASC
      ''',
      variables: [
        if (startDate != null) Variable<DateTime>(startDate),
        if (endDate != null) Variable<DateTime>(endDate),
        if (searchByProcessName != null) Variable<String>(searchByProcessName),
        if (filterByTags != null && filterByTags.isNotEmpty) ...[
          ...filterByTags.map((tag) => Variable<String>(tag)),
          Variable<int>(filterByTags.length)
        ],
        if (filterByDevices != null && filterByDevices.isNotEmpty) ...[
          ...filterByDevices.map((device) => Variable<String>(device)),
        ],
        Variable<int>(pageSize),
        Variable<int>(pageIndex * pageSize),
      ],
      readsFrom: {
        table,
        database.appUsageTable,
        database.appUsageTagTable,
        database.tagTable,
      },
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
          final tagTypeInt = row.read<int?>('tag_type') ?? 0;
          final tagType =
              tagTypeInt >= 0 && tagTypeInt < TagType.values.length ? TagType.values[tagTypeInt] : TagType.label;

          appUsageMap[id]!.tags.add(AppUsageTagListItem(
                id: tagAppUsageTagId,
                appUsageId: id,
                tagId: tagId,
                tagName: tagName,
                tagColor: row.read<String?>('tag_color'),
                tagType: tagType,
                tagOrder: row.read<int?>('ordering') ?? 0,
              ));
        }
      }
    }

    // Convert to list - no need for additional pagination since SQL already handles it
    final allResults = appUsageMap.values.toList();

    // Fetch comparison data if needed
    if (compareStartDate != null && compareEndDate != null && allResults.isNotEmpty) {
      final appUsageIds = allResults.map((e) => e.id).toList();
      final comparisonDurations = await getAppUsageDurations(
        appUsageIds: appUsageIds,
        startDate: compareStartDate,
        endDate: compareEndDate,
      );

      // Merge comparison durations
      for (var i = 0; i < allResults.length; i++) {
        final item = allResults[i];
        if (comparisonDurations.containsKey(item.id)) {
          allResults[i] = AppUsageTimeRecordWithDetails(
            id: item.id,
            name: item.name,
            displayName: item.displayName,
            color: item.color,
            deviceName: item.deviceName,
            duration: item.duration,
            compareDuration: comparisonDurations[item.id],
            tags: item.tags,
          );
        }
      }
    }

    return PaginatedList<AppUsageTimeRecordWithDetails>(
      items: allResults,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
    );
  }

  @override
  Future<List<String>> getDistinctDeviceNames() async {
    final query = database.customSelect(
      '''
      SELECT DISTINCT device_name
      FROM app_usage_table
      WHERE deleted_date IS NULL
        AND device_name IS NOT NULL
        AND device_name != ''
      ORDER BY device_name
      ''',
      variables: [],
      readsFrom: {database.appUsageTable},
    );

    final results = await query.get();
    return results.map((row) => row.read<String>('device_name')).toList();
  }
}
