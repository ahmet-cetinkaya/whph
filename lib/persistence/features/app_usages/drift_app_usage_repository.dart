import 'package:drift/drift.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(AppUsage)
class AppUsageTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get name => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get deviceName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftAppUsageRepository extends DriftBaseRepository<AppUsage, String, AppUsageTable>
    implements IAppUsageRepository {
  DriftAppUsageRepository() : super(AppDatabase.instance(), AppDatabase.instance().appUsageTable);

  @override
  Expression<String> getPrimaryKey(AppUsageTable t) {
    return t.id;
  }

  @override
  Insertable<AppUsage> toCompanion(AppUsage entity) {
    return AppUsageTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      name: entity.name,
      displayName: Value(entity.displayName),
      color: Value(entity.color),
      deviceName: Value(entity.deviceName),
    );
  }

  @override
  Future<AppUsage?> getByDateAndHour(
      {required String name, required int year, required int month, required int day, required int hour}) async {
    return await (database.select(table)
          ..where((t) =>
              t.name.equals(name) &
              t.createdDate.year.equals(year) &
              t.createdDate.month.equals(month) &
              t.createdDate.day.equals(day) &
              t.createdDate.hour.equals(hour)))
        .getSingleOrNull();
  }

  @override
  Future<PaginatedList<AppUsage>> getListByTopAppUsages({
    required int pageIndex,
    required int pageSize,
    List<String>? filterByTags,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = database.customSelect(
      '''
      WITH FilteredPeriodAppUsages AS (
        SELECT t.id, t.name, SUM(t.duration) as total_duration
        FROM app_usage_table t
        WHERE t.deleted_date IS NULL
        ${startDate != null ? 'AND t.created_date >= ?' : ''}
        ${endDate != null ? 'AND t.created_date < ?' : ''}
        GROUP BY t.name
      ),
      FirstAppUsage AS (
        SELECT 
          t.name,
          t.id as first_id,
          t.color,
          t.display_name,
          t.device_name,
          t.created_date,
          ROW_NUMBER() OVER (PARTITION BY t.name ORDER BY t.created_date ASC) as rn
        FROM app_usage_table t
        WHERE t.deleted_date IS NULL
      )
      SELECT 
        fa.first_id as id,
        fp.name,
        fa.display_name,
        fa.color,
        fa.device_name,
        fp.total_duration as duration,
        MIN(t.created_date) as created_date,
        MAX(t.modified_date) as modified_date,
        MAX(t.deleted_date) as deleted_date
      FROM FilteredPeriodAppUsages fp
      INNER JOIN app_usage_table t ON fp.name = t.name
      LEFT JOIN FirstAppUsage fa ON fp.name = fa.name AND fa.rn = 1
      ${filterByTags != null && filterByTags.isNotEmpty ? '''
      WHERE EXISTS (
        SELECT 1 FROM app_usage_tag_table att 
        WHERE att.app_usage_id = fa.first_id 
        AND att.deleted_date IS NULL 
        AND att.tag_id IN (${List.filled(filterByTags.length, '?').join(',')})
      )
      ''' : ''}
      GROUP BY fp.name, fa.first_id, fa.display_name, fa.color, fp.total_duration
      ORDER BY fp.total_duration DESC
      LIMIT ? OFFSET ?
      ''',
      variables: [
        if (startDate != null) Variable.withDateTime(startDate),
        if (endDate != null) Variable.withDateTime(endDate),
        if (filterByTags != null) ...filterByTags.map((tag) => Variable.withString(tag)),
        Variable.withInt(pageSize),
        Variable.withInt(pageIndex * pageSize),
      ],
    );

    final result = await query
        .map((row) => AppUsage(
            id: row.read<String>('id'),
            name: row.read<String>('name'),
            displayName: row.read<String?>('display_name'),
            color: row.read<String?>('color'),
            deviceName: row.read<String?>('device_name'),
            createdDate: row.read<DateTime>('created_date'),
            modifiedDate: row.read<DateTime?>('modified_date'),
            deletedDate: row.read<DateTime?>('deleted_date')))
        .get();

    final totalCountQuery = database.customSelect(
      '''
      WITH FilteredPeriodAppUsages AS (
        SELECT DISTINCT t.name
        FROM app_usage_table t
        WHERE t.deleted_date IS NULL
        ${startDate != null ? 'AND t.created_date >= ?' : ''}
        ${endDate != null ? 'AND t.created_date < ?' : ''}
      )
      SELECT COUNT(*) as count 
      FROM FilteredPeriodAppUsages fp
      INNER JOIN app_usage_table t ON fp.name = t.name
      WHERE EXISTS (
        SELECT 1 FROM app_usage_table au
        LEFT JOIN app_usage_tag_table att ON au.id = att.app_usage_id
        WHERE au.name = fp.name
        AND au.deleted_date IS NULL
        AND att.deleted_date IS NULL
        ${filterByTags != null && filterByTags.isNotEmpty ? 'AND att.tag_id IN (${List.filled(filterByTags.length, '?').join(',')})' : ''}
      )
      ''',
      variables: [
        if (startDate != null) Variable.withDateTime(startDate),
        if (endDate != null) Variable.withDateTime(endDate),
        if (filterByTags != null) ...filterByTags.map((tag) => Variable.withString(tag)),
      ],
    );

    final totalItemCount = await totalCountQuery.map((row) => row.read<int>('count')).getSingle();
    return PaginatedList<AppUsage>(
        items: result, totalItemCount: totalItemCount, pageIndex: pageIndex, pageSize: pageSize);
  }
}
