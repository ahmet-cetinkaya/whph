import 'package:drift/drift.dart';
import 'package:nanoid2/nanoid2.dart';
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
  IntColumn get habitId => integer()();
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
      habitId: entity.habitId,
      date: entity.date,
    );
  }

  @override
  Future<void> add(HabitRecord item) {
    item.id = nanoid();
    return super.add(item);
  }

  @override
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
      int habitId, DateTime startDate, DateTime endDate, int pageIndex, int pageSize) async {
    final query = database.select(table)
      ..where((t) => t.habitId.equals(habitId) & t.date.isBetweenValues(startDate, endDate))
      ..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await ((database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE habit_id = $habitId AND date BETWEEN \'$startDate\' AND \'$endDate\'',
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
}
