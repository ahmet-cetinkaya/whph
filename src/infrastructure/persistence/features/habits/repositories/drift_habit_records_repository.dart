import 'package:drift/drift.dart';
import 'package:application/features/habits/services/i_habit_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:domain/features/habits/habit_record.dart';
import 'package:domain/features/habits/habit_record_status.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(HabitRecord)
class HabitRecordTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get habitId => text()();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get status => intEnum<HabitRecordStatus>().withDefault(const Constant(0))();

  @override
  Set<Column>? get primaryKey => {id};
}

class DriftHabitRecordRepository extends DriftBaseRepository<HabitRecord, String, HabitRecordTable>
    implements IHabitRecordRepository {
  DriftHabitRecordRepository() : super(AppDatabase.instance(), AppDatabase.instance().habitRecordTable);

  DriftHabitRecordRepository.withDatabase(AppDatabase db) : super(db, db.habitRecordTable);

  @override
  Expression<String> getPrimaryKey(HabitRecordTable t) {
    return t.id;
  }

  @override
  Insertable<HabitRecord> toCompanion(HabitRecord entity) {
    return HabitRecordTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      habitId: entity.habitId,
      occurredAt: entity.occurredAt,
      status: Value(entity.status),
    );
  }

  @override
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
      String habitId, DateTime startDate, DateTime endDate, int pageIndex, int pageSize) async {
    final query = database.select(table)
      ..where((t) =>
          t.habitId.equals(habitId) &
          t.occurredAt.isNotNull() &
          t.occurredAt.isBetweenValues(startDate, endDate) &
          t.deletedDate.isNull())
      ..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await (database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE habit_id = ? AND occurred_at IS NOT NULL AND occurred_at BETWEEN ? AND ? AND deleted_date IS NULL',
      variables: [Variable<String>(habitId), Variable<DateTime>(startDate), Variable<DateTime>(endDate)],
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

  /// Count occurrences for a habit on a specific date
  @override
  Future<int> countByHabitIdAndDate(String habitId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE habit_id = ? AND occurred_at IS NOT NULL AND occurred_at >= ? AND occurred_at < ? AND deleted_date IS NULL',
      variables: [Variable<String>(habitId), Variable<DateTime>(startOfDay), Variable<DateTime>(endOfDay)],
      readsFrom: {table},
    ).getSingleOrNull();

    return result?.data['count'] as int? ?? 0;
  }

  @override
  Future<List<HabitRecord>> getByHabitId(String habitId) async {
    return (database.select(table)..where((t) => t.habitId.equals(habitId) & t.deletedDate.isNull())).get();
  }

  @override
  Future<List<HabitRecord>> getByHabitIdAndStatus(String habitId, HabitRecordStatus status) async {
    final query = database.select(table)
      ..where((t) => t.habitId.equals(habitId) & t.status.equals(status.index) & t.deletedDate.isNull());

    final result = await query.get();
    return result;
  }
}
