import 'package:drift/drift.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/drift_habits_repository.dart';

@UseRowClass(HabitTimeRecord)
class HabitTimeRecordTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get habitId => text().references(HabitTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get duration => integer()();

  @override
  Set<Column>? get primaryKey => {id};
}

class DriftHabitTimeRecordRepository extends DriftBaseRepository<HabitTimeRecord, String, HabitTimeRecordTable>
    implements IHabitTimeRecordRepository {
  DriftHabitTimeRecordRepository() : super(AppDatabase.instance(), AppDatabase.instance().habitTimeRecordTable);

  @override
  Expression<String> getPrimaryKey(HabitTimeRecordTable t) {
    return t.id;
  }

  @override
  Insertable<HabitTimeRecord> toCompanion(HabitTimeRecord entity) {
    return HabitTimeRecordTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      habitId: entity.habitId,
      duration: entity.duration,
    );
  }

  @override
  Future<int> getTotalDurationByHabitId(String habitId, {DateTime? startDate, DateTime? endDate}) async {
    final query = database.customSelect(
      '''
      SELECT COALESCE(SUM(duration), 0) as total_duration
      FROM habit_time_record_table
      WHERE habit_id = ?
        AND deleted_date IS NULL
        ${startDate != null ? 'AND created_date >= ?' : ''}
        ${endDate != null ? 'AND created_date <= ?' : ''}
      ''',
      variables: [
        Variable<String>(habitId),
        if (startDate != null) Variable<DateTime>(startDate),
        if (endDate != null) Variable<DateTime>(endDate),
      ],
      readsFrom: {table},
    );

    final result = await query.getSingleOrNull();
    return result?.data['total_duration'] as int? ?? 0;
  }

  @override
  Future<List<HabitTimeRecord>> getByHabitId(String habitId) async {
    return (database.select(table)..where((t) => t.habitId.equals(habitId) & t.deletedDate.isNull())).get();
  }

  @override
  Future<List<HabitTimeRecord>> getByHabitIdAndDateRange(String habitId, DateTime start, DateTime end) async {
    return (database.select(table)
          ..where(
              (t) => t.habitId.equals(habitId) & t.createdDate.isBetweenValues(start, end) & t.deletedDate.isNull()))
        .get();
  }
}
