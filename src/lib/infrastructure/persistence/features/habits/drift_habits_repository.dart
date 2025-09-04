import 'package:drift/drift.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

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

  // No need to override getById and getList methods anymore
  // The conversion between String and List<int> is handled automatically by Habit class
}
