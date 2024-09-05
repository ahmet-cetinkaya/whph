import 'package:drift/drift.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(TaskTag)
class TaskTagTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  IntColumn get taskId => integer()();
  IntColumn get tagId => integer()();
}

class DriftTaskTagRepository extends DriftBaseRepository<TaskTag, int, TaskTagTable> implements ITaskTagRepository {
  DriftTaskTagRepository() : super(AppDatabase.instance(), AppDatabase.instance().taskTagTable);

  @override
  Expression<int> getPrimaryKey(TaskTagTable t) {
    return t.id;
  }

  @override
  Insertable<TaskTag> toCompanion(TaskTag entity) {
    return TaskTagTableCompanion.insert(
      id: entity.id > 0 ? Value(entity.id) : const Value.absent(),
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      taskId: entity.taskId,
      tagId: entity.tagId,
    );
  }

  @override
  Future<PaginatedList<TaskTag>> getListByTaskId(int taskId, int pageIndex, int pageSize) async {
    final query = database.select(table)
      ..where((t) => t.taskId.equals(taskId))
      ..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await ((database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE task_id = $taskId',
    )).getSingleOrNull());
    final totalCount = count?.data['count'] as int? ?? 0;

    return PaginatedList(
      items: result,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
      totalPageCount: (totalCount / pageSize).ceil(),
    );
  }

  @override
  Future<bool> anyByTaskIdAndTagId(int taskId, int tagId) async {
    final query = database.select(table)..where((t) => t.taskId.equals(taskId) & t.taskId.equals(tagId));
    final result = await query.get();

    return result.isNotEmpty;
  }
}
