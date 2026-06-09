import 'package:drift/drift.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:whph/core/domain/features/tasks/task_status.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
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

  /// Handles builtin status IDs specially: returns a virtual TaskStatus for todo/done
  /// even if they don't exist in the database (migration may have been skipped or failed).
  @override
  Future<TaskStatus?> getById(String id, {bool includeDeleted = false}) async {
    final existing = await super.getById(id, includeDeleted: includeDeleted);
    if (existing != null) return existing;

    // Return virtual builtin status if table doesn't have it
    if (TaskStatusConstants.isTodoStatusId(id)) {
      return TaskStatus(
        id: TaskStatusConstants.todoId,
        createdDate: DateTime.now().toUtc(),
        name: '',
        color: TaskStatusConstants.todoColor,
        order: TaskStatusConstants.todoOrder,
        isBuiltIn: true,
        isDoneStatus: false,
      );
    }
    if (TaskStatusConstants.isDoneStatusId(id)) {
      return TaskStatus(
        id: TaskStatusConstants.doneId,
        createdDate: DateTime.now().toUtc(),
        name: '',
        color: TaskStatusConstants.doneColor,
        order: TaskStatusConstants.doneOrder,
        isBuiltIn: true,
        isDoneStatus: true,
      );
    }

    return null;
  }

  @override
  Future<bool> existsInDb(String id) async {
    final result = await database.customSelect(
      'SELECT 1 FROM ${table.actualTableName} WHERE id = ? AND deleted_date IS NULL LIMIT 1',
      variables: [Variable.withString(id)],
    ).getSingleOrNull();
    return result != null;
  }

  /// Checks if a status truly exists in the database (not just virtual from getById override).
  bool rowExistsInDb(String id) {
    // This is overridden in the command handler to check DB directly
    // By default, if we got here via getById, it exists
    throw UnsupportedError('Use DriftTaskStatusRepository with database access');
  }
}
