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
  TextColumn get title => text()();
  TextColumn get processName => text().nullable()();
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
      title: entity.title,
      processName: Value(entity.processName),
      duration: entity.duration,
    );
  }

  @override
  Future<AppUsage?> getByDateAndHour(
      {required String title, required int year, required int month, required int day, required int hour}) async {
    return await (database.select(table)
          ..where((t) =>
              t.title.equals(title) &
              t.createdDate.year.equals(year) &
              t.createdDate.month.equals(month) &
              t.createdDate.day.equals(day) &
              t.createdDate.hour.equals(hour)))
        .getSingleOrNull();
  }

  @override
  Future<PaginatedList<AppUsage>> getListByTopAppUsages(
      {required int pageIndex, required int pageSize, int? year, int? month, int? day, int? hour}) async {
    var query = database.selectOnly(table)
      ..addColumns([
        database.appUsageTable.id,
        database.appUsageTable.title,
        database.appUsageTable.processName,
        database.appUsageTable.duration.sum(),
        database.appUsageTable.createdDate,
        database.appUsageTable.modifiedDate,
      ])
      ..groupBy([database.appUsageTable.processName])
      ..orderBy([OrderingTerm.desc(database.appUsageTable.duration.sum())]);

    if (year != null) {
      query.where(database.appUsageTable.createdDate.year.equals(year));
    }
    if (month != null) {
      query.where(database.appUsageTable.createdDate.month.equals(month));
    }
    if (day != null) {
      query.where(database.appUsageTable.createdDate.day.equals(day));
    }
    if (hour != null) {
      query.where(database.appUsageTable.createdDate.hour.equals(hour));
    }

    query.limit(pageSize, offset: pageIndex * pageSize);

    final result = await query
        .map((row) => AppUsage(
            id: row.read(database.appUsageTable.id)!,
            title: row.read(database.appUsageTable.title)!,
            processName: row.read(database.appUsageTable.processName),
            duration: row.read(database.appUsageTable.duration.sum())!,
            createdDate: row.read(database.appUsageTable.createdDate)!,
            modifiedDate: row.read(database.appUsageTable.modifiedDate)))
        .get();

    var totalCountQuery = database.selectOnly(database.appUsageTable)
      ..addColumns([database.appUsageTable.processName])
      ..groupBy([database.appUsageTable.processName]);

    if (year != null) {
      totalCountQuery.where(database.appUsageTable.createdDate.year.equals(year));
    }
    if (month != null) {
      totalCountQuery.where(database.appUsageTable.createdDate.month.equals(month));
    }
    if (day != null) {
      totalCountQuery.where(database.appUsageTable.createdDate.day.equals(day));
    }
    if (hour != null) {
      totalCountQuery.where(database.appUsageTable.createdDate.hour.equals(hour));
    }

    final totalItemCount = await totalCountQuery.get().then((rows) => rows.length);
    final totalPageCount = (totalItemCount / pageSize).ceil();

    return PaginatedList<AppUsage>(
        items: result,
        totalItemCount: totalItemCount,
        totalPageCount: totalPageCount,
        pageIndex: pageIndex,
        pageSize: pageSize);
  }
}
