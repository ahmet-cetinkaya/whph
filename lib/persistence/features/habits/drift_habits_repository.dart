import 'package:drift/drift.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Habit)
class HabitTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  IntColumn get estimatedTime => integer().nullable()();
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
    );
  }
}
