import 'package:drift/drift.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:whph/core/domain/features/tasks/task_status.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(TaskStatus)
class TaskStatusTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  RealColumn get sortOrder => real().withDefault(const Constant(0.0))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  BoolColumn get isDoneStatus => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftTaskStatusRepository extends DriftBaseRepository<TaskStatus, String, TaskStatusTable>
    implements ITaskStatusRepository {
  DriftTaskStatusRepository() : super(AppDatabase.instance(), AppDatabase.instance().taskStatusTable);

  DriftTaskStatusRepository.withDatabase(AppDatabase db) : super(db, db.taskStatusTable);

  @override
  Expression<String> getPrimaryKey(TaskStatusTable t) {
    return t.id;
  }

  @override
  Insertable<TaskStatus> toCompanion(TaskStatus entity) {
    return TaskStatusTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      name: entity.name,
      color: Value(entity.color),
      sortOrder: Value(entity.order),
      isBuiltIn: Value(entity.isBuiltIn),
      isDoneStatus: Value(entity.isDoneStatus),
    );
  }
}
