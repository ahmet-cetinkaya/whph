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
  IntColumn get duration => integer()();

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
      duration: entity.duration,
      color: Value(entity.color),
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
  Future<PaginatedList<AppUsage>> getListByTopAppUsages(
      {required int pageIndex,
      required int pageSize,
      int? year,
      int? month,
      int? day,
      int? hour,
      List<String>? filterByTags}) async {
    var query = database.customSelect(
      'SELECT id, name, display_name, color, SUM(duration) as duration, created_date, modified_date, deleted_date FROM app_usage_table '
      'WHERE deleted_date IS NULL '
      '${year != null ? 'AND strftime("%Y", created_date) = ? ' : ''} '
      '${month != null ? 'AND strftime("%m", created_date) = ? ' : ''} '
      '${day != null ? 'AND strftime("%d", created_date) = ? ' : ''} '
      '${hour != null ? 'AND strftime("%H", created_date) = ? ' : ''} '
      '${filterByTags != null && filterByTags.isNotEmpty ? 'AND (SELECT COUNT(*) FROM app_usage_tag_table WHERE app_usage_tag_table.app_usage_id = app_usage_table.id AND app_usage_tag_table.tag_id IN (${List.filled(filterByTags.length, '?').join(', ')}) > 0) ' : ''} '
      'GROUP BY name '
      'ORDER BY SUM(duration) DESC '
      'LIMIT ? OFFSET ?',
      variables: [
        if (year != null) Variable.withString(year.toString()),
        if (month != null) Variable.withString(month.toString().padLeft(2, '0')),
        if (day != null) Variable.withString(day.toString().padLeft(2, '0')),
        if (hour != null) Variable.withString(hour.toString().padLeft(2, '0')),
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
            duration: row.read<int>('duration'),
            color: row.read<String?>('color'),
            createdDate: row.read<DateTime>('created_date'),
            modifiedDate: row.read<DateTime?>('modified_date'),
            deletedDate: row.read<DateTime?>('deleted_date')))
        .get();

    var totalCountQuery = database.customSelect(
      'SELECT COUNT(DISTINCT name) as count FROM app_usage_table '
      'WHERE deleted_date IS NULL '
      '${year != null ? 'AND strftime("%Y", created_date) = ? ' : ''} '
      '${month != null ? 'AND strftime("%m", created_date) = ? ' : ''} '
      '${day != null ? 'AND strftime("%d", created_date) = ? ' : ''} '
      '${hour != null ? 'AND strftime("%H", created_date) = ? ' : ''} '
      '${filterByTags != null && filterByTags.isNotEmpty ? 'AND (SELECT COUNT(*) FROM app_usage_tag_table WHERE app_usage_tag_table.app_usage_id = app_usage_table.id AND app_usage_tag_table.tag_id IN (${List.filled(filterByTags.length, '?').join(', ')}) > 0) ' : ''}',
      variables: [
        if (year != null) Variable.withString(year.toString()),
        if (month != null) Variable.withString(month.toString().padLeft(2, '0')),
        if (day != null) Variable.withString(day.toString().padLeft(2, '0')),
        if (hour != null) Variable.withString(hour.toString().padLeft(2, '0')),
        if (filterByTags != null) ...filterByTags.map((tag) => Variable.withString(tag)),
      ],
    );

    final totalItemCount = await totalCountQuery.map((row) => row.read<int>('count')).getSingle();
    final totalPageCount = (totalItemCount / pageSize).ceil();

    return PaginatedList<AppUsage>(
        items: result,
        totalItemCount: totalItemCount,
        totalPageCount: totalPageCount,
        pageIndex: pageIndex,
        pageSize: pageSize);
  }
}
