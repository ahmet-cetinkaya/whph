import 'package:drift/drift.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:acore/acore.dart' as acore;

@UseRowClass(Habit)
class HabitTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  IntColumn get estimatedTime => integer().nullable()();
  DateTimeColumn get archivedDate => dateTime().nullable()();

  // Reminder settings
  BoolColumn get hasReminder => boolean().withDefault(const Constant(false))();
  TextColumn get reminderTime => text().nullable()(); // Stored as "HH:mm" format
  TextColumn get reminderDays =>
      text().withDefault(const Constant(''))(); // Stored as comma-separated values (e.g. "1,2,3,4,5,6,7")

  // Goal settings
  BoolColumn get hasGoal => boolean().withDefault(const Constant(false))();
  IntColumn get targetFrequency => integer().withDefault(const Constant(1))();
  IntColumn get periodDays => integer().withDefault(const Constant(7))();

  // Daily target settings for multiple occurrences per day
  IntColumn get dailyTarget => integer().nullable()();

  RealColumn get order => real().withDefault(const Constant(0.0))();
}

class DriftHabitRepository extends DriftBaseRepository<Habit, String, HabitTable> implements IHabitRepository {
  DriftHabitRepository() : super(AppDatabase.instance(), AppDatabase.instance().habitTable);

  @override
  Expression<String> getPrimaryKey(HabitTable t) {
    return t.id;
  }

  @override
  Insertable<Habit> toCompanion(Habit entity) {
    return HabitTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      name: entity.name,
      description: entity.description,
      estimatedTime: Value(entity.estimatedTime),
      archivedDate: Value(entity.archivedDate),
      hasReminder: Value(entity.hasReminder),
      reminderTime: Value(entity.reminderTime),
      reminderDays: Value(entity.reminderDays),
      hasGoal: Value(entity.hasGoal),
      targetFrequency: Value(entity.targetFrequency),
      periodDays: Value(entity.periodDays),
      dailyTarget: Value(entity.dailyTarget),
      order: Value(entity.order),
    );
  }

  @override
  Future<String> getReminderDaysById(String id) async {
    final result = await database.customSelect(
      'SELECT reminder_days FROM ${table.actualTableName} WHERE id = ?',
      variables: [Variable.withString(id)],
      readsFrom: {table},
    ).getSingleOrNull();

    final reminderDays = result != null ? result.data['reminder_days'] as String : '';
    return reminderDays;
  }

  @override
  Future<void> updateAll(List<Habit> habits) async {
    await database.transaction(() async {
      for (final habit in habits) {
        await database.update(table).replace(toCompanion(habit));
      }
    });
  }

  @override
  Future<acore.PaginatedList<Habit>> getList(int pageIndex, int pageSize,
      {bool includeDeleted = false,
      acore.CustomWhereFilter? customWhereFilter,
      List<acore.CustomOrder>? customOrder}) async {

    // Check if sorting by actualTime is requested
    final hasActualTimeSort = customOrder?.any((order) => order.field == "actual_time") == true;

    if (!hasActualTimeSort) {
      // Use default implementation if no actualTime sorting
      return super.getList(pageIndex, pageSize,
          includeDeleted: includeDeleted,
          customWhereFilter: customWhereFilter,
          customOrder: customOrder);
    }

    // Build custom query with LEFT JOIN for actualTime sorting
    List<String> whereClauses = [
      if (customWhereFilter != null) "(${customWhereFilter.query})",
      if (!includeDeleted) 'h.deleted_date IS NULL',
    ];
    String? whereClause = whereClauses.isNotEmpty ? " WHERE ${whereClauses.join(' AND ')} " : null;

    // Build ORDER BY clause with special handling for actual_time
    String? orderByClause;
    if (customOrder?.isNotEmpty == true) {
      final orderClauses = customOrder!.map((order) {
        if (order.field == "actual_time") {
          return "COALESCE(SUM(htr.duration), 0) ${order.direction == acore.SortDirection.asc ? 'ASC' : 'DESC'}";
        } else {
          return "`h.${order.field}` IS NULL, `h.${order.field}` ${order.direction == acore.SortDirection.asc ? 'ASC' : 'DESC'}";
        }
      }).join(', ');
      orderByClause = ' ORDER BY $orderClauses ';
    }

    final query = database.customSelect(
      """
      SELECT h.*
      FROM habit_table h
      LEFT JOIN habit_time_record_table htr ON h.id = htr.habit_id AND htr.deleted_date IS NULL
      ${whereClause ?? ''}
      GROUP BY h.id
      ${orderByClause ?? ''}
      LIMIT ? OFFSET ?
      """,
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => _convertToQueryVariable(e)),
        Variable.withInt(pageSize),
        Variable.withInt(pageIndex * pageSize)
      ],
      readsFrom: {table, database.habitTimeRecordTable},
    ).map((row) => table.map(row.data));
    final result = await query.get();

    // Get count using the same JOIN logic
    final count = await database.customSelect(
      """
      SELECT COUNT(DISTINCT h.id) AS count
      FROM habit_table h
      LEFT JOIN habit_time_record_table htr ON h.id = htr.habit_id AND htr.deleted_date IS NULL
      ${whereClause ?? ''}
      """,
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => _convertToQueryVariable(e)),
      ],
    ).getSingleOrNull();
    final totalCount = count?.data['count'] as int? ?? 0;

    return acore.PaginatedList(
      items: await Future.wait(result.map((entity) => entity is Future<Habit> ? entity : Future.value(entity))),
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
    );
  }

  Variable _convertToQueryVariable(Object value) {
    if (value is String) return Variable.withString(value);
    if (value is int) return Variable.withInt(value);
    if (value is double) return Variable.withReal(value);
    if (value is bool) return Variable.withBool(value);
    if (value is DateTime) return Variable.withDateTime(value);
    if (value is List<int>) return Variable.withBlob(Uint8List.fromList(value));
    return Variable(value);
  }

  // No need to override getById method anymore
  // The conversion between String and List<int> is handled automatically by Habit class
}
