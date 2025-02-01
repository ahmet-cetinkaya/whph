import 'package:drift/drift.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Task)
class TaskTable extends Table {
  TextColumn get id => text()();
  TextColumn get parentTaskId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get priority => intEnum<EisenhowerPriority>().nullable()();
  DateTimeColumn get plannedDate => dateTime().nullable()();
  DateTimeColumn get deadlineDate => dateTime().nullable()();
  IntColumn get estimatedTime => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
}

class DriftTaskRepository extends DriftBaseRepository<Task, String, TaskTable> implements ITaskRepository {
  DriftTaskRepository() : super(AppDatabase.instance(), AppDatabase.instance().taskTable);

  @override
  Expression<String> getPrimaryKey(TaskTable t) {
    return t.id;
  }

  @override
  Insertable<Task> toCompanion(Task entity) {
    return TaskTableCompanion.insert(
      id: entity.id,
      parentTaskId: Value(entity.parentTaskId),
      title: entity.title,
      description: Value(entity.description),
      priority: Value(entity.priority),
      plannedDate: Value(entity.plannedDate),
      deadlineDate: Value(entity.deadlineDate),
      estimatedTime: Value(entity.estimatedTime),
      isCompleted: Value(entity.isCompleted),
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
    );
  }
}
