import 'package:drift/drift.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Task)
class TaskTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get priority => intEnum<EisenhowerPriority>().nullable()();
  DateTimeColumn get plannedDate => dateTime().nullable()();
  DateTimeColumn get deadlineDate => dateTime().nullable()();
  IntColumn get estimatedTime => integer().nullable()();
  IntColumn get elapsedTime => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}

class DriftTaskRepository extends DriftBaseRepository<Task, int, TaskTable> implements ITaskRepository {
  DriftTaskRepository() : super(AppDatabase.instance(), AppDatabase.instance().taskTable);

  @override
  Expression<int> getPrimaryKey(TaskTable t) {
    return t.id;
  }

  @override
  Insertable<Task> toCompanion(Task entity) {
    return TaskTableCompanion.insert(
        id: entity.id > 0 ? Value(entity.id) : const Value.absent(),
        createdDate: entity.createdDate,
        modifiedDate: Value(entity.modifiedDate),
        title: entity.title,
        description: Value(entity.description),
        priority: Value(entity.priority),
        plannedDate: Value(entity.plannedDate),
        deadlineDate: Value(entity.deadlineDate),
        estimatedTime: Value(entity.estimatedTime),
        elapsedTime: Value(entity.elapsedTime),
        isCompleted: Value(entity.isCompleted));
  }
}
