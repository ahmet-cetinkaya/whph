import 'package:drift/drift.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/habits/habit_record.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(HabitRecord)
class HabitRecordTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get habitId => text()();
  DateTimeColumn get date => dateTime()();
}

class DriftHabitRecordRepository extends DriftBaseRepository<HabitRecord, String, HabitRecordTable>
    implements IHabitRecordRepository {
  DriftHabitRecordRepository() : super(AppDatabase.instance(), AppDatabase.instance().habitRecordTable);

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
      date: entity.date,
    );
  }

  @override
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
      String habitId, DateTime startDate, DateTime endDate, int pageIndex, int pageSize) async {
    final query = database.select(table)
      ..where((t) => t.habitId.equals(habitId) & t.date.isBetweenValues(startDate, endDate) & t.deletedDate.isNull())
      ..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await (database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE habit_id = ? AND date BETWEEN ? AND ? AND deleted_date IS NULL',
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
}
