import 'package:drift/drift.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';

@UseRowClass(HabitTimeRecord)
class HabitTimeRecordTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get habitId => text().references(HabitTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get duration => integer()();
  DateTimeColumn get occurredAt => dateTime().nullable()();
  BoolColumn get isEstimated => boolean().withDefault(const Constant(false))();

  @override
  Set<Column>? get primaryKey => {id};
}

class DriftHabitTimeRecordRepository extends DriftBaseRepository<HabitTimeRecord, String, HabitTimeRecordTable>
    implements IHabitTimeRecordRepository {
  DriftHabitTimeRecordRepository() : super(AppDatabase.instance(), AppDatabase.instance().habitTimeRecordTable);

  DriftHabitTimeRecordRepository.withDatabase(AppDatabase db) : super(db, db.habitTimeRecordTable);

  @override
  Expression<String> getPrimaryKey(HabitTimeRecordTable t) {
    return t.id;
  }

  @override
  Future<void> add(HabitTimeRecord item) async {
    // Preserve the original createdDate instead of auto-setting it
    final originalCreatedDate = item.createdDate;
    item.createdDate = originalCreatedDate; // Don't let base class override this
    HabitTimeRecord insertedItem = await database.into(table).insertReturning(toCompanion(item));
    item.id = insertedItem.id;
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
      occurredAt: Value(entity.occurredAt),
      isEstimated: Value(entity.isEstimated),
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
          ..where((t) =>
              t.habitId.equals(habitId) &
              (t.occurredAt.isBetweenValues(start, end) |
                  (t.occurredAt.isNull() & t.createdDate.isBetweenValues(start, end))) &
              t.deletedDate.isNull()))
        .get();
  }

  @override
  Future<Map<String, int>> getTotalDurationsByHabitIds(List<String> habitIds,
      {DateTime? startDate, DateTime? endDate}) async {
    if (habitIds.isEmpty) return {};

    final placeholders = habitIds.map((_) => '?').join(',');
    final query = database.customSelect(
      '''
      SELECT habit_id, COALESCE(SUM(duration), 0) as total_duration
      FROM habit_time_record_table
      WHERE habit_id IN ($placeholders)
        AND deleted_date IS NULL
        ${startDate != null ? 'AND created_date >= ?' : ''}
        ${endDate != null ? 'AND created_date <= ?' : ''}
      GROUP BY habit_id
      ''',
      variables: [
        ...habitIds.map((id) => Variable<String>(id)),
        if (startDate != null) Variable<DateTime>(startDate),
        if (endDate != null) Variable<DateTime>(endDate),
      ],
      readsFrom: {table},
    );

    final results = await query.get();
    final map = <String, int>{};

    for (final result in results) {
      final habitId = result.data['habit_id'] as String;
      final totalDuration = result.data['total_duration'] as int? ?? 0;
      map[habitId] = totalDuration;
    }

    // Ensure all habitIds have an entry, even if they have no time records
    for (final habitId in habitIds) {
      map.putIfAbsent(habitId, () => 0);
    }

    return map;
  }
}
