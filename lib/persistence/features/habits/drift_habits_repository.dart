import 'package:drift/drift.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Habit)
class HabitTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text()();
}

class DriftHabitRepository extends DriftBaseRepository<Habit, int, HabitTable> implements IHabitRepository {
  DriftHabitRepository() : super(AppDatabase.instance(), AppDatabase.instance().habitTable);

  @override
  Expression<int> getPrimaryKey(HabitTable t) {
    return t.id;
  }

  @override
  Insertable<Habit> toCompanion(Habit entity) {
    return HabitTableCompanion.insert(
      id: entity.id > 0 ? Value(entity.id) : const Value.absent(),
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      name: entity.name,
      description: entity.description,
    );
  }
}
