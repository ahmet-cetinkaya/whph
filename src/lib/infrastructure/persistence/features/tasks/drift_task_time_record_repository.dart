import 'package:drift/drift.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(TaskTimeRecord)
class TaskTimeRecordTable extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  IntColumn get duration => integer()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
}

class DriftTaskTimeRecordRepository extends DriftBaseRepository<TaskTimeRecord, String, TaskTimeRecordTable>
    implements ITaskTimeRecordRepository {
  DriftTaskTimeRecordRepository() : super(AppDatabase.instance(), AppDatabase.instance().taskTimeRecordTable);

  @override
  Expression<String> getPrimaryKey(TaskTimeRecordTable t) {
    return t.id;
  }

  @override
  Insertable<TaskTimeRecord> toCompanion(TaskTimeRecord entity) {
    return TaskTimeRecordTableCompanion.insert(
      id: entity.id,
      duration: entity.duration,
      taskId: entity.taskId,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
    );
  }

  @override
  Future<int> getTotalDurationByTaskId(
    String taskId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = database.customSelect(
      '''
      SELECT COALESCE(SUM(duration), 0) as total_duration
      FROM task_time_record_table
      WHERE task_id = ?
        AND deleted_date IS NULL
        ${startDate != null ? 'AND created_date >= ?' : ''}
        ${endDate != null ? 'AND created_date < ?' : ''}
      ''',
      variables: [
        Variable<String>(taskId),
        if (startDate != null) Variable<DateTime>(startDate),
        if (endDate != null) Variable<DateTime>(endDate),
      ],
      readsFrom: {table},
    );

    final result = await query.getSingleOrNull();
    return result?.read<int>('total_duration') ?? 0;
  }

  @override
  Future<List<TaskTimeRecord>> getByTaskId(String taskId) async {
    return (database.select(table)..where((t) => t.taskId.equals(taskId) & t.deletedDate.isNull())).get();
  }
}
